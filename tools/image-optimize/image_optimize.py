from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

VALID_INPUT_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".bmp"}
VALID_OUTPUT_FORMATS = {"webp", "jpeg", "png", "same"}


@dataclass(frozen=True)
class Preset:
    name: str
    max_width: int
    max_height: int | None
    format: str
    quality: int
    subsampling: str | None = "4:2:0"


PRESETS: dict[str, Preset] = {
    "gallery": Preset("gallery", max_width=1600, max_height=None, format="webp", quality=76),
    "featured": Preset("featured", max_width=2000, max_height=None, format="webp", quality=80),
    "thumbnail": Preset("thumbnail", max_width=800, max_height=None, format="webp", quality=72),
}


class OptimizationError(RuntimeError):
    pass


@dataclass(frozen=True)
class OptimizationResult:
    src: Path
    dst: Path
    original_size: int
    optimized_size: int

    @property
    def saved_bytes(self) -> int:
        return max(0, self.original_size - self.optimized_size)

    @property
    def saved_percent(self) -> float:
        if self.original_size == 0:
            return 0.0
        return (self.saved_bytes / self.original_size) * 100


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch-resize and optimize images for the website."
    )
    parser.add_argument("input", type=Path, help="Input image file or directory")
    parser.add_argument("output", type=Path, help="Output file or directory")
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS),
        default="gallery",
        help="Optimization preset to use (default: gallery)",
    )
    parser.add_argument(
        "--format",
        choices=sorted(VALID_OUTPUT_FORMATS),
        help="Override output format (webp/jpeg/png/same)",
    )
    parser.add_argument("--max-width", type=int, help="Override maximum output width")
    parser.add_argument("--max-height", type=int, help="Override maximum output height")
    parser.add_argument("--quality", type=int, help="Override output quality (1-100)")
    parser.add_argument(
        "--no-filename-suffix",
        action="store_true",
        help="Do not append an automatic size suffix such as '-1600w' to generated filenames",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Recursively process images when input is a directory",
    )
    parser.add_argument(
        "--keep-metadata",
        action="store_true",
        help="Preserve metadata/EXIF where possible (default strips metadata)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite output files if they already exist",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned operations without writing files",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        from PIL import Image, ImageOps, features
    except ImportError as exc:
        print(
            "Pillow is not installed. Install dependencies first: pip install -r requirements.txt",
            file=sys.stderr,
        )
        return 2

    preset = PRESETS[args.preset]
    output_format = (args.format or preset.format).lower()
    if output_format not in VALID_OUTPUT_FORMATS:
        raise OptimizationError(f"Unsupported output format: {output_format}")

    max_width = args.max_width or preset.max_width
    max_height = args.max_height or preset.max_height
    quality = args.quality or preset.quality

    if quality < 1 or quality > 100:
        raise OptimizationError("Quality must be between 1 and 100")

    if output_format == "webp" and not features.check("webp"):
        raise OptimizationError("This Pillow build does not support WebP output")

    if not args.input.exists():
        raise OptimizationError(f"Input path does not exist: {args.input}")

    try:
        jobs = list(
            build_jobs(
                args.input,
                args.output,
                args.recursive,
                output_format,
                max_width,
                max_height,
                use_filename_suffix=not args.no_filename_suffix,
            )
        )
    except ValueError as exc:
        raise OptimizationError(str(exc)) from exc

    if not jobs:
        raise OptimizationError("No supported image files were found")

    processed = 0
    skipped = 0
    total_saved = 0
    results: list[OptimizationResult] = []

    for src, dst, effective_format in jobs:
        if dst.exists() and not args.overwrite:
            print(f"[skip] {dst} already exists (use --overwrite)")
            skipped += 1
            continue

        print(f"[opt]  {src} -> {dst}")
        if args.dry_run:
            continue

        dst.parent.mkdir(parents=True, exist_ok=True)

        with Image.open(src) as image:
            original_size = src.stat().st_size
            image = ImageOps.exif_transpose(image)
            image = convert_for_output(image, effective_format)
            image.thumbnail((max_width, max_height or max_width * 100), Image.Resampling.LANCZOS)

            save_kwargs = build_save_kwargs(
                output_format=effective_format,
                quality=quality,
                keep_metadata=args.keep_metadata,
            )
            image.save(dst, **save_kwargs)

        optimized_size = dst.stat().st_size
        saved = max(0, original_size - optimized_size)
        total_saved += saved
        processed += 1
        results.append(
            OptimizationResult(
                src=src,
                dst=dst,
                original_size=original_size,
                optimized_size=optimized_size,
            )
        )

    if results:
        print("\nOptimization summary:")
        for result in results:
            print(
                "  - "
                f"{result.src.name}: "
                f"{format_bytes(result.original_size)} -> {format_bytes(result.optimized_size)} "
                f"(saved {format_bytes(result.saved_bytes)}, {result.saved_percent:.1f}%) | "
                f"{result.dst}"
            )

    print(
        f"Done. processed={processed} skipped={skipped} saved={format_bytes(total_saved)}"
    )
    return 0


def build_jobs(
    input_path: Path,
    output_path: Path,
    recursive: bool,
    output_format: str,
    max_width: int,
    max_height: int | None,
    use_filename_suffix: bool,
) -> Iterable[tuple[Path, Path, str]]:
    if input_path.is_file():
        if input_path.suffix.lower() not in VALID_INPUT_SUFFIXES:
            raise ValueError(f"Unsupported input file type: {input_path.suffix}")
        effective_format = normalized_output_format(output_format, input_path)
        output_name = with_output_suffix(
            input_path.name,
            effective_format,
            max_width=max_width,
            max_height=max_height,
            use_filename_suffix=use_filename_suffix,
        )
        dst = output_path
        if output_path.exists() and output_path.is_dir():
            dst = output_path / output_name
        elif output_path.suffix == "":
            dst = output_path / output_name
        else:
            dst = output_path.with_suffix(suffix_for_format(effective_format))
        yield input_path, dst, effective_format
        return

    if not input_path.is_dir():
        raise ValueError(f"Input is not a file or directory: {input_path}")

    pattern = "**/*" if recursive else "*"
    files = [
        p for p in input_path.glob(pattern) if p.is_file() and p.suffix.lower() in VALID_INPUT_SUFFIXES
    ]
    for src in files:
        effective_format = normalized_output_format(output_format, src)
        rel = src.relative_to(input_path)
        dst = output_path / rel.parent / with_output_suffix(
            rel.name,
            effective_format,
            max_width=max_width,
            max_height=max_height,
            use_filename_suffix=use_filename_suffix,
        )
        yield src, dst, effective_format


def normalized_output_format(output_format: str, src: Path) -> str:
    if output_format != "same":
        return output_format
    suffix = src.suffix.lower()
    if suffix in {".jpg", ".jpeg"}:
        return "jpeg"
    if suffix == ".png":
        return "png"
    if suffix == ".webp":
        return "webp"
    return "jpeg"


def with_output_suffix(
    name: str,
    output_format: str,
    *,
    max_width: int,
    max_height: int | None,
    use_filename_suffix: bool,
) -> str:
    stem = Path(name).stem
    suffix = build_filename_suffix(max_width, max_height) if use_filename_suffix else ""
    return f"{stem}{suffix}{suffix_for_format(output_format)}"


def build_filename_suffix(max_width: int, max_height: int | None) -> str:
    suffix = f"-{max_width}w"
    if max_height:
        suffix += f"-{max_height}h"
    return suffix


def suffix_for_format(output_format: str) -> str:
    return {
        "webp": ".webp",
        "jpeg": ".jpg",
        "png": ".png",
    }[output_format]


def convert_for_output(image, output_format: str):
    from PIL import Image

    if output_format == "png":
        return image.convert("RGBA") if image.mode in {"LA", "P", "RGBA"} else image.convert("RGB")
    if image.mode not in {"RGB", "L"}:
        if output_format in {"jpeg", "webp"}:
            background = Image.new("RGB", image.size, (255, 255, 255))
            if image.mode in {"RGBA", "LA"}:
                background.paste(image, mask=image.getchannel("A"))
                return background
            return image.convert("RGB")
    return image.convert("RGB") if output_format in {"jpeg", "webp"} and image.mode != "RGB" else image


def build_save_kwargs(output_format: str, quality: int, keep_metadata: bool) -> dict:
    kwargs: dict = {"format": output_format.upper() if output_format != "jpeg" else "JPEG"}

    if output_format in {"jpeg", "webp"}:
        kwargs["quality"] = quality
        kwargs["optimize"] = True

    if output_format == "jpeg":
        kwargs["progressive"] = True

    if not keep_metadata:
        kwargs["exif"] = b""
        kwargs["icc_profile"] = None

    return kwargs


def format_bytes(num_bytes: int) -> str:
    if num_bytes < 1024:
        return f"{num_bytes} B"
    units = ["KB", "MB", "GB", "TB"]
    value = float(num_bytes)
    for unit in units:
        value /= 1024
        if value < 1024:
            return f"{value:.2f} {unit}"
    return f"{value:.2f} PB"


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except OptimizationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
