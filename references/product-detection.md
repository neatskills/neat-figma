# Product Detection

## Product Path and Name

**Product path** is provided by the user (e.g., `/path/to/my-awesome-ecommerce-platform`).

**Product name** (`<product>`) is extracted from the folder basename:

1. Take basename of product path (e.g., `my-awesome-ecommerce-platform`)
2. If basename > 20 characters, shorten meaningfully:
   - Remove common suffixes: `-app`, `-platform`, `-frontend`, `-backend`, `-mobile`, `-web`
   - Extract key term (e.g., `ecommerce` from `my-awesome-ecommerce-platform`)
   - If unclear, ask user: "I'll use `<shortened>` for the product name. OK?"
3. Use lowercase, alphanumeric + hyphens only

Examples:

- `/path/to/acme-store` → `acme-store`
- `/path/to/my-awesome-ecommerce-platform` → `ecommerce`
- `/path/to/mobile-banking-app` → `mobile-banking`
- `/path/to/app` → ask user for meaningful name

## Framework Detection

Auto-detect product setup by checking for framework configuration files in order:

1. `package.json` (JavaScript ecosystem - React, Vue, Svelte, React Native, etc.)
2. `pubspec.yaml` (Flutter/Dart)
3. `build.gradle` / `build.gradle.kts` (Android/Kotlin)
4. `Package.swift` (iOS/Swift)
5. `*.csproj` (C#/.NET MAUI, Xamarin, Blazor)
6. HTML files (vanilla web)

Extract framework and language from detected file.
