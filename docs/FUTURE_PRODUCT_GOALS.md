# Future Product Goals

Status: post-v1 strategy and future product direction.

Last updated: 2026-07-06

> Stage order and quality gates through Public v1 are now governed by [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md). This document remains the detailed strategy for work after that release; the master roadmap wins if they differ.

## 1. Purpose

This document collects future product goals for AI Nutrient Tracker after the core food logging loop is validated.

It is intentionally not the MVP source of truth. For current `Beta v1` scope, use [MVP_PRD.md](MVP_PRD.md). For future AI coach details, use [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md).

## 2. Strategic Direction

The product should remain nutrition-first.

The long-term opportunity is:

`fast food logging + clear daily progress + personal nutrition context -> a calm AI nutrition coach`

Do not expand into a broad health app too early. Workouts, sleep, weather, and wearable data are useful only when they improve nutrition decisions.

## 3. Release Horizon

The exact Beta v1 and Public v1 scope is maintained only in [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md). In particular, Public v1 includes account backup/restore, subscriptions, Premium history, and weekly reports; it does not include the full AI coach.

This document starts after Public v1. A personalized AI nutrition coach with an optional user-provided routine and coach reminders is a candidate post-v1 Premium direction, not a committed feature. Its discovery and manual concierge validation are defined in [planning/PRODUCT_AND_LAUNCH_PLAN.en.md](../planning/PRODUCT_AND_LAUNCH_PLAN.en.md). Health integrations, live multi-device sync, and broader fitness data remain later candidates.

## 4. Future AI Nutrition Coach

If research validates the direction, the future AI coach should be a personal nutrition companion, not a general health assistant. The first capability must be one proven proactive behaviour; `Today` cards and user-initiated `Ask` are separate later decisions, not an approved bundle.

Core context:

- food log;
- calorie and macro targets;
- current day progress;
- meal timing;
- user goal;
- repeated eating patterns.

Future optional context:

- routine;
- activity calories;
- workouts;
- steps;
- weight with explicit permission;
- sleep only when relevant to eating patterns;
- weather only when it affects routine or meal timing.

See [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md) for the detailed spec.

## 5. Integrations

Integrations should support nutrition advice, not replace the product's core.

Likely priority:

1. Android Health Connect
2. Apple HealthKit
3. Fitbit/Google Health or another provider if public APIs and permissions fit the product

Useful data:

- active calories / active energy burned;
- workouts / exercise sessions;
- total calories burned if reliable;
- steps as weak context;
- weight with explicit permission.

Data to treat carefully:

- sleep: useful for explaining routine and appetite, but not core;
- heart rate, readiness, stress, and vitals: avoid unless there is a clear nutrition-specific use and safety review;
- medical data: out of scope.

References:

- Android Health Connect data types: https://developer.android.com/health-and-fitness/health-connect/data-types
- Apple HealthKit: https://developer.apple.com/health-fitness/

## 6. Reminders And Scheduling

Push reminders can become a useful retention layer only after the core diary works and the manual concierge test demonstrates that a concrete reminder behaviour helps rather than annoys users.

Good reminder types:

- meal-time reminder;
- "you still have protein left" reminder;
- "you have logged breakfast, finish the day" reminder;
- gentle evening summary.

Avoid:

- guilt-based streak pressure;
- too many notifications;
- pretending to know the user's schedule before they provide it;
- reminders that require exact calorie accuracy from uncertain data.

Minimum requirements before shipping:

- notification permission flow;
- quiet hours;
- user-editable schedule;
- off switch;
- analytics for open/dismiss behavior.

## 7. Monetization

Do not monetize before the core loop has evidence.

Prerequisites:

- stable beta;
- first user testimonials;
- eligible D2 app/logging return signal; add day-7 only after its elapsed-time window and denominator are defined;
- users logging more than one meal per active day;
- clear understanding of which feature creates willingness to pay.

Possible premium features:

- higher photo-analysis limits;
- extended history;
- personalized AI nutrition coach, optional routine, and coach reminders after Public v1;
- integrations-enhanced insights;
- advanced trends;
- live multi-device sync later.

Avoid early mistakes:

- blocking manual logging;
- paywalling before value is felt;
- selling streak pressure;
- adding a subscription before analytics can measure conversion and churn.

## 8. Analytics Roadmap

Minimum beta analytics:

- `app_opened`
- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_completed`
- `first_meal_logged`
- `meal_logged` with `source`, `day_offset`, and `creates_new_session`
- `meal_logged_in_existing_session`
- `photo_analysis_succeeded`
- `photo_analysis_failed`
- `manual_fallback_used`
- `meal_edited`
- `meal_deleted`

Beta D2 return is derived from the provider timestamps of `app_opened` and `meal_logged`; it is not sent as a separate event. Day-7 retention is not a Beta v1 decision metric until its own elapsed-time window and denominator are approved. See [ANALYTICS.md](ANALYTICS.md).

Future monetization analytics:

- `free_daily_limit_hit`
- `paywall_shown_limit`
- `paywall_shown_history`
- `paywall_shown_coach`
- `purchase_started`
- `purchase_success`
- `purchase_cancel`
- `restore_purchase_started`
- `restore_purchase_success`

Future coach analytics:

- `coach_card_seen`
- `coach_card_dismissed`
- `coach_card_action_taken`
- `ask_coach_opened`
- `ask_coach_question_sent`
- `coach_suggestion_followed`

## 9. Technical Roadmap

Near-term engineering:

- reduce `lib/main.dart` ownership gradually;
- isolate home state/actions;
- strengthen persistence boundaries;
- add production analytics abstraction;
- improve environment configuration;
- make photo API errors and fallbacks easier to test.

Future engineering:

- more robust local database than `SharedPreferences`;
- sync-ready data model;
- account model;
- privacy-aware health integration layer;
- structured nutrition context object for deterministic cards and future AI;
- backend support for coach requests if LLM features are server-side.

## 10. Launch And Growth

Do not silently drop the project into app stores, but also do not optimise for broad discovery while its differentiated offer is unproven. The canonical discovery-to-beta plan is [planning/PRODUCT_AND_LAUNCH_PLAN.en.md](../planning/PRODUCT_AND_LAUNCH_PLAN.en.md): first conduct 8–10 problem interviews, then a small consent-based concierge/usability test, then recruit the approved 20–50-person Beta v1 cohort from a targeted partner audience.

TestFlight and Google Play closed tracks distribute an already recruited cohort; beta directories, Product Hunt, BetaList, and broad community promotion do not validate organic retention. Defer them until a repeated problem, a credible offer, and early user evidence exist.

## 11. Sponsor And Partner Timing

Do not start with sponsors. Start with users.

Good timing for sponsors or partners:

- working beta;
- clear demo video;
- 50-100 users or a strong early cohort;
- 3-5 useful testimonials;
- basic retention and usage numbers.

Possible partners:

- local trainers;
- small gyms;
- nutrition coaches;
- student wellness communities;
- creators focused on nutrition and fitness.

Best ask:

`Here is a working beta. Can your audience test it and give feedback?`

Avoid:

`Please fund an unvalidated idea.`

## 12. Decisions To Delay

Delay until after beta evidence:

- exact subscription price;
- paywall frequency;
- full AI coach scope;
- first health integration;
- live multi-device sync architecture;
- public launch timing;
- sponsor pitch.

Making these decisions after real usage will reduce wasted work.
