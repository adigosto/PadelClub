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

## Code Style For UI Work

- Prefer cohesive widgets over one-off styling scattered through the tree.
- Extract reusable themed pieces when the same visual pattern repeats.
- Keep login, onboarding, and entry screens elegant and focused.
- When adding new screens, match the established PadelClub palette and tone.
- If a screen resembles a results or search dashboard, echo the screenshot style: clean white background, strong header, search bar, filter pills, card list, and a bottom navigation bar.
- If a screen resembles a desktop admin view, echo the screenshot style: blue top app bar, left-aligned app branding, horizontal section navigation, white content surface, notification or management table, and compact action buttons.

## Do Not

- Do not introduce random accent colors without a clear reason.
- Do not revert to default starter-template UI.
- Do not drift away from Figma or screenshot references when they are available.
- Do not use cluttered layouts, oversized borders, or loud gradients.
- Do not sacrifice readability for decoration.

## Default Design Intent

If a future prompt is ambiguous, choose the version that feels like a premium padel club app: green, airy, rounded, calm, easy to use, with blue as a supporting accent for structure, and a more assertive blue admin style for desktop management surfaces.
