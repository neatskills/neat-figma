---
name: neat-figma-foundation
description: Use when user provides Figma URL(s) to extract design foundation (colors, typography, spacing, sizing, shadows) - supports multiple URLs for multi-page foundations
---

# Extract Design Foundation from Figma

**Role:** You are a UI engineer extracting design foundation primitives from Figma into the theme system.

## Overview

Extract foundation tokens from Figma, generate theme files. Multi-URL support for multi-page libraries.

**Flow:** Detect → Extract → Merge → Compare → Approve → Write

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | One or more Figma URLs (node-id optional) |
| **Output** | `<theme-dir>/colors.ts`, `typography.ts`, etc. |
| **Prerequisites** | FIGMA_ACCESS_TOKEN, product path |
| **Multi-page support** | Yes - merges tokens from multiple URLs |
| **Token categories** | Colors, typography, spacing, sizing, shadows |
| **Comparison** | Shows new/changed/removed tokens |

## Workflow

### Step 1: Parse URLs & Verify Setup

Warn about overwrites:

```
This will overwrite existing assets.
Figma is the source of truth - existing files will be replaced.
Commit your changes first if needed.

Continue? (yes/no)
```

If no: stop. If yes: proceed.

Extract `fileKey` and optional `nodeId` per URL.

Verify FIGMA_ACCESS_TOKEN. If missing: "Set token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product

See [references/product-detection.md](../references/product-detection.md).

Find theme directory per framework (`src/theme`, `lib/constants`, `Resources`).

### Step 3: Extract Foundation

Fetch node data from Figma API per URL.

**Tokens:**

- **Colors**: SOLID fills/strokes (validation needed)
- **Typography**: TEXT nodes (fontSize, fontWeight, lineHeight, fontFamily, letterSpacing)
- **Spacing**: auto-layout padding/itemSpacing (validation needed)
- **Sizing**: dimensions ÷ 4 (validation needed)
- **Shadows**: DROP_SHADOW/INNER_SHADOW

Track usage/source. Merge and deduplicate across URLs.

**CRITICAL: Dual-Source Extraction (API + Screenshot)**

API = precise values (no names). Screenshot = semantic names + structure.

**Process:**

1. Extract values from API (hex/rgb, pixels)

2. Generate Variables panel screenshot:

   ```bash
   # Export Variables panel screenshot via Figma API
   SCREENSHOT_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
     "https://api.figma.com/v1/images/${fileKey}?ids=${nodeId}&format=png&scale=2" \
     | jq -r '.images["'${nodeId}'"]')
   
   # Download screenshot
   curl -s "$SCREENSHOT_URL" -o /tmp/figma-variables-panel.png
   ```

   If fails, request: "Upload Variables panel screenshot (Local Variables → Colors/Spacing/Sizing). REQUIRED for semantic names."

3. Read screenshot for names (PRIMARY SOURCE): `color/primary`, `spacing/xl`, structure chains

4. Match: Screenshot name + API value = `color/primary` = `#FF0000`

5. Generate with semantic names (screenshot) + precise values (API)

**Why both:** API only = guessed names (WRONG). Screenshot only = imprecise values. Both = correct.

**No screenshot:** Ask user for names, document as unvalidated.

### Step 4: Generate & Verify

Generate theme files with usage comments per framework/language.

Verify against screenshot:

```bash
open /tmp/figma-variables-panel.png
```

**Checklist:**

1. ✅ Names match screenshot (`color/primary` not `primaryColor`)
2. ✅ Values precise from API (`#0066CC` not approximations)
3. ✅ Structure preserved (semantic → alias → primitive)
4. ✅ All screenshot tokens included
5. ✅ No extra tokens

If mismatches: regenerate.

### Step 5: Check Components

Search `<component-dir>/`, `<screen-dir>/*/` for hardcoded values (hex, rgb/rgba):

```
Found {N} components with hardcoded values:
- {ComponentName}: {count} hardcoded colors, {count} hardcoded spacing

Refactor to use theme tokens? (yes/no/manual)
```

**yes**: Replace with imports | **no**: Skip, document | **manual**: List for user

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output Files

```
product/
└── <theme-dir>/            # Auto-detected or created
    ├── colors.*           # Generated (extension varies by language)
    ├── typography.*       # Generated
    ├── spacing.*          # Generated (if spacing tokens found)
    ├── sizing.*           # Generated (if sizing tokens found)
    └── shadows.*          # Generated (if shadow styles found)
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Token name generation unclear | Inspect node names in Figma, ask user for preferred names |
| Breaking changes to token values | Show comparison report, user approves changes |
| Token name conflicts | Ask user for resolution |
| Too many similar values | Filter by minimum usage threshold (used 10+ times) |
| Spacing/sizing noise | Only extract values divisible by 4 |
| Wrong token names | ALWAYS use screenshot for semantic names (PRIMARY SOURCE), API for precise values |
| Screenshot generation fails | Fall back to manual request - semantic names ESSENTIAL, cannot be guessed |
| Screenshot shows alias tokens | Extract full chain (`primary → {brand/red} → {primitive/red-500} → #FF0000`) |
| API/screenshot value mismatch | Trust API for value, screenshot for name |
