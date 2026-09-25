# AI Nutrient Tracker Agent Guide

This document is the canonical engineering and AI-agent reference for the AI Nutrient Tracker repository. The Dart and Flutter package name remains `my_new_app`.

Read this first if you need to understand:

- what the app does
- how data moves through the app
- where to change behavior safely
- which files matter most
- what not to break

The goal is to let a new engineer or AI agent work in the right place without reading large parts of the codebase first.

## 1. System Purpose

This repository contains a Flutter calorie-tracking client with three core jobs:

1. collect enough onboarding data to calculate a nutrition plan
2. let the user log meals from photos or manual entry
3. turn raw meal entries into useful daily progress and session-based history

The app is intentionally client-heavy for local UX and persistence, but photo understanding is delegated to a separate backend API.

What the app is optimized for:

- fast onboarding-to-tracking flow
- simple daily nutrition tracking
- photo-based meal logging with fallback clarification and portion confirmation
- local-first behavior for progress/history once a meal has been saved

What it is not optimized for:

- multi-user sync
- offline photo analysis
- secure secret management on-device
- complex backend-driven state
- a fully modular frontend architecture yet
- a full AI nutrition coach or general health assistant yet
- first-party workout, sleep, or wearable tracking

## 2. Product Direction And Documentation Map

The current product strategy is intentionally narrow:

`fast meal logging -> clear daily calories/macros -> return habit`

The near-term release target is `Beta v1`, not a fully monetized public product. `Beta v1` should prove that users can complete onboarding, log meals, understand the day summary, and return later.

Important product boundaries:

- The current app is a nutrition-first food logger.
- The current Home coach card is heuristic guidance, not an LLM coach.
- A future personalized AI nutrition coach is a post-v1 differentiator, not MVP.
- External activity data may later improve nutrition advice, but the app should not become a broad fitness tracker.
- Monetization, paywalls, subscriptions, push scheduling, accounts, and cloud sync are future work until the core loop has real user evidence.

Documentation roles:

- `README.md`: public-facing project presentation. Edit carefully.
- `docs/README.md`: documentation map and reading order.
- `docs/agent_guide.md`: current engineering source of truth for agents.
- `docs/MVP_PRD.md`: `Beta v1` scope, success criteria, and out-of-scope boundaries.
- `docs/BETA_V1_CHECKLIST.md`: approved beta release gates, success definition, and tester acceptance script.
- `docs/ANALYTICS.md`: beta event contract and privacy-safe provider integration boundary.
- `docs/FUTURE_PRODUCT_GOALS.md`: post-v1 roadmap and strategy.
- `docs/AI_NUTRITION_COACH.md`: future AI nutrition coach specification.
- `planning/`: public planning notes and launch strategy, less implementation-specific than `docs/`.

When docs conflict, prefer this order:

1. current code and tests for runtime behavior
2. `docs/agent_guide.md` for engineering context
3. `docs/MVP_PRD.md` for near-term product scope
4. `docs/BETA_V1_CHECKLIST.md` for beta release readiness
5. `docs/FUTURE_PRODUCT_GOALS.md` and `docs/AI_NUTRITION_COACH.md` for post-v1 direction

## 3. End-to-End Flows

### 3.1 App startup

Main path:

`main() -> MyApp -> hydrate SharedPreferences -> show onboarding or app shell`

Important details:

- `MyApp` is the root entry point in `lib/main.dart`.
- On startup, the app hydrates:
  - `app.onboarding.result`
  - `app.onboarding.draft`
  - `app.meals`
- Until hydration completes, the user sees a bootstrap loading screen.
- If onboarding is complete, the app opens the shell.
- Otherwise it opens `OnboardingFlow`.

### 3.2 Onboarding flow

Path:

`welcome -> goal -> profile -> activity -> pace -> macro preference -> result`

What onboarding produces:

- a persisted `OnboardingResult`
- a calculated `NutritionPlan`
- daily calorie target
- protein, fat, and carb targets

