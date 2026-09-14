# Project Work Backlog

Status: working task list for making the project easier to build on.

Last updated: 2026-07-16

This document lists the main gaps to close before implementing larger features such as AI nutrition coach, integrations, monetization, public launch, accounts, or sync.

For stage ordering, quality gates, Public v1 scope, Free/Premium policy, and account/restore decisions, use [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md) as the canonical roadmap. This file stays intentionally short and practical.

It is intentionally practical. It is not a product pitch and not a detailed engineering spec.

## 1. Product Readiness

- [x] Define the exact `Beta v1` release checklist in `docs/BETA_V1_CHECKLIST.md`.
- Keep MVP scope strict: food logging, daily progress, local history, manual fallback.
- [x] Remove or soften UI that looks like real analytics but is still demo/static.
- Make the first-user experience understandable without personal explanation.
- Prepare a short beta tester script: what to install, what to try, how to give feedback.
- Decide how feedback will be collected during beta.

## 2. Core Loop Quality

- Make onboarding reliable and easy to finish.
- Make the first meal log fast enough to feel valuable.
- Make photo failure states clear and non-frustrating.
- Make manual fallback obvious and usable.
- [x] Finalize Manual Add Meal for closed beta: production-ready interaction, feature-frozen except for bug fixes. Rules: `MEAL_EDIT_AUTO_CALC.md`.
- Make Home screen answer the basic question: "How is my day going?"
- Make edit/delete behavior feel safe and predictable.
- [x] Implement delayed manual logging and safe category moves according to [MEAL_HISTORY_BACKFILL_PLAN.md](MEAL_HISTORY_BACKFILL_PLAN.md), without letting a manual category override move nearby timed meals. The optional meal-time picker remains deferred.
- Make empty states useful instead of looking unfinished.

## 3. Data And Persistence

- Clarify what local data is the source of truth.
- Make saved meals and onboarding data resilient across normal restarts.
- Prepare a cleaner persistence boundary before adding accounts or sync.
- [ ] Implement authenticated cloud backup and restore for onboarding and meal history.
- [ ] Return the welcome-screen account/restore action only when it can sign a user in and restore their data after reinstalling or changing devices; do not ship it as a placeholder.
- Track enough meal metadata for future personalization: time, meal type, source, edits, AI uncertainty.
- Avoid adding future AI or integration features before the diary data is trustworthy.

## 4. Analytics And Learning

- [x] Add a minimal analytics abstraction before beta. Event schema: `docs/ANALYTICS.md`.
- Track onboarding completion.
- Track first meal logged.
- Track photo success/failure.
- Track manual fallback usage.
- Track meals logged per active day.
- Track the app-open denominator, onboarding funnel, 168-hour activation, and eligible D2 return; define day-7 separately before using it for decisions.
- Keep qualitative feedback alongside numbers.

## 5. Code Organization

- Reduce pressure on `lib/main.dart` before adding large new flows.
- Extract only when it reduces real confusion or risk.
- Keep manual meal editing rules protected by tests.
- Avoid adding AI coach, integrations, or monetization logic directly into already crowded UI code.
- Keep feature boundaries clear: logging, home summary, photo API, profile/settings, future coach.

## 6. Backend And Configuration

- Make production/staging/local API configuration less error-prone.
- Document backend dependency expectations clearly.
- Make API error handling reliable enough for real beta users.
- Decide how secrets and API keys should be handled before public builds.
- Avoid shipping builds that require manual hidden setup from testers.

## 7. Public Launch Preparation

- Prepare privacy policy.
- Prepare medical disclaimer.
- Prepare store screenshots.
- Prepare a short demo video.
- Prepare landing/project page copy.
- Prepare a simple public explanation of AI accuracy and manual fallback.
- Do not launch publicly before beta feedback confirms the main flow.

## 8. Future Feature Foundations

Before AI nutrition coach:

- stabilize food log data;
- define the nutrition context object;
- define safety/copy rules;
- define what a coach suggestion can and cannot say;
- add dismiss/correction paths for suggestions.

Before health integrations:

- decide first platform: Android Health Connect or Apple HealthKit;
- define exactly which data is useful for nutrition;
- design permission and no-data states;
- avoid broad fitness tracking scope.

Before monetization:

- prove repeat usage;
- understand which feature users value;
- avoid blocking manual logging;
- add analytics for paywall and conversion if/when paywall exists.

Before accounts/sync:

- clean up local data model;
- define conflict behavior;
- define deletion/export expectations;
- decide what data should remain local-only.

## 9. Near-Term Priority Order

1. Lock `Beta v1` checklist.
2. Stabilize core loop.
3. Add beta analytics/feedback path.
4. Clean the most painful code boundaries.
5. Prepare beta distribution and tester materials.
6. Use beta results to choose the next feature.

## 10. Rule Of Thumb

If a task does not improve beta learning or protect the future architecture, delay it.

The project should earn bigger features by proving the smaller loop first.
