---
name: neat-figma-foundation
description: Use when user provides Figma URL(s) to extract design foundation (colors, typography, spacing, sizing, shadows) - supports multiple URLs for multi-page foundations
---

# Extract Design Foundation from Figma

**Role:** You are a UI engineer extracting design foundation primitives from Figma into the theme system.

## Overview

Extract foundation tokens from Figma, generate theme files. Multi-URL support for multi-page libraries.

**Flow:** Detect → Extract → Markdown → Diff → Approve → Code

**Markdown-first:** Generate markdown documentation, check for changes, then optionally generate code files.

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
This will overwrite existing files.
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

### Step 2.5: Check for Existing Markdown (Cross-Skill Awareness)

Before extracting from Figma, check if foundation markdown exists and compare Figma version:

```bash
if [ -f "docs/design-system/foundation.md" ]; then
  # Extract stored Figma version
  STORED_VERSION=$(grep "figmaVersion:" docs/design-system/foundation.md | cut -d'"' -f2)
  
  # Fetch current Figma version
  CURRENT_VERSION=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
    "https://api.figma.com/v1/files/${fileKey}" | jq -r '.version')
  
  # Check if manually edited
  GIT_STATUS=$(git status --porcelain docs/design-system/foundation.md 2>/dev/null)
fi
```

**If versions match AND no manual edits:**

```
Foundation markdown up-to-date (Figma version {version}, no changes)

Options:
1. Use existing markdown → skip to code generation (Step 9)
2. Force re-extract from Figma (continue to Step 3)
3. Cancel

Choose (1/2/3):
```

**If versions differ OR manual edits detected:**

```
Foundation markdown needs update:
- Stored Figma version: {storedVersion}
- Current Figma version: {currentVersion}
- Manual edits: {yes/no}

Options:
1. Use existing markdown → skip to code generation (Step 9) [preserves manual edits, ignores Figma updates]
2. Extract from Figma → update markdown (continue to Step 3) [Step 7 will show diff including version]
3. Cancel → review changes first

Choose (1/2/3):
```

**Option 1:** Skip to Step 9 (preserves manual edits, may be stale)
**Option 2:** Continue extraction (Step 7 shows diff with version info)
**Option 3:** Stop

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

### Step 5: Fetch Figma Version

Before generating markdown, get Figma version for tracking:

```bash
# Fetch file metadata
curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}" > /tmp/figma-file-meta.json

# Extract version info
FIGMA_VERSION=$(jq -r '.version' /tmp/figma-file-meta.json)
FIGMA_LAST_MODIFIED=$(jq -r '.lastModified' /tmp/figma-file-meta.json)
FIGMA_NAME=$(jq -r '.name' /tmp/figma-file-meta.json)
```

### Step 6: Generate Markdown Documentation

Ask for markdown path:

```
Path for markdown documentation? (default: docs/design-system)
```

Generate `<path>/foundation.md` with structured format:

```markdown
---
type: design-foundation
source: https://figma.com/file/{fileKey}
figmaName: "{fileName}"
figmaVersion: "{version}"
figmaLastModified: "{lastModified}"
extracted: {YYYY-MM-DDTHH:mm:ssZ}
---

# Design Foundation

## Colors

### color/primary
- **value**: `#0066CC`
- **type**: semantic
- **usage**: Primary actions, links, brand elements

### color/neutral/100
- **value**: `#F5F5F5`
- **type**: primitive
- **usage**: Background surfaces

## Typography

### heading/h1
- **fontFamily**: Inter
- **fontWeight**: 700
- **fontSize**: 32px
- **lineHeight**: 40px
- **letterSpacing**: -0.02em
- **usage**: Page titles, hero headings

## Spacing

### xs
- **value**: 4px
- **usage**: Tight internal spacing

### sm
- **value**: 8px
- **usage**: Compact component spacing

## Sizing

### icon/sm
- **value**: 16px

## Shadows