The app uses that result in multiple places:

- calorie progress on the home screen
- macro progress cards
- coach card heuristics
- profile summary and labels
- meal session tier thresholds

Core file:

- `lib/onboarding.dart`

### 3.3 Photo meal flow

Path:

`FAB -> choose camera/gallery -> pick image -> clarification sheet (optional) -> analyze photo -> portion confirmation (optional) -> save/update meal -> rebuild sessions -> refresh home UI`

Detailed behavior:

- `PhotoFoodController.pickImage()` stores the last picked `XFile`.
- `PhotoFoodController.analyzePickedImage()` sends the image to the backend.
- The client always uses locale `ru-RU` right now.
- If the backend marks the response as needing clarification, the UI can send one clarified request with:
  - `dish_category`
  - `ingredient_hints`
  - `analysis_mode=clarified`
- If the backend returns `requires_user_confirmation`, the app opens the portion sheet.
- Portion confirmation can use:
  - explicit grams
  - or AI estimate if supported
- Successful responses are converted into local `_MealEntry` records and persisted.

Relevant files:

- `lib/photo_food/controller.dart`
- `lib/photo_food/api_client.dart`
- `lib/photo_food/models.dart`
- photo-flow UI inside `lib/main.dart`

### 3.4 Manual meal flow

Path:

`FAB -> Add manually -> fill sheet -> realtime nutrition math -> save -> rebuild sessions -> refresh home UI`

Important implementation detail:

- The sheet UI still lives inside `lib/main.dart`.
- The draft logic and recalculation rules live in `lib/meal_edit_draft.dart`.
- `meal_edit_draft.dart` is a `part` file, not an independent feature package.

Manual editing rules are non-trivial. Do not infer them from the UI. Read:

- `docs/MEAL_EDIT_AUTO_CALC.md`

That document is the product-rule reference for:

- lock behavior
- calories-to-macros rebalance
- weight scaling
- reset and restore actions
- locked-calories conflict confirmation

### 3.5 Home screen rendering

Path:

`persisted meals + onboarding targets -> rebuild sessions -> aggregate per selected day -> render cards and category sections`

The home screen shows:

- calorie progress
- macro progress
- coach guidance
- latest added meal
- grouped history sections

Most of the orchestration still lives in `lib/main.dart`.

## 4. Module Responsibilities

### `lib/main.dart`

This is the central orchestration file. It currently owns:

- app bootstrap
- persistence hydration and save queue
- shell navigation
- home screen state
- meal list mutations
- session rebuild triggers
- add-photo and add-manual flows
- clarification UI
- portion confirmation UI
- meal detail/edit surfaces

This file is the biggest change-risk area in the repo. Many features are coupled here.

### `lib/meal_edit_draft.dart`

This `part` file contains the most important manual-edit math and lock-state logic.

Owns:

- nutrition field relationships
- lock and unlock behavior
- conflict detection
- auto-adjust proposals
- reset and restore mechanics

If a change affects manual meal editing, read this file and `docs/MEAL_EDIT_AUTO_CALC.md` together.

### `lib/onboarding.dart`

Owns:

- onboarding UI steps
- validation
- unit conversion
- nutrition plan calculation
- onboarding draft serialization

If you need to change calorie targets, macro formulas, or onboarding questions, start here.

### `lib/meal_type.dart`

Owns:

- `MealType`
- time-of-day classification
- meal labels and icons

Current windows:

- breakfast: `04:00-10:29`
- lunch: `10:30-16:29`
- dinner: `16:30-23:29`
- snack: everything else

### `lib/meal_session.dart`

Owns:

- session grouping
- session IDs
- per-session nutrition totals
- auto type classification
- threshold-based session tiering
- override resolution

Important rules:

- adjacent entries within `15 minutes` stay in one session
- session type comes from the session start time window
- snacks are always `extra`
- breakfast/lunch/dinner use calorie thresholds derived from daily target
- latest user override in a session wins

