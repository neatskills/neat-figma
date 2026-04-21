---
name: neat-figma-assets
description: Use when user provides Figma URL to extract images, logos, icons, illustrations from Figma designs
---

# Extract Assets from Figma

**Role:** You are a UI engineer extracting and organizing design assets from Figma.

## Overview

Extract and organize design assets from Figma using screenshot-first visual detection.

**Flow:** Screenshot → Detect → Match → Classify → Document → Export → Validate

**Markdown-first:** Generate inventory documentation, show diffs, then export files.

**Why Screenshot-First:** Complex designs hide assets in nested structures with generic names. Screenshot provides visual context for identification, API provides node IDs for export.

## When to Use

User provides Figma URL with images, logos, icons, or illustrations.

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | Figma URL (node-id **required** - should be PAGE or FRAME node containing assets) |
| **Output** | `assets/images/`, `assets/icons/` |
| **Prerequisites** | FIGMA_ACCESS_TOKEN, product path |
| **Screenshot** | Step 3 REQUIRED - primary source for asset identification |
| **Formats** | SVG (icons/logos), PNG multi-resolution (photos) |
| **Classification** | Visual-first (screenshot), confirmed by position/size/type matching |
| **Asset index** | Generates asset index following framework conventions |
| **Validation** | Step 10 compares extracted assets against screenshot |

## Screenshot-First Detection Strategy

**Traditional (fails):** API → Search IMAGE nodes → Misses deep nesting, INSTANCE nodes, generic names → Blind extraction

**Screenshot-first (works):** Screenshot → Visual ID ("blue car, center, ~400px") → API tree (depth=10) → Match by position/size/name → Resolve components → Export matched nodes → Validate

**Key:** Screenshot shows WHAT to extract (semantic), API provides HOW (node IDs).

## Workflow

### Step 1: Parse Figma URL

Warn about overwrites:

```
This will overwrite existing files.
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

Find `<asset-dir>` following framework conventions (e.g., `src/assets` for React, `assets` for Flutter, `Resources` for iOS).

### Step 2.5: Check Existing Markdown

Check if `docs/design-system/assets.md` exists and compare versions:

```bash
if [ -f "docs/design-system/assets.md" ]; then
  STORED_VERSION=$(grep "figmaVersion:" docs/design-system/assets.md | cut -d'"' -f2)
  CURRENT_VERSION=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
    "https://api.figma.com/v1/files/${fileKey}" | jq -r '.version')
  GIT_STATUS=$(git status --porcelain docs/design-system/assets.md 2>/dev/null)
fi
```

**If versions match AND no edits:** Prompt to use existing (skip to Step 11) or force re-extract (continue).

**If versions differ OR has edits:** Prompt to use existing (preserves edits, validates nodeIds) or re-extract (shows diff in Step 9).

**Note:** Using existing validates nodeIds before export. If nodes deleted/moved in Figma, export fails and requires re-extraction.

### Step 3: Generate Screenshot

**CRITICAL:** Screenshot is PRIMARY source for asset detection.

```bash
SCREENSHOT_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${nodeId}&format=png&scale=2" \
  | jq -r '.images["'${nodeId}'"]')

curl -s "$SCREENSHOT_URL" -o /tmp/figma-assets-detection-${nodeId}.png
open /tmp/figma-assets-detection-${nodeId}.png
```

If API fails: Request manual upload (REQUIRED).

### Step 4: Visual Identification

Analyze screenshot to identify extractable assets.

**Extract:** Illustrations, icons, logos, photos, discrete patterns
**Exclude:** UI chrome, background patterns, text, placeholder boxes

**Record per asset:**

1. Description ("blue car illustration", "search icon")
2. Position (top-left, center, header)
3. Size (~24px, ~100px, ~400px+)
4. Type (icon/logo/illustration/photo)

Present list:

```
Detected {N} assets:

Icons (SVG): search icon (top-right, ~24px), menu icon (top-left, ~24px)
Illustrations (SVG): blue car (center, ~400px)
Photos (PNG): hero image (header, ~1200px)

Extract these? Or describe any I missed/misidentified. (yes/adjust)
```

Update if user adjusts, proceed if approved.

### Step 5: Fetch Node Tree

```bash
curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}/nodes?ids=${nodeId}&depth=10" \
  > /tmp/figma-node-tree.json
```

Parse to flat list: `id`, `name`, `type`, `visible`, `absoluteBoundingBox`, `fills`, `componentId`.

### Step 6: Match to API Nodes

For each asset, match using (try in order):

1. **Name matching**: Fuzzy, case-insensitive ("car" → "Car Illustration", "car-vector", "Car_Final_V2")
2. **Position matching**: Match `absoluteBoundingBox` (±100px tolerance)
3. **Size matching**: Match width/height to visual estimate (±20% range)
4. **Type filtering**: IMAGE, VECTOR, RECTANGLE/ELLIPSE with fills, INSTANCE nodes
5. **Component resolution**: If INSTANCE, resolve componentId:

   ```bash
   curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
     "https://api.figma.com/v1/files/${fileKey}/nodes?ids=${componentId}" \
     > /tmp/figma-component-${componentId}.json
   ```

   Traverse for underlying IMAGE/VECTOR nodes.
6. **Deep nesting**: If no match in top 3 levels, traverse full depth, match by position + size only.

**Record:** `nodeId`, `name`, `type`, `bounds`, `classification`. If multiple candidates, pick closest position or ask user.

**If no match:** Offer to show node tree, skip asset, or export entire frame.

### Step 7: Classify Assets

Confirm classification from Step 4, allow override:

- **Icons**: ≤64px, UI-purpose → SVG
- **Logos**: Brand graphics → SVG
- **Illustrations**: >64px vector art → SVG
- **Photos**: Raster → PNG @2x, @3x

Sanitize filenames (lowercase, alphanumeric, hyphens). Handle collisions with numbers.

### Step 8: Generate Markdown

Ask for path (default: `docs/design-system`). Generate `<path>/assets.md`:

```markdown
---
type: assets
source: https://figma.com/file/{fileKey}?node-id={nodeId}
figmaName: "{fileName}"
figmaVersion: "{version}"
figmaLastModified: "{lastModified}"
extracted: {YYYY-MM-DDTHH:mm:ssZ}
assetCount: {N}
---

