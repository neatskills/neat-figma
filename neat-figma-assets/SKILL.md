---
name: neat-figma-assets
description: Use when user provides Figma URL to extract images, logos, icons, illustrations from Figma designs
---

# Extract Assets from Figma

**Role:** You are a UI engineer extracting and organizing design assets from Figma.

## Overview

Extract and organize design assets from Figma. Auto-classifies and generates import structure.

**Principle:** Parse → Detect → Classify → Export → Download

## When to Use

User provides Figma URL with images, logos, icons, or illustrations.

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | Figma URL (node-id **required** - should be PAGE or FRAME node containing assets) |
| **Output** | `assets/images/`, `assets/icons/` |
| **Prerequisites** | FIGMA_ACCESS_TOKEN, product path |
| **Formats** | SVG (icons/logos), PNG multi-resolution (photos) |
| **Classification** | Auto-classifies by name + size |
| **Asset index** | Generates asset index following framework conventions |

## Workflow

### Step 1: Parse Figma URL

Warn about overwrites:

```
This will overwrite existing assets.
Figma is the source of truth - existing files will be replaced.
Commit your changes first if needed.

Continue? (yes/no)
```

If no: stop and exit.
If yes: proceed.

Extract `fileKey` and `nodeId` from URL. The `node-id` parameter is required and should point to a PAGE or FRAME node containing assets (not a component node).

Verify FIGMA_ACCESS_TOKEN exists. If missing, halt and prompt: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md) for framework detection.

Find asset directory following framework conventions (e.g., `src/assets` for React, `assets` for Flutter, `Resources` for iOS).

### Step 3: Fetch Asset Node from Figma

Fetch node data from Figma API.

### Step 4: Detect Assets

Find assets:

- IMAGE and VECTOR nodes (visible, >10px)
- RECTANGLE/ELLIPSE nodes with image fills

### Step 5: Classify Assets

Show preview of detected assets. Ask: "I'll classify these automatically. Speak up if any should be categorized differently."

Classify by name and size:

- **logo/icon/illustration**: Match keywords
- **VECTOR nodes**: ≤48px → icon (SVG), >48px → illustration (SVG)
- **IMAGE/SHAPE_WITH_IMAGE**: photo (PNG)

Sanitize filenames (lowercase, alphanumeric + hyphens). Handle collisions with numbers.

### Step 6: Export via Figma API

Request export URLs from Figma:

- SVG assets: format=svg
- PNG assets: format=png at scale=2 and scale=3

### Step 7: Download Assets

Download files from export URLs to asset directories. Create directories as needed. PNG files save as `{filename}@2x.png` and `{filename}@3x.png`.

### Step 8: Generate Asset Index

Generate asset index file following framework conventions. Exports grouped by category. Convert filenames to appropriate naming convention. Use multi-resolution suffixes for PNGs when needed.

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output

```
assets/
├── images/           # Logos, photos, illustrations
│   ├── logo.svg
│   ├── hero@2x.png
│   └── hero@3x.png
├── icons/            # UI icons
│   ├── search.svg
│   └── close.svg
└── index.*          # Asset index (extension varies by language)
```

## Common Issues

| Issue | Solution |
|-------|----------|
| No assets detected | Check if node contains IMAGE/VECTOR nodes, try parent node |
| Export URL expired | Figma URLs expire after 24 hours, re-run extraction |
| SVG not rendering | Install framework-specific SVG support and configure build tools |
| PNG too large | Use optimization tools |
| Filename collisions | Script auto-appends numbers (logo-1, logo-2, etc.) |
| Missing multi-resolution assets | Script generates multi-resolution variants when needed for mobile frameworks |
