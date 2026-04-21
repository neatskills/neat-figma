---
name: neat-figma-assets
description: Use when user provides Figma URL to extract images, logos, icons, illustrations from Figma designs
---

# Extract Assets from Figma

**Role:** You are a UI engineer extracting and organizing design assets from Figma.

## Overview

Extract and organize design assets from Figma using screenshot-first visual detection. Auto-classifies and generates import structure.

**Principle:** Screenshot → Visual Detect → API Match → Classify → Export → Download → Validate

**Why Screenshot-First:** Complex designs hide assets in deep nesting, component instances, and generic names. Screenshot provides visual context to identify what should be extracted, then API provides node IDs for export.

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

```
TRADITIONAL (fails):                  SCREENSHOT-FIRST (works):
API → Search node tree                Screenshot → Visual identification
   → Find IMAGE nodes                    → "blue car illustration, center, ~400px"
   → Miss: deep nesting                     
   → Miss: INSTANCE nodes             API → Fetch full tree (depth=10)
   → Miss: generic names                 → Match by position + size + name
   → Blind extraction                    → Resolve components if needed
                                          → Find: node "Car_V2" at x:450, y:300, 380px
                                      
                                       Export → Download matched nodes
                                       
                                       Validate → Compare against screenshot
                                                → Ensure all visual assets extracted
```

**Key Insight:** Screenshot shows WHAT to extract (semantic), API provides HOW to extract (node IDs).

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

Find `<asset-dir>` following framework conventions (e.g., `src/assets` for React, `assets` for Flutter, `Resources` for iOS).

### Step 3: Generate Screenshot for Visual Detection

**CRITICAL: Screenshot-first approach** - visual context is PRIMARY source for asset detection.

```bash
# Generate high-res screenshot of the design
SCREENSHOT_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${nodeId}&format=png&scale=2" \
  | jq -r '.images["'${nodeId}'"]')

curl -s "$SCREENSHOT_URL" -o /tmp/figma-assets-detection-${nodeId}.png

# Display for analysis
open /tmp/figma-assets-detection-${nodeId}.png
```

If API fails: "Upload screenshot of the design. REQUIRED for visual asset detection."

### Step 4: Visual Asset Identification

Analyze screenshot to identify extractable assets by visual characteristics:

**Identify:**
- Illustrations (focal graphics, decorative art, characters, objects)
- Icons (UI symbols, action indicators, status markers)
- Logos (brand marks, wordmarks, product logos)
- Photos (product images, hero images, portraits)
- Patterns (repeating graphics if used as discrete elements)

