# Prerequisites

All Figma skills require:

1. **Figma Access Token**
   - Set as environment variable: `export FIGMA_ACCESS_TOKEN=figd_...`
   - Get token at: <https://www.figma.com/settings> (Personal Access Tokens)
   - If not found, prompt user: "Set your Figma token: `export FIGMA_ACCESS_TOKEN=figd_...`"

2. **Valid Figma URL**
   - Must include `node-id` query parameter for page/assets skills
   - Format: `https://figma.com/file/{fileKey}/{title}?node-id={nodeId}`
   - Example: `https://figma.com/file/abc123/Design?node-id=2055-3`

3. **Product Path** (user input)
   - Absolute path to target product directory
   - Example: `/path/to/my-app`
   - Product must contain framework configuration file
   - Supported: `package.json`, `pubspec.yaml`, `build.gradle`, `build.gradle.kts`, `Package.swift`, `*.csproj`, or HTML files
   - Used for framework detection, output path configuration, and product name extraction
   - See [references/product-detection.md](product-detection.md) for product name extraction logic
