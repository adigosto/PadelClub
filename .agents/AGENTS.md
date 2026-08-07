# PadelClub Agent Guide

This file defines the UI and implementation style for the PadelClub Flutter app. Any AI agent editing this app should follow these rules first.

## Reference Fidelity

- When a user provides a Figma frame, screenshot, or any visual mockup, treat it as the primary source of truth for the UI.
- Match the reference layout, spacing, alignment, hierarchy, sizing, radius, shadows, iconography, and density before adding new interpretation.
- Reuse the same visual patterns across nearby screens so the app feels intentional and consistent instead of template-driven.
- If a request is ambiguous, choose the option that stays closest to the provided design reference and existing PadelClub patterns.
- Do not replace reference-driven design decisions with default Flutter starter styles when a visual example exists.

## Visual Direction

- Mood: calm, premium, athletic, clean, modern.
- Overall feel: polished court club branding, not generic app boilerplate.
- Prefer soft depth, rounded surfaces, and balanced whitespace.
- Keep the interface bright and approachable. Avoid harsh contrast unless it is intentional.

## Color Palette

Use this palette as the default visual language:

- Primary green: #1F7A63
- Secondary blue: #2E6BD7
- Admin header blue: #2F64E7
- Soft admin blue surfaces: #EAF1FF, #DDE8FF
- Deep green accent: #27423A
- Soft mint tint: #E8F4EF
- Page background: #F4F7F2
- White surface: #FFFFFF
- Gradient support tones: #EFF6F1, #D9EDE4, #F8FAF6
- Cool panel tones: #EEF3FB, #DCE7FA
- Border neutral: #DDE5DC
- Supporting text: #5C6B64
- Strong text: #27423A
- Error accent: #C95C4C

Do not drift back to default Flutter purple unless the user explicitly asks for it.

## UI Rules

- Prefer Material 3 patterns.
- Use rounded corners for cards, buttons, fields, and chips.
- Use soft shadows, not heavy shadows.
- Keep layouts centered and spacious when appropriate, but allow clean mobile layouts with search bars, filter chips, and stacked cards.
- Use subtle gradients or layered backgrounds instead of flat single-color screens.
- White content surfaces with green and blue accents are encouraged when the screen needs a more informational, app-like feel.
- For desktop/admin layouts, blue can become the dominant structural color in the top bar and active navigation, while green stays present in actions and status accents.
- Make primary actions obvious and visually dominant.
- Keep forms clean, readable, and easy to scan.

## Typography

- Use clear hierarchy with strong section titles and lighter supporting text.
- Prefer short, confident copy.
- Avoid dense walls of text.
- Headings should feel premium and purposeful, not generic template copy.

## Components

- Buttons should be full-width for primary actions when used in login or onboarding flows.
- Inputs should be padded, rounded, and clearly separated.
- Icons should support the meaning of the screen, not decorate it randomly.
- Empty states and placeholder screens should still feel intentional and branded.
- For results or discovery pages, use search fields, pill filters, status badges, and bottom navigation patterns that feel like a modern mobile app.
- For desktop admin pages, use a strong blue top navigation bar, a white workspace canvas, compact page titles, search and filter rows, and card or table layouts with clear action columns.
- Notifications and management dashboards should feel like the screenshot: top nav tabs, page title with subtitle, filter chips, compact search controls, status pills, and clean table rows or cards.

## Motion And Depth

- Keep motion subtle and helpful.
- Avoid overly flashy animations.
- Use layered backgrounds, translucent cards, and gentle shadows for depth.
- Let blue appear as a secondary accent for navigation, statuses, charts, and links. Keep green as the brand anchor.
- On desktop admin screens, the top header and active navigation can use blue more heavily than mobile screens, but it should still feel like part of the same product family.

## Clean Flutter Architecture Guidelines

Any code restructuring, refactoring, or new features added to the UI must strictly adhere to **Clean Architecture** patterns, structured by feature.

### 1. Folder Structure (Feature-First)
All new features must be placed inside `lib/features/<feature_name>/` and structured as follows:
```
lib/features/<feature_name>/
  domain/                 # Business logic, independent of external frameworks
    entities/             # Plain Dart business objects (no JSON serialization)
    repositories/         # Abstract definitions (interfaces) for data retrieval
    usecases/             # Application-specific business rules (single action classes)
  data/                   # Retrieve and save data
    datasources/          # Remote (HTTP/GraphQL clients) & Local (SQLite/Preferences) sources
    models/               # Extends entities, implements JSON serialization (fromJson/toJson)
    repositories/         # Concrete implementation of domain repositories
  presentation/           # UI and State
    providers/            # State management classes (e.g. ChangeNotifier / Notifier)
    screens/              # Full-page screen widgets
    widgets/              # Component-level widgets
```
Shared code (common widgets, network clients, base errors, config) should reside in `lib/core/` (e.g., `lib/core/error/`, `lib/core/widgets/`, `lib/core/theme/`).

