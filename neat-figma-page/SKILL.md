---
name: neat-figma-page
description: Use when user provides Figma URL with node-id to generate page implementation from Figma designs - iterative page-by-page approach with user journey guidance
---

# Generate Page from Figma

**Role:** You are a UI engineer generating page implementations from Figma designs one page at a time, using user journey understanding to guide sequence and component extraction.

## Overview

Generate pages iteratively guided by user journey.

**Principle:** Understand Journey → Pick Page → Extract for Page → Generate → Repeat

## When to Use

User provides Figma URL with `node-id` to scaffold pages from designs iteratively.

**Don't use for:** Component library (`/neat-figma-component`) or design foundation (`/neat-figma-foundation`)

## Core Principles

**Iterative:** One page at a time, user chooses sequence.

**Design Fidelity:** Implement only what's visible in Figma. No assumptions.

**User Journey First:** Understand flow, use it to recommend next steps.

**Extract per Page:** Components/assets as needed, not upfront.

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

If no: stop and exit.

Extract `fileKey` and `nodeId` (required).

Verify FIGMA_ACCESS_TOKEN. If missing: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md). Find screen directory. If missing: "Screen directory not found. Create {suggested-path}? (yes/custom)"

### Step 3: Fetch Figma Structure

Fetch page data. List top-level frames/pages with count and types.

### Step 4: Understand User Journey

Ask about: main flow, edge cases, animations/interactions, page relationships.

Compare with Figma structure. Show findings (frames, patterns, components). Identify gaps. Ask clarifying questions. Capture understanding for recommendations.

### Step 5: Recommend Starting Page

Present page list. Recommend starting page with reasoning: "Found {N} pages: {list}. Recommend: {Page} — Reason: {why}. Which first?"

### Step 6: User Picks Page

Record choice.

### Step 7: Page Implementation Loop

For each page:

#### 7.1 Request Page Screenshot

Request: "Upload screenshot of {PageName}. I'll extract precise values from Figma API (colors, spacing, sizes). Screenshot validates interpretation (rectangular vs circular, labels present, custom vs default). Screenshot REQUIRED."

Wait for screenshot.

#### 7.2 Analyze Page

Traverse tree: sections (FRAME/GROUP depth < 2), instances (INSTANCE), images (IMAGE/VECTOR), text (TEXT). List components and assets needed.

**Extract from API:** Layout, spacing, colors (hex/RGB), typography, dimensions, effects

**Validate with screenshot:** Shape, element presence, pattern type, layout structure

**DON'T:** Guess from screenshot, interpret without validation, add extras

**DO:** API for precision, screenshot for validation

#### 7.3 Extract Components

For each unique component instance:

1. Get nodeId from API
2. Check if exists in `<component-dir>/` or `<screen-dir>/*/` (case-insensitive, ignore suffixes)
3. **If in `<component-dir>/`:** Reuse (skip)
4. **If in `<screen-dir>/OtherPage/`:** Prompt: "⚠️ {ComponentName} in OtherPage/ — {CurrentPage} needs it (2+ pages). Move to {component-dir}/? (yes/no)"
   - yes: Move, verify, update imports, roll back on failure
   - no: Duplicate
5. **If NOT found:** Construct URL, invoke `/neat-figma-component`

**Note:** Component extraction requests its own screenshot for precision (intentional).

Extract only what THIS page needs.

#### 7.4 Extract Assets

If images/icons: Extract page nodeId, construct URL, invoke `/neat-figma-assets`.

#### 7.5 Generate Implementation

Extract page name (remove suffixes, convert to PascalCase).

**From API:** Colors, spacing, typography, dimensions, layout

**From screenshot:** Structure validation (shape, presence, pattern)

Generate: imports, asset references, header (URL, date, TODOs), structure, text, validated values.

**DON'T add:** validation, loading, dialogs, features, framework defaults not in screenshot, labels not shown, guessed values.

#### 7.6 Generate Test

Basic render test + TODO comments. Generate index/export.

#### 7.7 Validate

Checklist: Colors/spacing/typography/dimensions from API. Layout/shape/text/proportions match screenshot. No framework overrides or extras.

If fails: revise.

#### 7.8 Show Results

"✅ {PageName} — Files: {list} — Components: {list with status} — Assets: {list} — ✓ Validated"

#### 7.9 Recommend Next

Suggest next page with reason. Offer alternative: "Next: {NextPage} — {reason}. Alternative: {Alt} — {reason}. Which next, or 'done'?"

If another: return to 7.1. If done: complete.

## Prerequisites

See [references/prerequisites.md](../references/prerequisites.md)

## Output Structure

Per page (incremental):

```
product/<screen-dir>/
├── Page1Name/
│   ├── Page1Name.*
│   ├── Page1Name.test.*
│   └── index.*
├── Page2Name/
└── ...
```

## Common Mistakes

| Issue | Solution |
|-------|----------|
| No screenshot | STOP at 7.1 - REQUIRED per page |
| Reusing previous screenshot | Each page needs own screenshot at 7.1 |
| No dual-source validation | Always validate API + screenshot at 7.7 |
| Guessing from screenshot | Extract precise values from API |
| Adding extras | If screenshot doesn't show it, don't generate |
| Component exists in shared | Reuse, don't re-extract |
| Component in another page | Prompt move with error handling |
| Screen directory missing | Prompt create |
| Move fails | Roll back, don't leave broken |
| Complex nesting/animations | Simplified placeholder + TODO |
| Extraction fails | Document, generate placeholder/TODO |
