---
name: neat-figma-page
description: Use when user provides Figma URL with node-id to generate page implementation from Figma designs - iterative page-by-page approach with user journey guidance
---

# Generate Page from Figma

**Role:** You are a UI engineer generating page implementations from Figma designs one page at a time, using user journey understanding to guide sequence and component extraction.

## Overview

**Principle:** Understand Journey → Pick Page → Extract for Page → Generate → Repeat

User provides Figma URL with `node-id` to scaffold pages from designs iteratively.

**Don't use for:** Component library (`/neat-figma-component`) or design foundation (`/neat-figma-foundation`)

## Core Principles

- **Iterative:** One page at a time, user chooses sequence
- **Design Fidelity:** Implement only what's visible in Figma
- **User Journey First:** Understand flow, recommend next steps
- **Extract per Page:** Components/assets as needed, not upfront

## Quick Reference

| Item | Value |
|------|-------|
| **Input** | Figma URL (node-id required) + journey + screenshot per page |
| **Output** | `<screen-dir>/PageName/` (one at a time), components, assets |
| **Prerequisites** | FIGMA_ACCESS_TOKEN, product path |
| **Screenshot** | One per page at Step 7.1 (REQUIRED) |
| **Approach** | Page-by-page, user chooses sequence |
| **Extraction** | Per-page components/assets |
| **Manual refinement** | State, navigation, logic (not visuals) |

## Workflow

### Step 1: Parse URL and Verify Token

Warn: "This will overwrite existing assets. Figma is the source of truth. Commit changes first if needed. Continue? (yes/no)"

If no: stop.

Extract `fileKey` and `nodeId` (required). Verify FIGMA_ACCESS_TOKEN. If missing: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md). Find `<screen-dir>`. If missing: "Screen directory not found. Create {suggested-path}? (yes/custom)"

### Step 3: Fetch Figma Structure

Fetch page data. List top-level frames/pages with count and types.

### Step 4: Extract User Journey from Figma

Fetch file data (`GET /v1/files/:fileKey`). Analyze:

1. **Prototype:** `prototypeStartNodeID`, `interactions`, navigation graph
2. **Frame naming:** Sequence ("1. Login"), flow grouping ("Auth/Login"), state suffixes ("Dashboard-Default")
3. **Spatial layout:** Left-to-right, top-to-bottom, grouped positioning
4. **Parent-child:** Same parent = related screens
5. **Text annotations:** Flow descriptions, "Notes"/"Flow"/"Journey" labels, arrows (→, ⇒)
6. **Visual indicators:** Arrows, connecting lines, flow diagrams

**Present:**

- Entry: {FrameName} (prototype start / leftmost / "1.")
- Main: {FrameA} → {FrameB} → {FrameC} [connections/naming/layout]
- Alternative: {FrameB} → {FrameD} (error/modal) [naming/annotation]
- Isolated: {FrameX}, {FrameY} (error states/overlays/alternatives)

Validate: Confirm main flow, clarify isolated, verify edge cases. If no signals: Ask flow, entry/exit, edge cases.

### Step 5: Recommend Starting Page

"Found {N} pages: {list}. Recommend: {Page} — Reason: {why}. Which first?"

### Step 6: User Picks Page

Record choice.

### Step 7: Page Implementation Loop

For each page:

#### 7.1 Generate Page Screenshot

**Dual-source:** API (precise values: `#0066CC`, `32px`) + screenshot (visual structure: button vs link, grid vs list).

```bash
# Export page screenshot
SCREENSHOT_URL=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/images/${fileKey}?ids=${pageNodeId}&format=png&scale=2" \
  | jq -r '.images["'${pageNodeId}'"]')

# Download screenshot
curl -s "$SCREENSHOT_URL" -o /tmp/figma-page-${pageNodeId}.png
```

API shows FRAME/TEXT/RECTANGLE, not button/input/card/modal. Screenshot reveals UI element types.

