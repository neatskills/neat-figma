---
name: neat-figma-component
description: Use when user provides Figma URL to generate UI components from Figma component library or design system
---

# Generate Components from Figma

**Role:** You are a UI engineer generating components from Figma design system, focusing on high-value components based on reusability, complexity, and product needs.

## Overview

Extract Figma components and generate code with proper types, styling, and variants. Manual refinement expected for interactions and logic.

**Principle:** Parse → Extract → Markdown → Diff → Approve → Code → Test

**Markdown-first:** Generate markdown documentation, check for changes, then optionally generate code.

Run `/neat-figma-foundation` first to establish theme tokens. Components auto-import theme values.

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | Figma URL (node-id optional) + screenshot (REQUIRED) |
| **Output** | `<component-dir>/ComponentName/` (shared) or `<screen-dir>/PageName/ComponentName/` (page) |
| **Prerequisites** | FIGMA_ACCESS_TOKEN, product path |
| **Screenshot** | Step 1 required; Step 5 for complex components |
| **Theme** | Auto-imports if exists |
| **Location** | Shared if from "Components"/"Design System", page-specific otherwise |

## Workflow

### Step 1: Parse Figma URL

Warn: "This will overwrite existing files. Commit changes first if needed. Continue? (yes/no)"

If no: stop.

Extract `fileKey` and optional `nodeId`. From `/neat-figma-page`: node-id provided. Direct: if missing, fetch library and prompt.

Verify FIGMA_ACCESS_TOKEN. If missing: "Set token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

#### Generate Component Screenshot

**Dual-source extraction:** API = precise values, screenshot = visual structure.

```bash
# Export component screenshot (scale=2 for standard detail)
SCREENSHOT_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${nodeId}&format=png&scale=2" \
  | jq -r '.images["'${nodeId}'"]')

# Download screenshot
curl -s "$SCREENSHOT_URL" -o /tmp/figma-component-${nodeId}.png
```

If fails: "Upload screenshot. REQUIRED - provides visual structure."

**Reveals:** Element types, patterns, states, labels, layout.

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md). Find `<component-dir>` and `<screen-dir>`.

If missing: "Create {suggested-path}? (yes/custom/skip)"

### Step 2.5: Check for Existing Markdown (Cross-Skill Awareness)

Extract component name from node/URL. Check if markdown exists and compare Figma version:

```bash
if [ -f "docs/design-system/components/${COMPONENT_NAME}.md" ]; then
  STORED_VERSION=$(grep "figmaVersion:" "docs/design-system/components/${COMPONENT_NAME}.md" | cut -d'"' -f2)
  CURRENT_VERSION=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
    "https://api.figma.com/v1/files/${fileKey}" | jq -r '.version')
  GIT_STATUS=$(git status --porcelain "docs/design-system/components/${COMPONENT_NAME}.md" 2>/dev/null)
fi
```

**If versions match AND no manual edits:**

```
Component markdown up-to-date (Figma version {version})

Options:
1. Use existing → skip to code generation (Step 17) [REQUIRES screenshot from Step 1 first]
2. Force re-extract (continue to Step 3)
3. Cancel

Choose (1/2/3):
```

**Note:** Option 1 still requires screenshot generation at Step 1 for validation (Step 17).

**If versions differ OR manual edits:**

```
Component markdown needs update:
- Stored version: {storedVersion}
- Current version: {currentVersion}
- Manual edits: {yes/no}

Options:
1. Use existing → skip to code generation (Step 17) [preserves edits, may be stale, REQUIRES screenshot from Step 1 first]
2. Extract from Figma → update (continue to Step 3) [Step 15 shows diff]
3. Cancel

Choose (1/2/3):
```

**Note:** Option 1 still requires screenshot generation at Step 1 for validation (Step 17).

### Step 3: Determine Extraction Location

Search `<component-dir>/` and `<screen-dir>/*/`. Match name (case-insensitive), ignore suffixes.

**Exists in `<component-dir>/`:** Reuse (skip)

**Exists in `<screen-dir>/PageA/` extracting for PageB:**

