---
name: neat-figma-foundation
description: Use when user provides Figma URL(s) to extract design foundation (colors, typography, spacing, sizing, shadows) - supports multiple URLs for multi-page foundations
---

# Extract Design Foundation from Figma

**Role:** You are a UI engineer extracting design foundation primitives from Figma into the theme system.

## Overview

Extract theme tokens from Figma, generate theme files. Multi-URL support for multi-page libraries.

**Flow:** Detect → Extract → Markdown → Diff → Approve → Code

**Markdown-first:** Generate markdown documentation, check for changes, then optionally generate code files.

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | One or more Figma URLs (node-id optional - targets specific token panels if provided) |
| **Output** | `<theme-dir>/colors.ts`, `typography.ts`, etc. |
| **Prerequisites** | FIGMA_ACCESS_TOKEN (file_content:read scope), product path |
| **Multi-page support** | Yes - merges theme tokens from multiple URLs |
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

**Node-id usage:**

- **If provided:** Screenshot and extract tokens from specific FRAME nodes
- **If missing:** Search entire file for token panels matching naming patterns (e.g., "Token", "Foundation", "Primitives")

Verify FIGMA_ACCESS_TOKEN. If missing: "Set token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product

See [references/product-detection.md](../references/product-detection.md).

Find theme directory per framework (`src/theme`, `lib/constants`, `Resources`).

### Step 2.5: Check for Existing Markdown (Cross-Skill Awareness)

Check if `docs/design-system/foundation.md` exists. Compare versions:

```bash
STORED_VERSION=$(grep "figmaVersion:" docs/design-system/foundation.md | cut -d'"' -f2 || echo "unknown")
CURRENT_VERSION=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}" | jq -r '.version // "unknown"')
GIT_STATUS=$(git status --porcelain docs/design-system/foundation.md 2>/dev/null || echo "")
```

**If API fails:** Prompt "Continue with re-extraction (skips version check)?" If no: exit with "Fix API access or use existing markdown."

| Condition | Options |
|-----------|---------|
| **Versions match, no edits** | 1. Use existing → Step 9 (markdown-only) 2. Force re-extract → Step 3 3. Cancel |
| **Versions differ OR edits** | 1. Use existing → Step 9 (preserves edits) 2. Extract → Step 3 (shows diff at Step 7) 3. Cancel |

**Option 1:** Markdown-only validation (no screenshot). **Option 2:** Full re-extraction with diff review.

### Step 3: Extract Foundation

**Screenshot each token panel individually at high resolution:**

```bash
# Find all FRAME nodes containing token tables
NODE_TYPE="FRAME"
FILTER_PATTERN="Token"
SCALE=3

# Fetch file and find matching nodes
NODES=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}" | \
  jq -r --arg type "$NODE_TYPE" --arg pattern "$FILTER_PATTERN" '
    .. | objects |
    select(.type == $type and (.name | test($pattern))) |
    "\(.id)|\(.name)"
  ')

# Screenshot each node
echo "$NODES" | while IFS='|' read -r node_id node_name; do
  safe_name=$(echo "$node_name" | tr '/ ' '_' | tr -cd '[:alnum:]_-')
  output_path="/tmp/figma-node-${safe_name}.png"
  
  # Get screenshot URL
  screenshot_url=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
    "https://api.figma.com/v1/images/${fileKey}?ids=${node_id}&scale=${SCALE}&format=png" | \
    jq -r ".images[\"${node_id}\"]")
  
  # Download screenshot
  curl -s "$screenshot_url" -o "$output_path"
  echo "Screenshot saved: $output_path"
done
```

Generates scale=3 screenshots: `/tmp/figma-node-{PanelName}.png` (one per token panel).

**Rationale:** Individual panels at scale=3 make token names/values readable (vs. full canvas = tiny text).

**Read each screenshot:** Extract token table (Name, Value, Description) → Parse to JSON:

```json
{"name": "color/primary", "value": "#0066CC", "description": "Primary brand color"}
```

**Token types:** Primitive (`color/red/500`), semantic (`color/primary` → `{color/red/500}`), component (`button/bg` → `{color/primary}`). Preserve reference chains.

### Step 4: Extract Tokens from Panel Screenshots

For each screenshot, read and parse the token table:

| Column | Content | Example |
|--------|---------|---------|
| 1 | Token name | `color/primary`, `spacing/md` |
| 2 | Value | `#0066CC`, `16px`, `{ref}` (alias) |
| 3 | Description | Usage notes (optional) |

**Extract to JSON:**

```json
{"panel": "GUI_SemanticColorTokens", "tokens": [
  {"name": "color/primary", "value": "{color/brand/blue-600}", "type": "alias"},
  {"name": "color/brand/blue-600", "value": "#0066CC", "type": "primitive"}
]}
```

**Aliases:** `{reference}` → mark as alias, track chain, resolve later.

**Verify:** Spot-check 5-10 tokens against screenshot.

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

**yes:** Proceed to Step 9
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

**Note:** When regenerating from markdown, validation uses structured markdown fields instead of screenshot comparison.

### Step 10: Check Components

Search `<component-dir>/`, `<screen-dir>/*/` for hardcoded values (hex, rgb/rgba):

```
Found {N} components with hardcoded values:
- {ComponentName}: {count} hardcoded colors, {count} hardcoded spacing

Refactor to use theme tokens? (yes/no/manual)
```

**yes**: Replace with imports | **no**: Skip, document | **manual**: List for user

## Prerequisites

**Figma Access Token:**

- Required scope: `file_content:read`
- Optional scope: `file_metadata:read`
- **NOT required:** `file_variables:read` (Variables API - not always available)

**Token generation:**

1. Visit <https://www.figma.com/settings>
2. Personal access tokens → Generate new token
3. Select: `file_content:read` + `file_metadata:read`
4. `export FIGMA_ACCESS_TOKEN=figd_your_token`

See [references/prerequisites.md](../references/prerequisites.md) for more details.

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

Components and pages check for `<theme-dir>/` existence and import available theme tokens. If theme tokens exist, they replace hardcoded values. If theme tokens don't exist or specific token missing, components hardcode with `// TODO: use theme token` comment.

**Token naming convention:** Use `/` separator for hierarchy (`color/primary`, `spacing/md`) to enable tree-shaking and autocomplete.

## Common Issues

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| **Screenshot text too small to read** | Entire canvas screenshotted instead of individual panels | Screenshot each token panel separately at scale=3 (see Step 3 panel-by-panel screenshot pattern) |
| **Token names unclear in screenshot** | Low resolution or poor contrast | Increase scale to 3 or 4, verify panel background is light/white |
| **Alias references unclear** | Value shows `{ref}` but can't read ref name | Zoom into alias column, cross-reference with primitive tokens panel |
| **Breaking changes to token values** | Designer updated colors/spacing in Figma | Show comparison report with diff, user reviews and approves changes before regenerating code |
| **Token name conflicts** | Multiple tokens map to same name | Ask user for resolution: keep primitive, rename semantic, or merge |
| **Too many similar values** | Design not using consistent scale | Filter by minimum usage threshold (used 10+ times) or present all with usage counts |
| **Spacing/sizing noise** | Random pixel values not on 4px grid | Only extract values divisible by 4, flag outliers for review |
| **Alias token chains incomplete** | Circular references or missing primitives | Recursively resolve: `semantic → alias → primitive → value`, detect cycles |
| **Multiple modes (light/dark/brand)** | Design system uses Figma modes for theming | Screenshot each mode separately (if panels show mode selector), extract all modes |

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
