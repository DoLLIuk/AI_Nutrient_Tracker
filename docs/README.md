# Documentation Map

This folder is the working memory for AI Calorie Tracker.

Use this map before changing product scope, architecture, AI behavior, or launch strategy.

## Canonical Docs

- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md): shareable project handoff — current capabilities, decisions, risks, and next priorities.
- [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md): master stage-by-stage quality roadmap from internal alpha through Public v1 and its first 30 days.
- [agent_guide.md](agent_guide.md): engineering source of truth for future contributors and AI agents.
- [MVP_PRD.md](MVP_PRD.md): current `Beta v1` product scope and success criteria.
- [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md): approved release gates, beta success definition, tester script, and go/no-go rules.
- [ANALYTICS.md](ANALYTICS.md): Beta event contract, privacy boundary, and provider integration rules.
- [FUTURE_PRODUCT_GOALS.md](FUTURE_PRODUCT_GOALS.md): post-v1 roadmap, launch, monetization, integrations, and sponsor timing.
- [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md): future personalized AI nutrition coach spec. Not MVP scope.
- [PROJECT_WORK_BACKLOG.md](PROJECT_WORK_BACKLOG.md): practical gaps to close before larger feature implementation.
- [MEAL_EDIT_AUTO_CALC.md](MEAL_EDIT_AUTO_CALC.md): detailed manual meal editing rules.

## How To Read

For implementation work:

1. Start with [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) when joining the project or handing it to another person.
2. Start with [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md) to identify the current stage and its quality gate.
3. Read [agent_guide.md](agent_guide.md) before engineering changes.
4. If the work changes product scope, check [MVP_PRD.md](MVP_PRD.md).
5. If the work affects beta readiness or distribution, check [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md).
6. If the work touches beta telemetry, check [ANALYTICS.md](ANALYTICS.md).
7. If the work is future-facing, check [FUTURE_PRODUCT_GOALS.md](FUTURE_PRODUCT_GOALS.md).
8. If the work touches AI coach behavior, check [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md).
9. If the work is about project readiness or cleanup, check [PROJECT_WORK_BACKLOG.md](PROJECT_WORK_BACKLOG.md).
10. If the work touches manual meal editing, check [MEAL_EDIT_AUTO_CALC.md](MEAL_EDIT_AUTO_CALC.md).

## Current Product Boundary

Near-term target: `Beta v1`.

Current product is a nutrition-first food logger:

`onboarding -> meal logging -> daily calories/macros -> session history -> return habit`

The current app does not yet implement AI coach, health integrations, subscriptions, push scheduling, accounts, or sync. Their planned order and Public v1 boundaries are defined in [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md); they must not be treated as existing behavior.

## Public Planning Notes

The `planning/` folder contains public-facing planning notes in Russian and English. Those files are useful for launch and strategy, but `docs/` remains the canonical technical/product working memory.