### `lib/home_coach.dart`

Owns:

- coach-card state selection
- heuristic coaching copy based on:
  - selected date
  - calories consumed
  - protein consumed
  - yesterday protein
  - time-of-day context

This is pure product behavior, not backend logic.

Current boundary:

- It can use meal totals, targets, selected date, yesterday protein, and time-of-day context.
- It must not be described as a real personalized AI nutrition coach.
- If this evolves toward AI, first define data contracts and safety rules in `docs/AI_NUTRITION_COACH.md`.

### `lib/photo_food/`

Purpose: isolate backend integration and response parsing.

Files:

- `api_client.dart`: HTTP requests, multipart upload, API key header, timeout, file validation
- `api_error.dart`: API error model and UI-facing message mapping
- `controller.dart`: state machine for pick/analyze/confirm flow
- `models.dart`: backend DTO parsing
- `photo_picker.dart`: picker abstraction
- `repository.dart`: repository contract

Important client constraints enforced here:

- max image size: `8 MB`
- allowed types: `image/jpeg`, `image/png`, `image/webp`
- timeout: `25 seconds`

### `lib/profile/`

Owns:

- profile summary screen
- account/settings screen
- shared labels for onboarding-derived values

Important caveat:

- some profile content is still placeholder/product-demo style UI, not fully data-backed analytics
- examples: weekly bars, badges, and some account copy

Do not describe those as real backend-driven analytics in public docs.

## 5. Important Files And Directories

Use this as the fastest repo map.

- `README.md`: public-facing project overview
- `docs/README.md`: documentation map
- `docs/agent_guide.md`: canonical engineering reference
- `docs/MVP_PRD.md`: current `Beta v1` product scope
- `docs/BETA_V1_CHECKLIST.md`: beta release gates and tester script
- `docs/ANALYTICS.md`: beta analytics event contract
- `docs/FUTURE_PRODUCT_GOALS.md`: post-v1 roadmap and monetization/integration direction
- `docs/AI_NUTRITION_COACH.md`: future personalized AI nutrition coach spec
- `docs/MEAL_EDIT_AUTO_CALC.md`: manual meal editing rules
- `planning/`: launch and strategy planning files
- `lib/main.dart`: highest-leverage and highest-risk frontend file
- `lib/onboarding.dart`: onboarding and plan calculation
- `lib/meal_session.dart`: session logic
- `lib/meal_type.dart`: time-window classification
- `lib/home_coach.dart`: coaching heuristics
- `lib/photo_food/`: backend integration layer
- `lib/profile/`: profile/settings UI
- `test/widget_test.dart`: major integration-style behavior coverage
- `test/meal_session_test.dart`: session grouping and override behavior
- `test/photo_food_parsing_test.dart`: API parsing assumptions
- `test/api_error_and_validation_test.dart`: error parsing and validation expectations

## 6. Configuration Model

### Runtime configuration

The app reads API configuration from compile-time Dart defines:

- `API_BASE_URL`
- `API_KEY`

Source:

- `lib/app_config.dart`

If either value is missing, app initialization throws a `StateError`.

### Persistence

The app stores local state in `SharedPreferences`:

- `app.onboarding.result`
- `app.onboarding.draft`
- `app.meals`

This means:

- onboarding survives restarts
- meals survive restarts
- there is no remote sync layer in this repo

### Backend assumptions

The frontend expects a separate backend exposing:

- `POST /v0/ai/photo-food`
- `POST /v0/ai/photo-food/confirm-portion`

It sends:

- `X-API-Key`
- multipart `image`
- `locale`
- optional `meal_time`
- optional clarification fields

The linked backend repo path provided for this project is:

- `C:\Users\golov\rofl_codex\backend_for_diet_app`

This path is a local development reference for AI-agent workflows in the author's environment. It is not a public service endpoint, deployment identifier, or runtime config value for the client.

That backend README is useful for contract context, but the frontend must still stay honest to what its own code actually sends and consumes.

