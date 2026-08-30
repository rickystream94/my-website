---
description: "Use when editing or reviewing Hugo config, Blowfish overrides, layouts, shortcodes, custom CSS, or deployment workflow files for this site. Covers theme compatibility, regression checks, and required validation."
name: "Theme And Config Review"
applyTo:
  - "mywebsite/config/_default/**"
  - "mywebsite/layouts/**"
  - "mywebsite/assets/**"
  - ".github/workflows/**"
---
# Theme And Config Review Guidelines

- Treat https://blowfish.page/docs/ as the default source of truth for Blowfish theme behavior and configuration semantics.
- Treat `mywebsite/themes/blowfish/` as a third-party submodule; prefer overrides in `mywebsite/config/_default/`, `mywebsite/layouts/`, and `mywebsite/assets/`.
- Do not edit generated Hugo output or cache directories when changing behavior: `mywebsite/public/` and `mywebsite/resources/_gen/`.
- When changing layout or shortcode behavior, check whether the change could accidentally pull remote assets into the build output or otherwise increase deployment size.
- Preserve the existing remote-image behavior in `mywebsite/layouts/shortcodes/gallery.html` unless the task explicitly requires changing it.
- When changing site-wide behavior, inspect `mywebsite/config/_default/config.toml`, `mywebsite/config/_default/params.toml`, and `mywebsite/config/_default/menus.en.toml` first.
- When editing deployment behavior, align changes with `.github/workflows/azure-static-web-apps-gentle-pebble-02e20fd03.yml`, which currently deploys prebuilt `mywebsite/public/` output to Azure Static Web Apps.
- After relevant edits, validate with `hugo --minify` from `mywebsite/` unless the user explicitly says not to run verification.
