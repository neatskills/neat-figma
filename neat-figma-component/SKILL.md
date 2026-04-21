---
name: neat-figma-component
description: Use when user provides Figma URL to generate UI components from Figma component library or design system
---

# Generate Components from Figma

**Role:** You are a UI engineer generating components from Figma design system, focusing on high-value components based on reusability, complexity, and product needs.

## Overview

Extract Figma components and generate code with proper types, styling, and variants. Manual refinement expected for interactions and logic.

**Principle:** Parse → Detect → Extract → Generate → Test

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

Warn: "This will overwrite existing assets. Commit changes first if needed. Continue? (yes/no)"

If no: stop.

Extract `fileKey` and optional `nodeId`. From `/neat-figma-page`: node-id provided. Direct: if missing, fetch library and prompt.

Verify FIGMA_ACCESS_TOKEN. If missing: "Set token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

#### Generate Component Screenshot

**Dual-source extraction:** API = precise values, screenshot = visual structure.

```bash
# Export component screenshot
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
# Export close-up screenshot for complex component (3x scale for detail)
CLOSEUP_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${componentNodeId}&format=png&scale=3" \
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

### Step 13: Validate Against Screenshot

Compare code to screenshot.

```bash
# Display screenshot for verification
open /tmp/figma-component-${nodeId}.png
```

**Verification checklist:**

1. ✅ Element type correct (button vs link)
2. ✅ Visual properties accurate (colors, spacing, typography)
3. ✅ Layout matches (arrangement, alignment)
4. ✅ Content accurate (labels, icons, states)
5. ✅ No extra features (only visible)
6. ✅ States/variants covered

If fails: revise. If pass: "✅ {ComponentName} — Files: {list} — Location: {path} — ✓ Validated"

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output Structure

**Shared:**

```
product/<component-dir>/Button/
├── Button.*
├── Button.test.*
└── index.*
```

**Page-specific:**

```
product/<screen-dir>/LoginPage/LoginForm/
├── LoginForm.*
├── LoginForm.test.*
└── index.*
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