## 7. Architectural Decisions And Tradeoffs

### 7.1 Client-side sessionization instead of backend-driven grouping

Why:

- makes the home screen responsive
- avoids extra backend dependencies for timeline rendering
- keeps session rules easy to test in Dart

Tradeoff:

- grouping behavior must stay consistent everywhere meals are mutated
- changing session rules may require migration care for persisted meals

### 7.2 Separate photo analysis from local meal management

Why:

- backend handles uncertain food recognition
- frontend stays responsible for UX, persistence, and day/session presentation

Tradeoff:

- the app depends on a strict API contract
- photo features cannot work without a compatible backend

### 7.3 Compile-time API config

Why:

- easy local setup
- simple dev/stage/prod switching during manual builds

Tradeoff:

- this is not strong secret management
- keys passed through `--dart-define` are part of the app build process
- acceptable for current development flow, but not a hardened production approach

### 7.4 Monolithic home/add/edit orchestration in `main.dart`

Why:

- fast iteration during product exploration
- fewer files while the flow was changing quickly

Tradeoff:

- harder navigation for new contributors
- more accidental coupling between unrelated UI behaviors
- larger blast radius for edits

### 7.5 Nutrition-first scope

Why:

- the strongest current product loop is food logging and day-level nutrition feedback
- going broad into workouts, sleep, hydration, and general wellness would dilute the product
- external activity data is useful only when it improves nutrition advice

Tradeoff:

- integrations must be designed as context providers, not as new first-party product categories
- AI coach work must stay constrained to nutrition decisions unless the product strategy changes explicitly

## 8. Known Limitations

- `lib/main.dart` is still too large and mixes app shell, persistence, home logic, and add/edit flow logic.
- Photo logging requires the separate backend; there is no offline fallback.
- The current API locale passed by the client is fixed to `ru-RU`.
- Persistence is local-only and uses `SharedPreferences`, not a more structured data store.
- There is no authentication, account sync, or remote user profile model in this repo.
- Some profile surfaces are presentational rather than fully backed by real historical analytics.
- Build/deploy flow is manual; no CI/CD is defined here.
- There is no production analytics SDK yet, only debug-style event hooks in some areas.
- There is no AI nutrition coach, Ask Coach, health integration, or activity-calorie import yet.

## 9. Common Pitfalls

### Pitfall: changing meal classification in one place only

Meal classification and session tiering affect:

- home history grouping
- latest-added labels
- session summaries
- tests

If you change meal windows or thresholds, update:

- `lib/meal_type.dart`
- `lib/meal_session.dart`
- relevant tests

### Pitfall: editing manual meal math from the widget layer only

The behavior is governed by draft logic, not just text fields.

Before changing manual edit UX or save behavior, review:

- `lib/meal_edit_draft.dart`
- `docs/MEAL_EDIT_AUTO_CALC.md`
- widget tests covering edit flows

### Pitfall: assuming profile cards are all real analytics

Some profile UI is demonstrative. Be careful not to:

- wire business logic to placeholder visuals without checking
- claim backend-backed weekly trend features that do not exist

### Pitfall: forgetting session rebuild after meal mutations

Any change that adds, edits, deletes, or reclassifies a meal must preserve:

- session rebuild
- `_sessionsByEntryId` refresh
- persistence update

If you skip this, the UI can show stale grouping or wrong category/tier metadata.

### Pitfall: breaking API parsing by assuming optional fields are always present

The parsing models already tolerate some optional backend fields. Keep that flexibility unless the contract is explicitly tightened.

### Pitfall: turning future strategy into current UI copy

Do not advertise future features as implemented:

- AI nutrition coach
- Ask Coach
- Apple Health / Health Connect / Fitbit integration
- subscriptions or premium limits
- cloud sync
- real weekly analytics

If a feature is only in `docs/FUTURE_PRODUCT_GOALS.md`, `docs/AI_NUTRITION_COACH.md`, or `planning/`, label it as future work.

## 10. Safe Ways To Modify The Project

