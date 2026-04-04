# Neat Figma

Claude Code custom skills for extracting design systems from Figma and generating production code.

## Overview

This repository contains four self-contained Figma extraction skills:

1. **neat-figma-foundation** - Extract design foundation (colors, typography, spacing, sizing, shadows) - supports multiple URLs
2. **neat-figma-component** - Generate components from Figma (component library or page-specific components)
3. **neat-figma-page** - Generate screen/page implementations from Figma designs
4. **neat-figma-assets** - Extract images, logos, icons, and illustrations

Each skill is **fully self-contained** - just provide a Figma URL and it handles the rest:

- Auto-detects project setup (framework, language, paths)
- Extracts from Figma via API
- Generates code matching your project
- No config files needed

## Quick Start

Set your Figma access token: `export FIGMA_ACCESS_TOKEN=figd_...` ([Get token](https://www.figma.com/settings))

Each skill takes a Figma URL:

```bash
# Extract design foundation
/neat-figma-foundation https://figma.com/file/abc123/Foundation?node-id=1-2

# Or extract from multiple pages
/neat-figma-foundation \
  https://figma.com/file/abc123/Foundation?node-id=1-2 \
  https://figma.com/file/abc123/Foundation?node-id=3-4 \
  https://figma.com/file/abc123/Foundation?node-id=5-6

# Generate components
/neat-figma-component https://figma.com/file/abc123/Components?node-id=2055-3

# Generate screens/pages
/neat-figma-page https://figma.com/file/abc123/Screens?node-id=6058-3

# Extract assets
/neat-figma-assets https://figma.com/file/abc123/Screens?node-id=6058-3
```

## Skills

### 1. neat-figma-foundation

Extract design foundation from Figma and generate theme files. Supports multiple URLs for multi-page foundation libraries.

**Input:** One or more Figma URLs with design foundation pages

**Output:**

```
<theme-dir>/
├── colors.*
├── typography.*
├── spacing.*
├── sizing.*
└── shadows.*
```

**Features:**

- Multiple URL support for multi-page foundation libraries
- Hybrid extraction (Figma Styles API + file structure)
- Automatic merging and deduplication across pages
- Semantic names from designers ("Brand/Primary" → `colors.primary`)
- Usage frequency tracking
- Unstylified token detection
- Framework-aware code generation

[📖 Full Documentation](./neat-figma-foundation/SKILL.md)

---

### 2. neat-figma-component

Generate components from Figma. Works with shared component libraries or page-specific components.

**Input:** Figma URL pointing to component, component set, or component frame

**Output:**

```
<components-dir>/Button/
├── Button.*
├── Button.test.*
└── index.*
```

**Features:**

- Variant detection (Type, Size, State)
- Type/interface generation (when applicable)
- Auto-styled with theme tokens or hardcoded values
- Test file generation
- Framework-specific output

[📖 Full Documentation](./neat-figma-component/SKILL.md)

---

### 3. neat-figma-page

Generate screen/page implementation from Figma design.

**Input:** Figma URL pointing to screen/page design

**Output:**

```
<screens-dir>/LoginScreen/
├── LoginScreen.*
├── LoginScreen.test.*
└── index.*
```

**Features:**

- Layout extraction from Figma hierarchy
- Placeholder structure generation
- TODO comments for manual refinement
- Component instance detection
- Framework-specific scaffolding

**Note:** Generates starter code - manual refinement expected for state, navigation, and business logic.

[📖 Full Documentation](./neat-figma-page/SKILL.md)

---

### 4. neat-figma-assets

Extract images, logos, icons, and illustrations from Figma.

**Input:** Figma URL containing visual assets

**Output:**

```
<assets-dir>/
├── images/
│   ├── logo.svg
│   ├── hero@2x.png
│   └── hero@3x.png
├── icons/
│   ├── search.svg
│   └── close.svg
└── index.*
```

**Features:**

- Auto-classification (logo, icon, illustration, photo)
- Format detection (SVG for logos/icons, PNG for photos)
- Multi-resolution PNG export (when needed for mobile frameworks)
- Asset index generation
- Filename collision handling

[📖 Full Documentation](./neat-figma-assets/SKILL.md)

---

## Import Order

For new projects, follow this order:

1. **Foundation** → Theme tokens (colors, typography, spacing, sizing, shadows)
2. **Assets** → Visual resources (icons, images, logos)
3. **Components** → Reusable UI (buttons, inputs, cards)
4. **Pages** → Screen implementations

Re-run skills after design changes to update your code. Each skill warns you upfront and asks for confirmation before overwriting files.

## Notes

- All skills auto-detect framework, language, and output paths
- Generated code is **starter code** - manual refinement expected for state, navigation, interactions, business logic
- See individual SKILL.md files for detailed workflows and troubleshooting

## License

MIT
