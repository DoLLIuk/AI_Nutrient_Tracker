# Beta Analytics Contract

Status: event schema, in-app instrumentation, Firebase adapter, and Android/iOS Firebase configuration files are implemented. Android DebugView is verified; iOS verification is still required.

Last updated: 2026-07-11

## Purpose

Measure the Beta v1 core loop without collecting meal contents, photos, body measurements, API keys, request IDs, or other unnecessary personal data.

The client owns a provider-neutral `Analytics` interface in `lib/analytics.dart`. Android and iOS release builds use `FirebaseAnalyticsAdapter`; unsupported desktop targets keep the debug-only implementation. It sends only the events and properties in this document.

Before beta invitations, verify the events in a real Android and iOS device build through Firebase DebugView. Until then, the analytics release gate in `BETA_V1_CHECKLIST.md` remains unchecked.

## Required Events

| Event | When it fires | Allowed properties |
| --- | --- | --- |
| `app_opened` | When the Flutter app process starts and when it returns from background to foreground. It is not sent for a brief `inactive` interruption such as a system dialog. | None |
| `onboarding_started` | User taps **Get started** on Welcome. | None |
| `onboarding_step_viewed` | A distinct onboarding step becomes visible. | `step`: integer `0` (Welcome) through `6` (plan result) |
| `onboarding_completed` | A new user finishes onboarding. | None |
| `first_meal_logged` | The user's first saved meal is added. | None |
| `meal_logged` | A newly saved meal is added. | `source`: `ai` or `manual`; `day_offset`: integer relative to the current local day; `creates_new_session`: boolean |
| `meal_logged_in_existing_session` | A newly saved meal joins an existing app logging session: the same diary day and no more than 15 minutes from an adjacent logging timestamp. | `source`: `ai` or `manual`; `day_offset`: integer relative to the current local day |
| `photo_analysis_succeeded` | The photo analysis request returns a usable response. | `source`: `camera` or `gallery`; `requires_portion_confirmation`: boolean |
| `photo_analysis_failed` | The photo analysis request fails. | `source`: `camera` or `gallery`; `error_code` |
| `manual_fallback_used` | The user selects **Add manually** from a photo error. | `error_code` |
| `meal_edited` | A saved meal is changed. | `source`: `ai` or `manual` |
| `meal_deleted` | A saved meal is deleted. | `source`: `ai` or `manual` |

`day_offset` lets the provider group a meal with its intended diary day without receiving the raw date or timezone. `creates_new_session` identifies a new app meal session without exposing its timestamp or session ID. `meal_logged_in_existing_session` repeats only the non-sensitive source/day-offset context for diagnostic analysis; it sends no raw time or session identifier. Do not send raw dates, timezones, meal timestamps, session IDs, meal names, photos, or onboarding values unless there is a documented product need.

## Derived Beta Metrics

- **App-open denominator:** users with `app_opened`; this is the base for active-user and return calculations.
- **Onboarding funnel:** `app_opened → onboarding_started → onboarding_step_viewed(step) → onboarding_completed`. Step drop-off is measured from the last viewed step, not inferred from completion alone.
- **Onboarding completion:** users with `onboarding_completed` divided by users who emitted `onboarding_started` in the same analysis cohort.
- **First meal rate:** users with `first_meal_logged` after onboarding divided by users with `onboarding_completed`.
- **Activation:** within 168 elapsed hours after `onboarding_completed`, a user logs at least 3 `meal_logged` events and at least 2 of those events have `creates_new_session = true`. Activation time is the timestamp of the third qualifying logged meal. This measures repeat app logging sessions, not real meals eaten: batch-logging within one 15-minute diary session does not satisfy the second-session criterion.
- **D2 app return:** an activated user emits `app_opened` between 18 (inclusive) and 42 (exclusive) elapsed hours after activation.
- **D2 logging return:** an activated user emits at least one `meal_logged` event in the same 18–42 hour window. This is the primary habit metric; D2 app return is its denominator/context metric.
- **Eligible D2 denominator:** activated users for whom the full 42-hour observation window has elapsed.
- **Same-session logging rate:** `meal_logged_in_existing_session / meal_logged` events. Also report the share of meal loggers with at least one diagnostic event.
- **Potential activation-rule suppression:** users with at least 3 meal logs in the activation window, fewer than 2 new sessions, and at least one `meal_logged_in_existing_session`. Treat this as an upper bound on batch-logging impact, not proof that different real meals were backfilled.
- **Photo failure rate:** `photo_analysis_failed / (photo_analysis_succeeded + photo_analysis_failed)`.
- **Manual fallback usage:** users or events with `manual_fallback_used`.
- **Editing/deletion rate:** counts of `meal_edited` and `meal_deleted` relative to logged meals.

## Beta cohorts and reporting

- The full cohort contains every invited tester. Its report names `N_invited`, `N_opened`, `N_onboarding_started`, `N_onboarding_completed`, and `N_activated_all`.
- The D2 cohort is a subset: testers who complete onboarding by `t0 + 120h` in the approved 14-day beta and become D2-eligible after activation. Its report names `N_onboarding_by_cutoff`, `N_D2_eligible`, `N_D2_app_return`, and `N_D2_logging_return`.
- Show absolute N beside every percentage. Do not put the full-cohort activation percentage and the D2-cohort return percentage into one funnel or compare them without their denominators.

## Time and timezone policy

- Provider event timestamps are evaluated in UTC and cohort windows use elapsed hours, not calendar dates.
- Activation and D2 calculations must use the provider timestamp of the listed events. Do not calculate them from `day_offset`.
- The diary's visible "today" remains based on the user's device-local calendar day. That UI behavior is intentionally separate from behavioural cohort measurement.
- This avoids a false D2 result when onboarding/activation happens near midnight or when analytics users live in different timezones.

## Provider Integration Rules

When a provider is chosen:

1. Implement a separate `Analytics` adapter; do not add provider calls directly to widgets or controllers.
2. Keep the exact event names and property meanings above stable for the first beta cycle.
3. Send only the listed properties.
4. Do not initialize the provider with `API_KEY`, meal names, images, nutrition values, onboarding inputs, or backend request IDs.
5. Document the provider's privacy configuration, retention, consent requirement, and dashboard queries before enabling release builds.
6. Add an adapter test and verify a real iOS and Android beta build before checking the analytics release gate.