### 2. Dependency Flow and Separation of Concerns
- **Domain is Pure**: The `domain/` layer must contain pure Dart code only. It must not import `package:flutter/material.dart`, any database, state management libraries, or the `data` layer.
- **Dependency Direction**: Dependencies must point inward toward the domain layer: `Presentation -> Domain <- Data`.
- **Abstract Contracts**: Use Cases must depend only on repository *interfaces* defined in the domain layer, not on concrete repository implementations.
- **Dependency Injection**: Instantiate and inject dependencies (using constructor injection) via a service locator (e.g. `GetIt`) or scoped providers.

### 3. Layers Definition and Conventions
- **Use Cases**: Each use case class should perform a single action and expose a single public method (e.g. `call`).
- **Models vs Entities**: Never use models in domain use cases or entities. Models (which have serialization logic) are strictly restricted to the `data/` layer. They should map to entities when passing data back to the domain.
- **Providers**: Presentation state controllers (Providers) should manage UI state and invoke Use Cases. They should not directly perform HTTP requests, database transactions, or import the `data` layer.

### 4. Import Guidelines
To prevent dependency leaks and maintain high refactorability, follow these import rules:
- **No Layer Violations via Imports**:
  - The `domain/` layer must NEVER import libraries or files from the `presentation/` or `data/` layers.
  - The `presentation/` layer must NEVER import concrete data sources, database drivers, or remote API models directly. It must only interact with domain entities, usecases, and repository interfaces.
- **Package vs Relative Imports**:
  - **Use Package Imports** (e.g., `import 'package:padelclub_desktop/features/...';`) when importing across layers, across different features, or from `lib/core/`.
  - **Use Relative Imports** (e.g., `import 'widgets/product_card.dart';`) only within the *same* feature subdirectory (e.g., when a screen imports a widget from the same presentation subdirectory). Never use relative path jumps (`../../`) to traverse features or layers.
- **Professional Import Ordering**: Group and order imports alphabetically within these blocks, separated by a single blank line:
  1. Dart core libraries (e.g., `import 'dart:async';`)
  2. Flutter framework (e.g., `import 'package:flutter/material.dart';`)
  3. Third-party packages (e.g., `import 'package:provider/provider.dart';`)
  4. Local package absolute imports (e.g., `import 'package:padelclub_desktop/...';`)
  5. Local relative imports (only when allowed inside the same subdirectory)

## Code Style For UI Work

- Prefer cohesive widgets over one-off styling scattered through the tree.
- Extract reusable themed pieces when the same visual pattern repeats.
- Keep login, onboarding, and entry screens elegant and focused.
- When adding new screens, match the established PadelClub palette and tone.
- If a screen resembles a results or search dashboard, echo the screenshot style: clean white background, strong header, search bar, filter pills, card list, and a bottom navigation bar.
- If a screen resembles a desktop admin view, echo the screenshot style: blue top app bar, left-aligned app branding, horizontal section navigation, white content surface, notification or management table, and compact action buttons.

## Product Feature Implementation Pattern

When working on the product feature, follow this implementation shape unless the user explicitly requests a different architecture:

- Keep the main product provider as a `ChangeNotifier` with a clear `get({Map<String, dynamic>? filter})` method.
- Build the request URL from the base API URL, append query parameters when filters are present, and call the HTTP client directly for this feature.
- Parse the API response into a `SearchResult` and return a `List<Product>`.
- Keep the domain entity in `lib/features/product/domain/entities/` and use data models in `lib/features/product/data/models/` for JSON handling.
- Keep the logged provider as a thin wrapper that adds timing or logging around the base provider instead of reworking the request flow.
- Avoid the earlier broken pattern of using undefined values, missing response parsing, or returning inconsistent types.

## Do Not

- Do not introduce random accent colors without a clear reason.
- Do not revert to default starter-template UI.
- Do not drift away from Figma or screenshot references when they are available.
- Do not use cluttered layouts, oversized borders, or loud gradients.
- Do not sacrifice readability for decoration.
- **Do not violate layer boundaries**: Never import data-layer code or concrete repositories into the domain or presentation layers (except when registering dependencies).
- **Do not put serialization logic in Entities**: Keep entities free of `fromJson`/`toJson` methods.
- **Do not reintroduce inconsistent provider logic**: avoid undefined response values, ad-hoc `data` access, or returning the wrong type from the provider.

## Default Design Intent

If a future prompt is ambiguous, choose the version that feels like a premium padel club app: green, airy, rounded, calm, easy to use, with blue as a supporting accent for structure, and a more assertive blue admin style for desktop management surfaces.