### elevation/low
- **offsetX**: 0px
- **offsetY**: 2px
- **blur**: 4px
- **spread**: 0px
- **color**: rgba(0, 0, 0, 0.1)
- **usage**: Cards, subtle elevation
```

**Structured format requirements:**

- Use `###` for token names
- Use `- **field**: value` format (lowercase field names)
- Include `value`, `usage` for all tokens
- Typography: separate fields for fontFamily, fontWeight, fontSize, lineHeight, letterSpacing
- Spacing: semantic names (xs, sm, md, lg) not raw numbers
- Shadows: full properties (offsetX, offsetY, blur, spread, color)

### Step 7: Check for Existing Markdown

If markdown file exists at same path:

```bash
# Show diff
git diff --no-index <existing-file> <new-file> || diff -u <existing-file> <new-file>
```

Present changes:

```
Changes detected in foundation tokens:

Colors:
  + color/success: #00C853 (new)
  ~ color/primary: #0066CC → #0052A3 (changed)
  - color/accent: #FF6B6B (removed)

Typography:
  ~ heading/h1: 32px → 36px (fontSize changed)

Review changes? (show/approve/cancel)
```

**show:** Display full diff
**approve:** Continue to next step
**cancel:** Stop, keep existing

### Step 8: User Review & Edit

After showing changes (or if new):

```
Markdown generated at {path}/foundation.md

You can:
1. Review and edit the markdown file manually
2. Continue to generate code

Ready to generate code? (yes/no/later)
```

**yes:** Proceed to Step 8
**no/later:** Stop, user can edit markdown and run generation later

### Step 9: Generate Code from Markdown

Read markdown file and generate theme files:

**Parse markdown:**

- Extract tokens from `###` headers
- Parse `- **field**: value` lines
- Build token objects per category

**Generate per framework:**

- React/Next: TypeScript with typed constants
- React Native: JavaScript with StyleSheet
- iOS: Swift with enums
- Android: Kotlin with sealed classes

**Output:** `<theme-dir>/colors.*`, `typography.*`, `spacing.*`, etc.

Verify against screenshot (same checklist as current Step 4).

### Step 10: Check Components

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

**Code files:**

```
product/
└── <theme-dir>/            # Auto-detected or created
    ├── colors.*           # Generated (extension varies by language)
    ├── typography.*       # Generated
    ├── spacing.*          # Generated (if spacing tokens found)
    ├── sizing.*           # Generated (if sizing tokens found)
    └── shadows.*          # Generated (if shadow styles found)
```

**Markdown documentation (if requested):**

```
docs/design-system/         # Default path
└── foundation.md          # Consolidated design tokens
```

## Token Contract Documentation

**For downstream skills (component/page):**

Foundation exports theme tokens that components and pages import. Token contract:

- **Colors**: Semantic names (`color/primary`, `color/neutral/100`) mapped to hex values
- **Typography**: Font families, weights, sizes, line heights, letter spacing
- **Spacing**: Semantic scale (xs, sm, md, lg, xl) for padding/margins
- **Sizing**: Preset dimensions for icons, buttons, avatars
- **Shadows**: Named elevation levels

**Validation expectations:**

Components and pages check for `<theme-dir>/` existence and import available tokens. If tokens exist, they replace hardcoded values. If tokens don't exist or specific token missing, components hardcode with `// TODO: use theme token` comment.

**Token naming convention:** Use `/` separator for hierarchy (`color/primary`, `spacing/md`) to enable tree-shaking and autocomplete.

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

## Regenerating Code from Existing Markdown

**When:** You have foundation markdown with manual edits and want to regenerate code without re-extracting from Figma.

**How:**

1. Run `/neat-figma-foundation` with any Figma URL (or same URL as before)
2. At Step 2.5, choose Option 1: "Use existing markdown"
3. Skill skips to Step 9 (Generate Code from Markdown)
4. Reads `docs/design-system/foundation.md`
5. Generates code files in `<theme-dir>/`

**What's skipped:**

- Figma API calls (no token extraction)
- Screenshot generation (not needed for code gen)
- Markdown generation (uses existing file)

**What's preserved:**

- All manual edits in markdown
- Custom usage notes
- Modified token names/values
- Token additions/removals

**Use case:** Designer made changes in markdown (added custom tokens, fixed naming), engineer regenerates code to match.