# Assets

## Icons (SVG)

### search-icon
- **nodeId**: 123:456
- **path**: assets/icons/search.svg
- **size**: 24px × 24px

## Illustrations (SVG)

### hero-illustration
- **nodeId**: 123:458
- **path**: assets/images/hero.svg
- **size**: 400px × 300px

## Photos (PNG)

### product-photo
- **nodeId**: 123:459
- **path**: assets/images/product@2x.png, product@3x.png
- **dimensions**: 800px × 600px (@2x), 1200px × 900px (@3x)

## Logos (SVG)

### company-logo
- **nodeId**: 123:460
- **path**: assets/images/logo.svg
- **size**: 120px × 40px
```

### Step 9: Show Diff

If markdown exists:

```bash
git diff --no-index <existing> <new> || diff -u <existing> <new>
```

Present changes:

```
Changes:
Icons:
  + search-icon (new)
  ~ menu-icon: 24px → 20px
  - old-icon (removed)
Illustrations:
  + hero-illustration (new)
Photos:
  ~ product-photo: single → multi-resolution

Review? (show/approve/cancel)
```

### Step 10: Review

```
Markdown: {path}/assets.md
Ready to export? (yes/no/later)
```

**yes:** Step 11 | **no/later:** Stop (user edits, exports later)

### Step 11: Export

```bash
NODE_IDS="nodeId1,nodeId2,nodeId3"

SVG_EXPORT=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=svg")

PNG_EXPORT_2X=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=png&scale=2")

PNG_EXPORT_3X=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=png&scale=3")
```

Parse URLs per nodeId. Validate nodes exist:

```bash
MISSING=$(echo "$SVG_EXPORT" | jq -r '.err // empty')
if [ -n "$MISSING" ]; then
  echo "ERROR: Nodes deleted/moved: $MISSING"
  echo "Re-run Step 3 to update markdown"
  exit 1
fi
```

### Step 12: Download

```bash
mkdir -p <asset-dir>/images <asset-dir>/icons

for nodeId in $SVG_NODE_IDS; do
  url=$(echo "$SVG_EXPORT" | jq -r ".images[\"$nodeId\"]")
  filename=$(get_filename_for_node $nodeId)
  curl -s "$url" -o "<asset-dir>/icons/${filename}.svg"
done

for nodeId in $PNG_NODE_IDS; do
  url_2x=$(echo "$PNG_EXPORT_2X" | jq -r ".images[\"$nodeId\"]")
  url_3x=$(echo "$PNG_EXPORT_3X" | jq -r ".images[\"$nodeId\"]")
  filename=$(get_filename_for_node $nodeId)
  curl -s "$url_2x" -o "<asset-dir>/images/${filename}@2x.png"
  curl -s "$url_3x" -o "<asset-dir>/images/${filename}@3x.png"
done
```

### Step 13: Validate

```bash
open /tmp/figma-assets-detection-${nodeId}.png
open <asset-dir>/images/
open <asset-dir>/icons/
```

**Verify:**

1. All identified assets extracted
2. Quality appropriate (SVG crisp, PNG high-res)
3. Filenames semantic, no collisions
4. No unwanted assets
5. Classification correct

If fails: identify gaps, re-run matching. If pass: proceed.

### Step 14: Generate Asset Index

Generate asset index file following framework conventions. Exports grouped by category. Convert filenames to appropriate naming convention. Use multi-resolution suffixes for PNGs when needed.

## Regenerating from Markdown

If user has markdown but needs re-export:

1. Read `docs/design-system/assets.md`
2. Parse inventory (nodeIds, paths, classifications)
3. Export (Step 11) → Download (Step 12) → Validate (Step 13)
4. Skip detection/matching (markdown is source of truth)

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
| Screenshot generation fails | Fall back to manual upload - screenshot is REQUIRED for visual detection |
| Asset not found in API | Try component resolution, show node tree for manual selection, or export entire frame |
| Multiple nodes match position | Pick closest bounds match or ask user to identify |
| Deep nesting hides assets | Fetch with depth=10, traverse full tree, match by position only |
| Component instances hide IMAGE | Resolve componentId, traverse component definition tree |
| Export URL expired | Figma URLs expire after 24 hours, re-run extraction |
| SVG not rendering | Install framework-specific SVG support and configure build tools |
| PNG too large | Use optimization tools (imagemin, tinypng) |
| Filename collisions | Auto-append numbers (logo-1, logo-2, etc.) |
| Wrong classification | User override in Step 7 before extraction |
| Extracting UI chrome | Screenshot analysis should exclude mockup UI - only discrete assets |