"⚠️ {ComponentName} in PageA/ — PageB needs it. Move to {component-dir}/? (yes/no)"

- yes: Move, verify, update imports, roll back on fail
- no: Duplicate, warn maintenance

**NOT exists, check Figma parent:**

- EXACTLY "Components"/"Design System"/"Library"/"Foundation" → `<component-dir>/`
- Ambiguous → Prompt
- Otherwise → `<screen-dir>/PageName/` or ask

### Step 4: Fetch Figma Components

Fetch from Figma REST API. Identify parent page.

### Step 5: Determine Complexity

**Primitive:** Single element, no INSTANCE, 1-2 layers

**Complex:** INSTANCE nodes, multiple elements

If complex:

```bash
# Export close-up screenshot for complex component (scale=2 for consistency)
CLOSEUP_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${componentNodeId}&format=png&scale=2" \
  | jq -r '.images["'${componentNodeId}'"]')

curl -s "$CLOSEUP_URL" -o /tmp/figma-component-closeup-${componentNodeId}.png
```

If fails, request upload.

### Step 6: Extract Component Structure

Find COMPONENT/COMPONENT_SET nodes. Extract fills, strokes, effects, cornerRadius, layoutMode, variants.

If INSTANCE: "Extract {NestedComponentName}? (yes/no/placeholder)"

### Step 7: Analyze Components

**Type:** Single → simple; Set → variants

**API:** Colors, spacing, typography, dimensions

**Screenshot:** Shapes, types, layout, text, states

**Combine:** API: `width: 120px, fill: #0066CC`. Screenshot: button, "Submit". Result: button with exact values, correct type.

**DON'T:** Guess from API alone, add invisible features

**DO:** API for precision, screenshot for structure

### Step 8: Resolve Styling

Check `<theme-dir>/`.

**Exists:** Match values to tokens (`#0066CC` → `colors.primary`), generate imports

**Missing:**

- Multiple: "Run `/neat-figma-foundation` first, or hardcode?"
- Single: Hardcode with `// TODO`

### Step 9: Generate Component Code

Generate in target location: framework conventions, typing, validated by screenshot, accessibility, Figma URL + date. Sets: variant props.

### Step 10: Generate Test File

Tests: renders, handlers, disabled, variants.

### Step 11: Generate Index File

Index/export per framework.

### Step 12: Update Main Export

Add to centralized exports if exist.

### Step 13: Fetch Figma Version

Get Figma version for tracking:

```bash
curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}" > /tmp/figma-file-meta.json

FIGMA_VERSION=$(jq -r '.version' /tmp/figma-file-meta.json)
FIGMA_LAST_MODIFIED=$(jq -r '.lastModified' /tmp/figma-file-meta.json)
FIGMA_NAME=$(jq -r '.name' /tmp/figma-file-meta.json)
```

### Step 14: Generate Markdown Documentation

Ask for markdown path:

```
Path for markdown documentation? (default: docs/design-system)
```

Generate `<path>/components/{ComponentName}.md`:

```markdown
---
type: component
source: https://figma.com/file/{fileKey}?node-id={nodeId}
figmaName: "{fileName}"
figmaVersion: "{version}"
figmaLastModified: "{lastModified}"
extracted: {YYYY-MM-DDTHH:mm:ssZ}
componentName: {ComponentName}
location: {code-path}
---

# {ComponentName} Component

## Overview

{Brief description from visual analysis}

## Variants

### size
- **sm**: Compact buttons for dense interfaces
- **md**: Standard size (default)
- **lg**: Prominent calls-to-action

### variant
- **primary**: Main actions, high emphasis
- **secondary**: Supporting actions, medium emphasis

### state
- **default**: Normal interactive state
- **hover**: Mouse hover
- **disabled**: Non-interactive

## Props

### label
- **type**: string
- **required**: true
- **description**: Button text content

### size
- **type**: 'sm' | 'md' | 'lg'
- **required**: false
- **default**: 'md'

## Styling

### size=sm
- **height**: 32px
- **padding**: 0 12px
- **fontSize**: 14px

### variant=primary
- **background**: color/primary
- **text**: color/white

## Usage Guidelines

- Use `primary` for main page actions
- Use `secondary` for supporting actions

## Dependencies

- Foundation: color/*, spacing/*
```

