---
name: neat-figma-component
description: Use when user provides Figma URL to generate UI components from Figma component library or design system
---

# Generate Components from Figma

**Role:** You are a UI engineer generating components from Figma design system, focusing on high-value components based on reusability, complexity, and product needs.

## Overview

Extract Figma components and generate code with proper types, styling, and variants. Generates starter components—manual refinement expected for interactions and logic.

**Principle:** Parse → Detect → Extract → Generate → Test

## When to Use

- User provides Figma URL to components/design system
- Generate/scaffold UI components from Figma
- Create components matching Figma designs

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

Warn: "This will overwrite existing assets. Figma is the source of truth. Commit changes first if needed. Continue? (yes/no)"

If no: stop and exit.

Extract `fileKey` and optional `nodeId`. From `/neat-figma-page`: node-id always provided. Direct invocation: if nodeId missing, fetch library and prompt for selection.

Verify FIGMA_ACCESS_TOKEN. If missing, halt: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

#### Request Screenshot

Figma API provides precise values. Screenshot validates interpretation.

Request: "Upload screenshot showing component(s). Validates layout, structure, patterns. May request close-ups for complex components. Screenshot REQUIRED."

**Note:** Even from `/neat-figma-page`, component screenshots ensure variant coverage and detail validation.

Wait for screenshot.

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md). Find component directory (`src/components`, `lib/widgets`, `Views`) and screen directory (`src/screens`, `src/pages`, `lib/screens`).

If screen directory missing: "Screen directory not found. Create {suggested-path}? (yes/custom/skip)"

### Step 3: Determine Extraction Location

Search `<component-dir>/` and `<screen-dir>/*/`. Match name (case-insensitive), ignore suffixes: "Component", "Widget", "View", "Screen".

**If exists in `<component-dir>/`:** Reuse (skip)

**If exists in `<screen-dir>/PageA/` and extracting for PageB:**

Prompt: "⚠️ {ComponentName} in PageA/ — PageB needs it (2+ pages). Move to {component-dir}/? (yes/no)"

- yes: Move, verify, update imports, roll back on failure
- no: Duplicate in PageB/, warn maintenance

**If NOT exists:**

Check Figma parent:

- EXACTLY "Components"/"Design System"/"Library"/"Foundation" → `<component-dir>/`
- Ambiguous (e.g., "Components Screen") → Prompt user for shared vs page
- Otherwise → `<screen-dir>/PageName/` or ask user

### Step 4: Fetch Figma Components

Fetch from API. Identify parent page.

### Step 5: Determine Complexity

**Primitive** (Step 1 sufficient): Single element, no INSTANCE nodes, 1-2 layers

**Complex** (needs close-up): INSTANCE nodes, multiple elements, complex layout

If complex and Step 1 insufficient: "Upload close-up of {ComponentName}. Validates layout, visible elements, spacing, states."

### Step 6: Extract Component Structure

Find COMPONENT/COMPONENT_SET nodes. Extract fills, strokes, effects, cornerRadius, layoutMode, variant properties.

If INSTANCE nodes: Check if nested components exist. If not: "Extract {NestedComponentName}? (yes/no/placeholder)" — extract depth-first, skip, or use placeholder.

### Step 7: Analyze Components

**Type:** Single → simple export; Set → variants with union props

**Extract from API:** Layout, spacing, colors (hex/RGB), typography, dimensions, effects, variants

**Validate with screenshot:** Shape (rectangular vs circular), element presence, proportions, pattern type

**DON'T:** Guess from screenshot, interpret without screenshot, add "improvements"

**DO:** API for precision, screenshot for validation

### Step 8: Resolve Styling

Check theme directories. Match to tokens or hardcode with comments. If no theme + multiple components: "Run `/neat-figma-foundation` first, or proceed with hardcoded?"

### Step 9: Generate Component Code

Generate in target location (Step 3): framework conventions, proper typing, Figma values validated by screenshot, accessibility, Figma URL + date in header.

For sets: variant props with types, separate styles.

### Step 10: Generate Test File

Generate tests: renders, handlers, disabled, variants.

### Step 11: Generate Index File

Generate index/export per framework.

### Step 12: Update Main Export

If centralized exports exist, add component.

### Step 13: Validate

Checklist: Colors/spacing/typography/dimensions from API. Layout/shape/labels/proportions match screenshot. No framework overrides or extras.

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
| No screenshot | STOP - REQUIRED |
| Complex without close-up | Request at Step 5 |
| Guessing/adding extras | Extract API, validate screenshot |
| Component exists in shared | Reuse (skip) |
| Component in another page | Prompt move, verify, roll back on fail |
| Location ambiguous | Check parent or prompt user |
| Nested instances missing | Extract depth-first or placeholder |
| No theme | Hardcode with comments or run foundation first |
| Animations/images | Static/placeholder |
