# image-optimize

Small local Python CLI for batch image optimization before uploading media to Azure Blob Storage.

## What it does

- resizes images to a target max width/height
- converts them to `webp`, `jpeg`, `png`, or keeps the original format
- strips metadata by default
- preserves folder structure when processing directories
- appends automatic size suffixes such as `-1600w` to generated filenames by default
- prints a per-file optimization summary to the console
- supports repeatable presets for website usage

## Presets

- `gallery`
  - max width: `1600`
  - format: `webp`
  - quality: `76`
- `featured`
  - max width: `2000`
  - format: `webp`
  - quality: `80`
- `thumbnail`
  - max width: `800`
  - format: `webp`
  - quality: `72`

## Setup

From `tools/image-optimize`:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

For Azure Blob Storage sync, also make sure:

- `Az` PowerShell modules are installed
- you are signed in with `Connect-AzAccount`
- your identity has storage data-plane access to the `richmondwebmedia` account

Optional repo-level config file:

- `RemoteStorage/storage-account.json`

Example:

```json
{
  "tenantId": "<your-tenant-id>",
  "subscriptionId": "<your-subscription-id>",
  "storageAccountName": "richmondwebmedia",
  "containerNames": ["media"]
}
```

This file is intended only for non-secret Azure metadata. Do **not** put storage keys,
connection strings, SAS tokens, or client secrets in it.

## Usage

### Optimize one file

```powershell
python .\image_optimize.py "C:\photos\DSCF7613.JPG" ".\out" --preset gallery
```

This will typically create a file like:

```text
out/DSCF7613-1600w.webp
```

### Optimize a whole folder recursively

```powershell
python .\image_optimize.py "C:\photos\tromso" ".\out\tromso" --preset gallery --recursive
```

### Create featured images

```powershell
python .\image_optimize.py "C:\photos\featured" ".\out\featured" --preset featured --recursive
```

### Keep JPEG output instead of WebP

```powershell
python .\image_optimize.py "C:\photos\featured" ".\out\featured" --preset featured --format jpeg --recursive
```

### Keep original filename without the automatic suffix

```powershell
python .\image_optimize.py "C:\photos\featured" ".\out\featured" --preset featured --recursive --no-filename-suffix
```

### Preview actions without writing files

```powershell
python .\image_optimize.py "C:\photos\tromso" ".\out\tromso" --preset gallery --recursive --dry-run
```

### Example console summary

After a real run, the script prints a compact summary like:

```text
Optimization summary:
  - DSCF7613.JPG: 15.46 MB -> 742.10 KB (saved 14.73 MB, 95.3%) | .\out\DSCF7613-1600w.webp
Done. processed=1 skipped=0 saved=14.73 MB
```

## Notes

- The tool does **not** modify originals.
- Output images are written to the destination path you provide.
- Existing files are skipped unless you pass `--overwrite`.
- WebP output depends on your Pillow build supporting WebP.
- For website delivery, keep the originals elsewhere and upload only optimized outputs.
- By default, output filenames get a width-based suffix like `-1600w` so optimized variants are easier to version and identify.

## Suggested workflow for this site

1. Keep original camera files in a separate archive folder.
2. Run this tool on the images you want to publish.
3. Upload the optimized output files to Azure Blob Storage.
4. Reference the optimized URLs from Hugo content.
5. Use versioned filenames when replacing assets.

## Optimize existing images already stored in Azure Blob Storage

Use `Sync-BlobImages.ps1` to:

1. enumerate blob containers and blobs
2. download them locally while preserving container/folder structure
3. optimize only the currently selected local image files that match the requested blob filters
4. upload only those optimized files back to the same storage account as new suffixed blob names

The script uses the repo config at `RemoteStorage/storage-account.json` for Azure defaults such as tenant, subscription, storage account, and container.

### Folder layout used by the script

Downloaded files:

```text
<DownloadRoot>/<container>/<blob-path>
```

Optimized files:

```text
<OptimizedRoot>/<container>/<blob-path>
```

### Parameters

The current `Sync-BlobImages.ps1` supports these parameters:

- `-DownloadRoot` **(required)**
  - Local root folder where blobs are downloaded.
  - The script mirrors the container/blob structure underneath this folder.

- `-OptimizedRoot` **(required)**
  - Local root folder where optimized images are written.
  - The script mirrors the same container/blob structure here as well.

- `-BlobPrefix`
  - One or more blob path prefixes to limit processing to a specific “folder-like” area.
  - Example: `blog/2025-01_my_2024_recap/tromso/`