### Step 15: Check for Existing Markdown

If markdown exists at `<path>/components/{ComponentName}.md`:

```bash
# Show diff
git diff --no-index <existing-file> <new-file> || diff -u <existing-file> <new-file>
```

Present changes:

```
Changes detected in {ComponentName}:

Props:
  + loading: boolean (new)
  ~ size: 'sm'|'md'|'lg' → 'xs'|'sm'|'md'|'lg'|'xl' (changed)

Variants:
  + ghost variant (new)

Styling:
  ~ variant=primary background: #0066CC → #0052A3 (changed)

Review changes? (show/approve/cancel)
```

### Step 16: User Review & Edit

```
Markdown generated at {path}/components/{ComponentName}.md

Ready to generate code? (yes/no/later)
```

### Step 17: Generate Code from Markdown

Read markdown and generate component files:

**Parse markdown:**

- Extract props from Props section
- Extract variants from Variants section
- Extract styling from Styling section
- Extract dependencies

**Generate per framework:**

- Component file with TypeScript types
- Test file
- Index/export file

**Validate against screenshot** (same checklist as current Step 14)

If pass: "✅ {ComponentName} — Files: {list} — Location: {path} — ✓ Validated"

**Structure:**

```markdown
# {ComponentName}

*Extracted from Figma on {date}*
*Source: {figma-url}*
*Location: `{code-path}`*

## Overview

{Brief description based on visual analysis}

## Variants

| Variant | Options | Usage |
|---------|---------|-------|
| size | sm, md, lg | Adjust for hierarchy |
| variant | primary, secondary, ghost | Visual emphasis |
| state | default, hover, disabled | Interactive states |

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| label | string | required | Button text |
| icon | IconType | undefined | Optional leading icon |
| disabled | boolean | false | Disable interactions |

## Usage Guidelines

- Use `primary` for main actions
- Use `secondary` for supporting actions  
- Use `ghost` for tertiary actions

## Visual Reference

![{ComponentName}]({screenshot-path-or-figma-link})

## Implementation

See: `{code-path}`
```

**Multiple components:** Generate separate markdown file per component in `<path>/components/` directory.

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output Structure

**Code files (shared):**

```
product/<component-dir>/Button/
├── Button.*
├── Button.test.*
└── index.*
```

**Code files (page-specific):**

```
product/<screen-dir>/LoginPage/LoginForm/
├── LoginForm.*
├── LoginForm.test.*
└── index.*
```

**Markdown documentation (if requested):**

```
docs/design-system/components/     # Default path
├── Button.md                     # Per-component docs
├── Input.md
└── Card.md
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Screenshot generation fails | Fall back to manual request or proceed with API data only (with warning) |
| Complex without close-up | Request at Step 5 |
| Guessing/adding extras | Extract API, validate screenshot |
| Component exists in shared | Reuse (skip) |
| Component in another page | Prompt move, verify, roll back on fail |
| Location ambiguous | Check parent or prompt user |
| Nested instances missing | Extract depth-first or placeholder |
| No theme | Hardcode with comments or run foundation first |
| Animations/images | Static/placeholder |

## Regenerating Code from Existing Markdown

**When:** You have component markdown with manual edits and want to regenerate code without re-extracting from Figma.

**How:**

1. Run `/neat-figma-component` with component URL or name
2. At Step 2.5, choose Option 1: "Use existing markdown"
3. Skill skips to Step 17 (Generate Code from Markdown)
4. Reads `docs/design-system/components/{ComponentName}.md`
5. Generates component files in appropriate location

**What's skipped:**

- Figma API calls (no component extraction)
- Screenshot generation (not needed for code gen)
- Markdown generation (uses existing file)

**What's preserved:**

- All manual edits in markdown
- Custom prop descriptions
- Modified variants/styling
- Usage guidelines

**Use case:** Designer documented component behavior in markdown (added interaction notes, usage rules), engineer regenerates code to match spec.