If API fails: "Upload screenshot showing {PageName}. Screenshot REQUIRED."

#### 7.2 Analyze Page

Traverse tree: sections (FRAME/GROUP depth < 2), instances (INSTANCE), images (IMAGE/VECTOR), text (TEXT). List components/assets.

**Combine sources:** API `FRAME > RECTANGLE(fill: #0066CC) + TEXT("Submit")` + Screenshot → button component (not frame with shapes).

Use API for precise values (colors hex/RGB, spacing px, typography, dimensions, effects), screenshot for element types (layout patterns, visible content, component states). Don't guess from API or add features not in screenshot.

#### 7.3 Extract Components

For each unique component:

1. Get nodeId from API
2. Check exists in `<component-dir>/` or `<screen-dir>/*/` (case-insensitive, ignore suffixes)
3. **If in `<component-dir>/`:** Reuse (skip)
4. **If in `<screen-dir>/OtherPage/`:** Prompt: "⚠️ {ComponentName} in OtherPage/ — {CurrentPage} needs it (2+ pages). Move to {component-dir}/? (yes/no)"
   - yes: Move, verify, update imports, roll back on failure
   - no: Duplicate
5. **If NOT found:** Construct URL, invoke `/neat-figma-component`

Component extraction requests own screenshot (intentional). Extract only THIS page needs.

#### 7.4 Extract Assets

If images/icons: Extract nodeId, construct URL, invoke `/neat-figma-assets`.

#### 7.5 Generate Implementation

Extract page name (remove suffixes, PascalCase). Check `<theme-dir>/`: if exists import tokens, if missing hardcode with TODOs.

**Generate:** imports (theme tokens, components, assets), header (URL, date, TODOs), structure, text, validated values (API colors/spacing/typography/dimensions/layout, screenshot structure).

**DON'T add:** validation, loading, dialogs, features, framework defaults, labels not shown, guessed values.

#### 7.6 Generate Test

Basic render test + TODOs. Generate index/export.

#### 7.7 Validate Generated Page Against Screenshot

Compare generated page against screenshot.

```bash
# Display screenshot for verification
open /tmp/figma-page-${pageNodeId}.png
```

**Verification checklist:**

1. ✅ Layout structure: Sections, components, element arrangement
2. ✅ Visual properties: Colors, spacing, typography, dimensions
3. ✅ Element types: Buttons, inputs, cards, lists
4. ✅ Content: All visible text, labels, placeholders
5. ✅ Components: All components as designed
6. ✅ No missing elements: Every visible element implemented
7. ✅ No extras: Only what's visible, no assumptions or framework defaults

If fails: revise. If pass: proceed to 7.8.

#### 7.8 Show Results

"✅ {PageName} — Files: {list} — Components: {list with status} — Assets: {list} — ✓ Validated"

#### 7.9 Recommend Next

"Next: {NextPage} — {reason}. Alternative: {Alt} — {reason}. Which next, or 'done'?"

If another: return to 7.1. If done: complete.

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output Structure

```
product/<screen-dir>/
├── Page1Name/
│   ├── Page1Name.*
│   ├── Page1Name.test.*
│   └── index.*
├── Page2Name/
└── ...
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Screenshot generation fails | Fall back to manual request at 7.1 - REQUIRED per page |
| Reusing previous screenshot | Each page needs own screenshot at 7.1 (auto-generated with unique node-id) |
| No dual-source validation | Always validate API + screenshot at 7.7 |
| Guessing from screenshot | Extract precise values from API |
| Adding extras | If screenshot doesn't show it, don't generate |
| Component exists in shared | Reuse, don't re-extract |
| Component in another page | Prompt move with error handling |
| Screen directory missing | Prompt create |
| Move fails | Roll back, don't leave broken |
| Complex nesting/animations | Simplified placeholder + TODO |
| Extraction fails | Document, generate placeholder/TODO |
