---
name: neat-figma-page
description: Use when user provides Figma URL with node-id to generate page implementation from Figma designs - iterative page-by-page approach with user journey guidance
---

# Generate Page from Figma

**Role:** You are a UI engineer generating page implementations from Figma designs one page at a time, using user journey understanding to guide sequence and component extraction.

## Overview

**Principle:** Understand Journey → Pick Page → Extract → Markdown → Diff → Approve → Code → Repeat

**Markdown-first:** Generate page documentation, check for changes, then optionally generate code.

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

Warn: "This will overwrite existing files. Figma is the source of truth. Commit changes first if needed. Continue? (yes/no)"

If no: stop.

Extract `fileKey` and `nodeId` (required). Verify FIGMA_ACCESS_TOKEN. If missing: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md). Find `<screen-dir>`. If missing: "Screen directory not found. Create {suggested-path}? (yes/custom)"

### Step 2.5: Check for Existing Markdown (Cross-Skill Awareness)

Determine page name. Check if `docs/design-system/pages/${PAGE_NAME}.md` exists. Compare versions:

```bash
STORED_VERSION=$(grep "figmaVersion:" <markdown> | cut -d'"' -f2 || echo "unknown")
CURRENT_VERSION=$(curl -s -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" \
  "https://api.figma.com/v1/files/${fileKey}" | jq -r '.version // "unknown"')
GIT_STATUS=$(git status --porcelain <markdown> 2>/dev/null || echo "")
```

**If API fails:** Prompt "Continue with re-extraction (skips version check)?" If no: exit with "Fix API access or use existing markdown."

| Condition | Options |
|-----------|---------|
| **Versions match, no edits** | 1. Use existing → Step 7.8 (markdown-only) 2. Force re-extract → Step 3 3. Cancel |
| **Versions differ OR edits** | 1. Use existing → Step 7.8 (preserves edits) 2. Extract → Step 3 (shows diff at Step 7.6) 3. Cancel |

**Option 1:** Markdown-only validation (no screenshot). **Option 2:** Full re-extraction with diff review.

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
# Export page screenshot (scale=2 for standard detail)
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
5. **If NOT found:** Construct URL with format `https://figma.com/file/{fileKey}?node-id={componentNodeId}`, invoke `/neat-figma-component`

Component extraction requests own screenshot (intentional). Extract only THIS page needs.

#### 7.4 Document Required Assets

If images/icons detected in page:

1. Identify the containing FRAME/PAGE node that holds all page assets
2. For each asset: Extract individual nodeId, classification, and visual properties from API
3. Generate screenshot for each asset to document visual appearance
4. Determine expected paths (assets/images/, assets/icons/)
5. Document in page markdown with both container nodeId and individual asset nodeIds

**Do NOT extract assets yet** - page markdown documents what's needed, extraction happens separately.

**NodeId roles:**

| Type | Used For | Usage |
|------|----------|-------|
| Container | `/neat-figma-assets` invocation | Passed to assets skill for extraction |
| Individual | Documentation/validation | NOT used by assets skill (does visual detection) |

**Markdown format:**

```markdown
## Assets
**Container nodeId**: 100:200

### hero-background
- **nodeId**: 123:456, **type**: illustration, **expectedPath**: assets/images/hero-background.svg
- **size**: 400px × 300px, **usage**: Page header, **status**: pending_extraction
```

**Rationale:** Decouples page completion from asset extraction (allows review, batch extraction).

#### 7.5 Generate Markdown Documentation

Ask for markdown path:

```
Path for markdown documentation? (default: docs/design-system)
```

Generate `<path>/pages/{PageName}.md`:

```markdown
---
type: page
source: https://figma.com/file/{fileKey}?node-id={nodeId}
figmaName: "{fileName}"
figmaVersion: "{version}"
figmaLastModified: "{lastModified}"
extracted: {YYYY-MM-DDTHH:mm:ssZ}
pageName: {PageName}
location: {screen-dir}/{PageName}
---

# {PageName}

## Layout

### Container
- **maxWidth**: 400px
- **padding**: 32px
- **centered**: true

### Sections
1. Logo
2. Heading
3. Form
4. Footer

## Components

### {ComponentName} (page-specific/shared)
**Location**: `{path}`

#### Fields/Props
- **fieldName**
  - type: input type
  - label: "Label"
  - required: true

#### Actions
- **buttonName**
  - label: "Text"
  - variant: primary

## Content

### Heading
- **text**: "Page Title"
- **style**: heading/h1

### Footer
- **text**: "Footer text"
- **link**: "Link text"
- **linkTo**: /path

## Behavior

### Form Validation
- Validate on submit
- Show inline errors

### Submit Flow
1. Disable button
2. API call
3. Redirect or error

## Assets

### Logo
- **path**: /assets/logo.svg
- **size**: 48px × 48px

## Dependencies

- Foundation: color/*, typography/*
- Components: Button, Input
```

#### 7.6 Check for Existing Markdown

If markdown exists at `<path>/pages/{PageName}.md`:

Show diff and present changes:

```
Changes detected in {PageName}:

Layout:
  ~ Container maxWidth: 400px → 480px (changed)

Components:
  + RememberMe checkbox (new)
  ~ Submit button label: "Login" → "Sign in" (changed)

Content:
  ~ Heading text: "Welcome" → "Welcome back" (changed)
  + Forgot password link (new)

Review changes? (show/approve/cancel)
```

#### 7.7 User Review & Edit

```
Markdown generated at {path}/pages/{PageName}.md

{N} assets documented (status: pending_extraction)

Ready to generate code? (yes/no/later)
```

**yes:** Proceed to 7.8
**no/later:** Skip to 7.11 (asset extraction prompt)

#### 7.8 Generate Implementation from Markdown

Read markdown and generate page files:

Extract page name, check `<theme-dir>/`, generate imports, structure, validated values from markdown.

**DON'T add:** Features not in markdown/screenshot.

#### 7.9 Generate Test & Validate

Generate test file. Validate against screenshot (same checklist).

If pass: "✅ {PageName} — Files: {list} — Components: {list} — Assets: {N} documented — ✓ Validated"

#### 7.10 Extract Assets (If Documented)

If page markdown has documented assets (status: pending_extraction):

```
{N} assets documented but not extracted:
- {asset1}: {type}, {expectedPath}, nodeId: {nodeId}
- {asset2}: {type}, {expectedPath}, nodeId: {nodeId}

Extract assets now? (yes/later/batch)
```

**yes:** Construct Figma URL with container node-id and invoke `/neat-figma-assets`:

```
https://figma.com/file/{fileKey}?node-id={containerNodeId}
```

Pass this URL to `/neat-figma-assets` using the **container nodeId** from page markdown (not individual asset nodeIds). Assets skill expects URL with node-id parameter pointing to PAGE or FRAME containing all assets.

**later:** User extracts manually when ready
**batch:** User will extract all page assets together later

#### 7.11 Recommend Next

"Next: {NextPage} — {reason}. Alternative: {Alt} — {reason}. Which next, or 'done'?"

If another: return to 7.1. If done: complete.

## Regenerating Code from Existing Markdown

If user has markdown but needs to regenerate code:

1. Read existing markdown from `docs/design-system/pages/{PageName}.md`
2. Parse structure, components, content, behavior, assets
3. Generate code files following markdown specification
4. Validate against screenshot if available
5. Skip Figma API calls (markdown is source of truth)

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
