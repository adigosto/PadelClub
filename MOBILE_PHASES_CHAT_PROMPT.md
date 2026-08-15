# PadelClub Mobile UI Phases — New Chat Prompt

Continue the PadelClub UI modernization, now focusing on the mobile Flutter app.

## Project context

- Repository root: `C:\Users\User\Desktop\PadelClub`
- Review all applicable `AGENTS.md` files before making changes.
- The existing Flutter project currently visible in the repository is `UI/padelclub_desktop`. First inspect the repository and identify whether the mobile app exists under another path. If it does not exist, report that clearly before scaffolding anything; do not assume that the desktop project should be converted into the mobile app.
- Desktop UI modernization phases are already complete.
- Notifications have been implemented on the backend and connected to the desktop frontend.
- The notification API runs through Docker on `http://localhost:5001`.

## Design direction

Preserve the established PadelClub design and architecture. Keep green as the main brand anchor and blue as the supporting accent. Use the supplied mobile mockups as visual direction and family resemblance, not as pixel-perfect specifications.

The mockups cover:

- Home dashboard with greeting, notification cards, horizontal review cards, and a shortcut/gallery grid.
- Reservation flow with horizontal date selection, court availability, and selectable time slots.
- Search/results with search input, filter pills, recent matches, player rankings, and upcoming tournaments.
- Profile with avatar, membership badge, statistics, achievements, settings rows, support, app information, and logout.
- Shop with search, categories, promotional banner, two-column product cards, prices, ratings, and add-to-cart actions.
- Persistent five-item bottom navigation: Home, Search, Reservations, Shop, and Profile.

Use consistent Material icons instead of copying placeholder emoji or low-fidelity mockup graphics. Preserve the app's clean, premium, rounded, airy appearance with soft shadows and restrained surfaces.

## Implementation approach

Work in explicit phases, completing and verifying one phase before proceeding to the next:

1. Inspect the mobile project, current navigation, theme, architecture, reusable widgets, implemented screens, and backend integrations. Present a concise phase plan based on what actually exists.
2. Build or refine the shared mobile design system and five-destination navigation shell.
3. Modernize the Home screen.
4. Modernize the Reservations experience and connect it to existing reservation logic.
5. Modernize Search/results, rankings, matches, and tournaments using existing data where available.
6. Modernize the Profile and settings experience.
7. Modernize the Shop while preserving existing product/cart behavior.
8. Perform responsive, loading, empty, error, accessibility, and visual consistency cleanup across mobile.

For every phase:

- Preserve working behavior and existing green/blue branding.
- Follow the existing feature-first Clean Architecture conventions.
- Reuse shared widgets rather than duplicating screen-specific styling.
- Do not invent backend endpoints when the required data is unavailable; identify the gap first.
- Format changed Dart files.
- Run focused analysis/tests, then broader relevant checks when practical.
- Summarize changed files, verification results, and the next phase.

Start now with Phase 1: inspect the repository and mobile implementation, then proceed with the first safe implementation phase without asking redundant questions.
