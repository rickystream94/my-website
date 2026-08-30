---
name: "Site Image Workflow"
description: "Help optimize images, sync Azure Blob media, or prepare remote image URLs for this Hugo site using the repo's documented workflow."
argument-hint: "Describe the image task: optimize local files, sync blob images, dry-run a batch, or update content references"
agent: "agent"
---
Help with image optimization and Azure Blob media workflow for this site.

Use these files as the primary source of truth:
- [image-optimize README](../../tools/image-optimize/README.md)
- [storage metadata](../../RemoteStorage/storage-account.json)
- [workspace instructions](../../.github/copilot-instructions.md)

Workflow:
1. Classify the task as one of: optimize local images, sync existing Azure Blob images, prepare upload commands, or update website content references.
2. Ask for any missing operational inputs before taking action. Typical missing inputs are source paths, output roots, preset, blob prefix or blob names, whether this is a dry run, and whether commands should be executed or only prepared.
3. Follow the documented repo workflow instead of inventing new commands.
4. Prefer the existing presets: `gallery`, `featured`, and `thumbnail`.
5. Keep secrets out of the repo and out of generated content. `RemoteStorage/storage-account.json` is only for non-secret metadata.
6. If optimized files will produce new names or extensions, call out the required content-reference updates explicitly.
7. If you make file changes, keep them minimal and consistent with the current content structure.

Output expectations:
- If the user wants guidance, provide the exact commands and the assumptions behind them.
- If the user wants execution, run the documented commands from the correct working directory and summarize the result.
- If content references need to change, list the exact files that should be updated next.