**DON'T extract:**
- UI chrome (buttons, inputs, containers shown as part of mockup)
- Background patterns (if decorative texture, not discrete asset)
- Text (unless it's part of logo SVG)
- Placeholder boxes

**Per asset, note:**
1. Visual description ("blue car illustration", "search icon", "company logo")
2. Approximate position (top-left, center, header, content area)
3. Relative size (small icon ~24px, medium ~100px, large illustration ~400px+)
4. Classification (icon/logo/illustration/photo)

Show list to user:

```
Detected {N} assets from screenshot:

Icons (SVG):
1. search icon - top-right, ~24px
2. menu icon - top-left, ~24px

Illustrations (SVG):
3. blue car illustration - center content, ~400px

Photos (PNG):
4. hero image - header background, ~1200px

Extract these? Or describe any I missed/misidentified.
(yes/adjust)
```

If user adjusts: update list. If yes: proceed.

### Step 5: Fetch Node Tree from Figma API

Fetch full node tree with deep traversal:

```bash
# Fetch node tree
curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}/nodes?ids=${nodeId}&depth=10" \
  > /tmp/figma-node-tree.json
```

Parse response to build flat list of ALL nodes (recursive traversal). Include: `id`, `name`, `type`, `visible`, `absoluteBoundingBox`, `fills`, `componentId`.

### Step 6: Match Visual Assets to API Nodes

For each visually identified asset:

**Matching strategy** (try in order until match found):

1. **Name matching**: Find nodes with matching names (case-insensitive, fuzzy)
   - "car" matches "Car Illustration", "car-vector", "Car_Final_V2"

2. **Position matching**: Filter nodes by approximate position from screenshot
   - Visual "center content" → nodes with `absoluteBoundingBox` x: 400-800, y: 200-600
   - Use loose bounds (±100px tolerance)

3. **Size matching**: Filter by relative size from visual estimate
   - Visual "~400px" → nodes with width/height 300-500px range

4. **Type filtering**: Prefer IMAGE/VECTOR types, but include:
   - IMAGE nodes (direct raster assets)
   - VECTOR nodes (SVG graphics)
   - RECTANGLE/ELLIPSE with image fills
   - INSTANCE nodes (might reference component with asset)

5. **Component resolution**: If matched node is INSTANCE
   ```bash
   # Resolve component definition
   curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
     "https://api.figma.com/v1/files/${fileKey}/nodes?ids=${componentId}" \
     > /tmp/figma-component-${componentId}.json
   ```
   - Traverse component tree to find underlying IMAGE/VECTOR nodes
   - Use component's child IMAGE nodes for export

6. **Deep nesting**: If no match in top 3 levels, traverse full depth
   - Collect ALL IMAGE/VECTOR nodes regardless of nesting
   - Match by position + size only (ignore names in deep nests)

**Per matched asset:**
- Record: `nodeId`, `name`, `type`, `bounds`, `classification`
- If multiple candidates: pick closest position match or ask user

**If no match found:**
```
Could not find API node for: {visual description}

Possible reasons:
- Asset is embedded in component (will search component definitions)
- Asset is background fill (show node tree for manual selection)
- Asset is not exportable (e.g., CSS background)

Should I:
(a) Show full node tree for manual selection
(b) Skip this asset
(c) Export entire frame and crop manually
```

### Step 7: Classify Assets

Confirm classification from Step 4 visual analysis. Allow user override:

- **Icons**: ≤64px, UI-purpose, export as SVG
- **Logos**: Brand graphics, export as SVG
- **Illustrations**: >64px vector art, export as SVG
- **Photos**: Raster images, export as PNG @2x, @3x

Sanitize filenames (lowercase, alphanumeric + hyphens). Handle collisions with numbers.

### Step 8: Export via Figma API

Request export URLs for matched nodeIds:

```bash
# Collect all node IDs
NODE_IDS="nodeId1,nodeId2,nodeId3"

# Export SVG assets
SVG_EXPORT=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=svg")

# Export PNG assets (multi-resolution)
PNG_EXPORT_2X=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=png&scale=2")

PNG_EXPORT_3X=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${NODE_IDS}&format=png&scale=3")
```

Parse JSON to extract download URLs per nodeId.

### Step 9: Download Assets

Download files from export URLs to `<asset-dir>` subdirectories:

```bash
# Create directories
mkdir -p <asset-dir>/images <asset-dir>/icons

# Download SVG assets
for nodeId in $SVG_NODE_IDS; do
  url=$(echo "$SVG_EXPORT" | jq -r ".images[\"$nodeId\"]")
  filename=$(get_filename_for_node $nodeId)  # from classification
  curl -s "$url" -o "<asset-dir>/icons/${filename}.svg"
done

# Download PNG assets (multi-resolution)
for nodeId in $PNG_NODE_IDS; do
  url_2x=$(echo "$PNG_EXPORT_2X" | jq -r ".images[\"$nodeId\"]")
  url_3x=$(echo "$PNG_EXPORT_3X" | jq -r ".images[\"$nodeId\"]")
  filename=$(get_filename_for_node $nodeId)
  
  curl -s "$url_2x" -o "<asset-dir>/images/${filename}@2x.png"
  curl -s "$url_3x" -o "<asset-dir>/images/${filename}@3x.png"
done
```

### Step 10: Validate Extracted Assets

Compare extracted assets against original screenshot:

```bash
# Display original for comparison
open /tmp/figma-assets-detection-${nodeId}.png

# Display extracted assets
open <asset-dir>/images/
open <asset-dir>/icons/
```

**Verification checklist:**

1. All visually identified assets extracted
2. Asset quality appropriate (SVG crisp, PNG high-res)
3. Filenames semantic and collision-free
4. No extra/unwanted assets extracted
5. Classification correct (icon vs illustration vs photo)

If fails: identify gaps, re-run matching for missed assets. If pass: proceed.

### Step 11: Generate Asset Index

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

## Why Screenshot-First Works

**Problem:** API-first blind search fails with complex designs:
- Deep nesting (PAGE > FRAME > GROUP > INSTANCE > IMAGE) hides assets
- Component instances (INSTANCE nodes) hide underlying IMAGE nodes
- No semantic context (can't distinguish content from decoration)
- Generic names ("Rectangle 123") prevent matching

**Solution:** Screenshot provides visual context:
- Human-recognizable assets ("blue car illustration")
- Semantic classification (content vs decoration)
- Position + size anchors for API matching
- Validation loop (compare extracted vs screenshot)

**Flow:** See screenshot → Identify assets → Find in API → Extract

This mirrors how designers work: they see the design visually, then locate elements in the layers panel.

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