- `-BlobName`
  - One or more exact blob paths to process.
  - Useful for targeting a handful of known files.

- `-Preset`
  - Optimization preset passed to `image_optimize.py`.
  - Supported values: `gallery`, `featured`, `thumbnail`.
  - Default: `gallery`
  - The preset defines the optimization intent, including default size, quality, and output format.

- `-ForceDownload`
  - Re-download blobs even if the local downloaded copy already exists.
  - Without this switch, existing local downloads are skipped.

- `-ForceOptimize`
  - Re-run optimization even if the expected optimized local output file already exists.
  - Without this switch, the optimization step is idempotent and existing optimized files are skipped by the Python tool.

- `-ForceUpload`
  - Allow upload to replace an already-existing optimized target blob with the same name.
  - This does **not** replace the original source blob path; it only affects reruns against the optimized target path.

- `-KeepMetadata`
  - Preserves image metadata where possible during optimization.
  - In practice, this means EXIF/ICC metadata is kept instead of being stripped.
  - Use this if you want to keep things like camera metadata, embedded color profile, or other image metadata.
  - Leave it off if you want smaller files and do not need that metadata.

- `-SkipDownload`
  - Skip the blob download step.
  - Useful if you already downloaded the target blobs and only want to re-run optimization/upload.

- `-SkipUpload`
  - Skip the blob upload step.
  - Useful if you only want to download + optimize locally first.

### Values loaded from config instead of parameters

The script currently loads these from `RemoteStorage/storage-account.json`:

- `tenantId`
- `subscriptionId`
- `storageAccountName`
- `containerName`

You normally do not need to pass those on the command line.

### Why the preset defines the output format

The sync script now lets the selected preset define the optimization intent.

With the current built-in presets, that means the output format is **WebP**:

- `gallery` → `1600px`, WebP, quality `76`
- `featured` → `2000px`, WebP, quality `80`
- `thumbnail` → `800px`, WebP, quality `72`

So with the current sync workflow, an older file like:

- `photo.jpg`

will typically become:

- `photo-1600w.webp`

That is now fine for your migration workflow because the script uploads optimized images as **new suffixed blob names**, and you are comfortable updating both the filename and the extension in your content references afterward.

### Example: full storage account sync

```powershell
Connect-AzAccount

pwsh .\Sync-BlobImages.ps1 `
  -DownloadRoot "C:\temp\richmondwebmedia-raw" `
  -OptimizedRoot "C:\temp\richmondwebmedia-optimized"
```

### Example: limit to a specific folder/prefix

```powershell
pwsh .\Sync-BlobImages.ps1 `
  -DownloadRoot "C:\temp\raw" `
  -OptimizedRoot "C:\temp\optimized" `
  -BlobPrefix "blog/2025-01_my_2024_recap/tromso/"
```

### Example: limit to specific files

```powershell
pwsh .\Sync-BlobImages.ps1 `
  -DownloadRoot "C:\temp\raw" `
  -OptimizedRoot "C:\temp\optimized" `
  -BlobName "static_assets/about/2021_hackaton1.JPG","static_assets/about/2021_hackaton2.JPG"
```

### Example: preview only

```powershell
pwsh .\Sync-BlobImages.ps1 `
  -DownloadRoot "C:\temp\raw" `
  -OptimizedRoot "C:\temp\optimized" `
  -WhatIf
```

### Example: force a full re-download + re-optimize + re-upload of the selected batch

```powershell
pwsh .\Sync-BlobImages.ps1 `
  -DownloadRoot "C:\temp\raw" `
  -OptimizedRoot "C:\temp\optimized" `
  -BlobPrefix "blog/2025-01_my_2024_recap/tromso/" `
  -ForceDownload `
  -ForceOptimize `
  -ForceUpload
```

### Notes about the Azure sync script

- You can limit work to folder-like blob prefixes and/or exact blob names.
- The optimize/upload phases operate only on the files selected by the current blob filters, even if `raw` or `optimized` already contain files from previous runs.
- The optimization step is idempotent by default: if the expected optimized local file already exists, it will not be regenerated unless you pass `-ForceOptimize`.
- The script keeps automatic filename suffixes enabled, so optimized uploads are new blob names like `photo-1600w.webp` or `photo-2000w.webp`.
- The upload step does not overwrite existing optimized target blobs unless you explicitly pass `-ForceUpload` and rerun against the same optimized target names.
- This is safer for already-published images because the original URLs remain valid until you update website references yourself.
- For future uploads, you can still use `image_optimize.py` directly and keep the width-based filename suffixes.
