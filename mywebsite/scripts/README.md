# Scripts

## `clean-hugo-cache.ps1`

Clears Hugo-generated output and cache folders so a normal `hugo server` run will pick up changes (especially useful when updating remote images used by `resources.GetRemote`).

### What it deletes

By default:

- `public/`
- `resources/_gen/`
- Hugo temp cache folders (commonly `%TEMP%\\hugo_cache` on Windows)

### Usage (PowerShell)

Run from the `mywebsite/` folder:

- Clean only:
  - `./scripts/clean-hugo-cache.ps1`

- Clean and start the dev server:
  - `./scripts/clean-hugo-cache.ps1 -Serve`

- Skip deleting `public/`:
  - `./scripts/clean-hugo-cache.ps1 -NoPublic`

- Skip deleting the global temp cache:
  - `./scripts/clean-hugo-cache.ps1 -NoTempCache`

- No confirmation prompt:
  - `./scripts/clean-hugo-cache.ps1 -Force`

### Notes

- After clearing temp caches, Hugo may re-download remote resources on the next build.
- If you overwrite a remote image at the same URL, consider cache-busting by changing the URL (e.g., `featured.png?v=20260214`) for a more reliable long-term workflow.
