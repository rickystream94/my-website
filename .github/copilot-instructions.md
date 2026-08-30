# Project Guidelines

## Workspace Layout

- The repository root contains CI/CD and utility tooling. The Hugo site source lives under `mywebsite/`.
- Run Hugo commands from `mywebsite/`, not from the repository root.
- Treat `mywebsite/themes/blowfish/` as a third-party submodule. Prefer overrides in `mywebsite/config/_default/`, `mywebsite/layouts/`, and `mywebsite/assets/` instead of editing the theme.
- Do not edit generated or cache directories unless the task is explicitly about build artifacts or cache cleanup: `mywebsite/public/`, `mywebsite/resources/_gen/`, and `tools/image-optimize/__pycache__/`.

## Architecture

- This project is a Hugo static site built on the Blowfish theme.
- Treat https://blowfish.page/docs/ as the source of truth for default Blowfish theme behavior and configuration; use the checked-in repo files to understand site-specific overrides.
- Content is organized by type:
  - Blog posts are page bundles under `mywebsite/content/blog/<slug>/index.md`.
  - Project pages are standalone Markdown files under `mywebsite/content/projects/`.
  - Top-level pages live under directories such as `mywebsite/content/about/` and `mywebsite/content/experience/`.
- Most published media is served from Azure Blob Storage rather than committed into the repository. Non-secret storage metadata lives in `RemoteStorage/storage-account.json`.
- The custom gallery shortcode at `mywebsite/layouts/shortcodes/gallery.html` intentionally preserves remote image URLs instead of pulling them into the Hugo build output.

## Build And Verification

- Start local development from `mywebsite/` with `hugo server`.
- Use `pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/clean-hugo-cache.ps1 -Force` from `mywebsite/` when remote assets do not refresh as expected.
- Use `pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/clean-hugo-cache.ps1 -Serve` from `mywebsite/` to clear caches and immediately start the local server.
- Use `hugo --minify` from `mywebsite/` for a production build.
- There is no dedicated automated test suite in this repo. The main validation step is a successful Hugo build.
- Deployment is currently handled by GitHub Actions in `.github/workflows/azure-static-web-apps-gentle-pebble-02e20fd03.yml`, which builds the site and uploads the prebuilt `mywebsite/public/` output to Azure Static Web Apps.

## Conventions

- Preserve the existing front matter style and content structure when adding or editing pages.
- Prefer versioned or renamed remote image URLs when replacing an asset. Hugo caches remote resources aggressively, so updating an image at the same URL may require cache cleanup.
- Keep site customizations theme-compatible. Prefer configuration changes, CSS overrides, layout overrides, or shortcodes before considering theme source edits.
- When changing site-wide behavior, inspect `mywebsite/config/_default/config.toml`, `mywebsite/config/_default/params.toml`, and `mywebsite/config/_default/menus.en.toml` first.
- For image preparation or Azure Blob sync workflows, follow the guidance in `tools/image-optimize/README.md` rather than inventing a new local process.
- This repository currently deploys to Azure Static Web Apps via GitHub Actions. Do not assume Azure App Service deployment behavior unless the workflow is changed.