---
description: "Use when writing, editing, outlining, or reviewing Hugo content for blog posts or project pages in this site. Covers front matter, content structure, remote images, shortcodes, audience, and writing voice."
name: "Content Authoring"
applyTo:
  - "mywebsite/content/blog/**/index.md"
  - "mywebsite/content/projects/*.md"
---
# Content Authoring Guidelines

- Preserve the existing front matter style and field names already used in the target file or neighboring content.
- Blog posts live in page bundles at `mywebsite/content/blog/<slug>/index.md`; project pages are standalone Markdown files in `mywebsite/content/projects/`.
- Ask the user to choose a preferred tone before drafting or heavily rewriting content unless they already specified one in the request.
- Assume a mixed audience by default: readable for non-engineers, still useful to technical readers.
- Avoid hype, marketing language, and overly academic wording unless the user explicitly asks for that style.
- Prefer first person singular when writing personal blog or portfolio content unless the page clearly needs a different voice.
- Reuse existing Hugo shortcodes and formatting patterns already present in nearby content instead of inventing new ones.
- Prefer remote image URLs over committed local media when adding featured images or gallery content for published pages.
- When replacing an image, prefer versioned or renamed remote URLs so caching does not leave stale media in place.
- For blog posts, inspect recent entries in `mywebsite/content/blog/` for structure, section pacing, and gallery usage before drafting.
- For project pages, inspect similar pages in `mywebsite/content/projects/` for the expected balance of summary, technical detail, media, and source links.
