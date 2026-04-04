---
name: neat-figma-foundation
description: Use when user provides Figma URL(s) to extract design foundation (colors, typography, spacing, sizing, shadows) - supports multiple URLs for multi-page foundations
---

# Extract Design Foundation from Figma

**Role:** You are a UI engineer extracting design foundation primitives from Figma into the theme system.

## Overview

Extract design foundation (colors, typography, spacing, sizing, shadows) from Figma and generate theme files. Supports **multiple URLs** for multi-page libraries. Auto-detect setup, compare existing tokens, recommend changes, get approval, write.

**Principle:** Detect → Extract → Merge → Compare → Recommend → Approve → Write

## When to Use

- User provides Figma URL(s) with foundation/design system/design tokens
- User requests to import/update design foundation (colors, typography, spacing, shadows, sizing)
- Theme files need updates from Figma designs
- Foundation library spans multiple Figma pages

## Input

Accepts one or more Figma URLs for multi-page foundation libraries.

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

### Step 1: Parse All Figma URLs

Warn about overwrites:

```
This will overwrite existing assets.
Figma is the source of truth - existing files will be replaced.
Commit your changes first if needed.

Continue? (yes/no)
```

If no: stop and exit.
If yes: proceed.

Extract `fileKey` and optional `nodeId` for each URL.

Verify FIGMA_ACCESS_TOKEN exists. If missing, halt and prompt: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_xxxxx`"

### Step 2: Auto-Detect Product Setup

See [references/product-detection.md](../references/product-detection.md) for framework detection.

Find theme directory following framework conventions (e.g., `src/theme` for React, `lib/constants` for Flutter, `Resources` for iOS).

### Step 3: Extract Design Foundation from Figma

For each URL, fetch node data from Figma.

Extract tokens:

- **Colors**: SOLID fills and strokes (visible)
- **Typography**: TEXT nodes (fontSize, fontWeight, lineHeight, fontFamily, letterSpacing)
- **Spacing**: auto-layout padding and itemSpacing
- **Sizing**: dimensions divisible by 4
- **Shadows**: DROP_SHADOW and INNER_SHADOW

Track usage and source nodes per token. If multiple URLs, merge and deduplicate.

### Step 4: Generate Theme Files

Generate theme files with usage comments in the appropriate format for the detected framework and language.

### Step 5: Check for Existing Components

After generating theme files, check if components already exist with hardcoded design values:

1. Search `<component-dir>/` and `<screen-dir>/*/` for component files
2. Grep for hardcoded color values (hex codes, rgb/rgba)
3. If found, present report:

```
Found {N} components with hardcoded values:
- {ComponentName}: {count} hardcoded colors, {count} hardcoded spacing

Refactor to use theme tokens? (yes/no/manual)
```

- **yes**: For each component, replace hardcoded values with theme token imports
- **no**: Skip refactoring, document in report
- **manual**: List components and values, user refactors

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
| Token name generation unclear | Inspect node names in Figma for context, ask user for preferred names |
| Breaking changes to token values | Show comparison report, user approves changes |
| Token name conflicts | Ask user for resolution |
| Too many similar values | Filter by minimum usage threshold (e.g., used 10+ times) |
| Spacing/sizing noise | Only extract values divisible by 4 (design system convention) |
