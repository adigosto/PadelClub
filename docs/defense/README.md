# PadelClub preparation and professor defense

Prepared from the working tree during 6–7 September 2026, including uncommitted code. This pack is for studying the implementation; it does not change application behavior.

## How to study

Read one stage at a time. Keep the referenced source open and rehearse the action before moving on. Having the documents does not mean you have demonstrated understanding.

1. [Project analysis and complete feature map](PROJECT_MAP.md): applications, architecture, screens, API groups, permissions, workflows and limitations.
2. [Tutor lessons](TUTOR_LESSONS.md): architecture, desktop, mobile, backend, database and advanced concepts, with explanations and rehearsal prompts.
3. [Database guide](DATABASE.md): entities, keys, relationships, delete behavior and read-only SQL demonstrations.
4. [Demonstration plan](DEMONSTRATION.md): startup, a 15-minute walkthrough and alternative cross-application sequences.
5. [Defense cheat sheet](CHEAT_SHEET.md): the facts to memorize, concepts to understand, 20 questions and priority code.
6. [Readiness and examiner protocol](READINESS.md): risks and the later mock-defense procedure.
7. [Source index](SOURCE_INDEX.md): all 623 indexed source/test/build/script files, controller declarations, entity properties and EF relationships. `source-index.json` also records file hashes. This lexical index is not a line-by-line review or runtime coverage report.

## Evidence boundary

The preparation is based on source inspection of application entry points, routing, providers, HTTP calls, controllers, services, models, EF configuration, migrations, workers, infrastructure and relevant tests. Legacy/commented UI, generated files and API-only features are distinguished from active screens.

The API and test project compiled during a focused existing-test run. Nine selected tests passed, zero failed and zero skipped. Selection: `ProductUpdateStateTests`, `ProductRecommendationTests`, `PasswordHasherTests`, `OutboxPublisherDeadlineTests` by fully qualified name filter; a filter term need not correspond to a discovered test class. This is not a claim that the complete suite, SQL integration tier, Flutter UI, Compose stack or external providers were exercised in this preparation session.

All relative Markdown file links were checked and resolved. The optional study companion passed a strict TypeScript no-emit check against the installed canvas declarations; it was not visually exercised in the host renderer.

No live email, push, payment, account deletion or database demonstration was executed. Commands and demonstration sequences below are rehearsal instructions. Current local configuration and current database contents may differ from fresh seeded data.

## Preparation sequence

Tutor Mode remains active. We start with architecture, then desktop and mobile, then trace the shared workflows through the backend and database. Questions printed in the lessons are practice material, not an active examination.

Only after preparation and your explicit **“Start the defense.”** instruction does Professor Mode begin. The examiner then asks one task at a time, waits for your answer, evaluates it and tracks your performance. No readiness score is invented before you answer.