### Safe change: API error copy

Change:

- `lib/photo_food/api_error.dart`

Risk:

- low, if tests still pass

### Safe change: onboarding formulas or validation

Change:

- `lib/onboarding.dart`

Also verify:

- onboarding widget tests
- any profile/home calculations using `OnboardingResult.plan`

### Safe change: session thresholds or grouping

Change:

- `lib/meal_session.dart`
- maybe `lib/meal_type.dart`

Also verify:

- `test/meal_session_test.dart`
- home-screen category rendering behavior

### Safe change: coach card copy or heuristics

Change:

- `lib/home_coach.dart`

Risk:

- moderate product-risk, low architectural risk

Guardrail:

- keep it heuristic and nutrition-first unless a separate AI-coach implementation task is explicitly scoped

### Safe change: backend request/response contract

Change:

- `lib/photo_food/models.dart`
- `lib/photo_food/api_client.dart`
- `lib/photo_food/controller.dart`

Also verify:

- parsing tests
- clarification flow
- portion confirmation flow

### High-caution area: `lib/main.dart`

Change here only after you identify whether the logic belongs to:

- app bootstrap
- persistence
- home aggregation
- photo-flow UI
- manual meal sheet UI
- detail/edit flow

When possible, extract targeted logic instead of adding more cross-cutting code.

## 11. Extension Points

Good next refactor targets:

- extract home screen state and actions out of `lib/main.dart`
- move meal detail and meal sheet flows into `lib/meal_edit/` or `lib/home/`
- isolate clarification-sheet logic into its own widget/module
- centralize persistence serialization for `_MealEntry`

Good product extensions that fit the current architecture:

- localization of UI and backend request locale
- stronger environment/build configuration
- more robust local storage than `SharedPreferences`
- richer profile analytics backed by actual meal history
- clearer separation between AI-estimated and manually-entered meal provenance in the UI
- analytics events needed for beta learning
- health/activity integrations as optional context for nutrition advice
- future AI nutrition coach surfaces: `Today` cards and `Ask`

AI nutrition coach foundation work should start with data quality, event tracking, and explicit permissions, not with a chat UI first. See `docs/AI_NUTRITION_COACH.md`.

## 12. Testing And Verification

Primary command:

```bash
flutter test
```

Current suite emphasis:

- onboarding behavior
- photo clarification flow
- portion confirmation flow
- API parsing and validation
- session grouping and overrides
- manual meal auto-calc and lock behavior

When changing code, verify at least:

1. startup with and without saved onboarding state
2. photo flow with skip clarification
3. photo flow with clarification selection
4. portion confirmation with manual grams and AI estimate
5. manual meal add/edit with locks and reset
6. category/session rendering on the home screen

For future analytics, integrations, monetization, or AI coach work, also verify:

1. feature-disabled state
2. permissions denied state
3. no-data state
4. stale-data state
5. user correction or dismissal path
6. no medical or overconfident AI copy

## 13. Fast Navigation Recipes For AI Agents

If the task is about:

- onboarding targets or profile inputs: start in `lib/onboarding.dart`
- session grouping or meal category bugs: start in `lib/meal_session.dart` and `lib/meal_type.dart`
- photo API bugs: start in `lib/photo_food/`
- manual meal edit math: start in `lib/meal_edit_draft.dart` and `docs/MEAL_EDIT_AUTO_CALC.md`
- home aggregation or persistence side effects: start in `lib/main.dart`
- coach messaging: start in `lib/home_coach.dart`
- profile/settings UI: start in `lib/profile/`
- MVP scope questions: start in `docs/MVP_PRD.md`; for beta readiness, use `docs/BETA_V1_CHECKLIST.md`; for telemetry, use `docs/ANALYTICS.md`
- future AI nutrition coach questions: start in `docs/AI_NUTRITION_COACH.md`
- post-v1 roadmap or monetization questions: start in `docs/FUTURE_PRODUCT_GOALS.md`
