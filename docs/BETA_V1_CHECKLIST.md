# Beta v1 Checklist

Status: approved product criteria; release gates remain to be completed.

Last updated: 2026-07-11

For the full path from internal alpha to Public v1, use [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md). This document remains the authoritative checklist for the closed Beta v1 release gate.

## 1. Beta Goal

Validate the core habit loop on iOS and Android:

`complete onboarding -> log meals -> understand daily progress -> return the next day`

This beta is not a public launch, monetization test, AI nutrition coach, health integration, account, or sync release.

## 2. Beta Format

- Platforms: iOS and Android.
- Distribution: closed beta through TestFlight and Google Play Closed Testing.
- Initial cohort: 20-50 testers.
- Duration: 14 full days (`t0 → t0 + 336h`), where `t0` is the start of the main invited cohort.
- D2 measurement cohort: complete onboarding no later than `t0 + 120h` (the end of day 5). Later testers may provide qualitative feedback but are not included in the final D2 cohort.
- Feedback channel: a dedicated support email is required before invitations are sent. The final address is intentionally pending.

The closed cohort comes before any broader public discovery. It gives the team a controlled way to find critical issues and collect useful feedback before the app is promoted more widely.

The future Public v1 values of 5 AI photo analyses per day and today plus 2 previous history days are `[~]` provisional. They are confirmed or changed only in the Pricing/Entitlement gate after beta cost and usage review; this beta does not present them as a final customer promise.

## 3. Definition Of Success

### Per-user activation

A tester is activated when they:

- complete onboarding;
- within 168 elapsed hours after completion, log at least 3 meals;
- have at least 2 of those meal logs create separate meal sessions.

The activation timestamp is the provider timestamp of the third qualifying meal. A separate session is an app logging session within one diary day, using the existing rolling 15-minute gap between adjacent logging timestamps.

This intentionally measures repeat use of the app rather than the number of real meals eaten. A tester who batch-logs breakfast, lunch, and dinner in one sitting may not activate because those logs can be one app session. This is a known limitation, not a defect in sessionization. The `meal_logged_in_existing_session` diagnostic estimates how much this rule may suppress activation; it does not change the activation gate.

### D2 return

A tester has demonstrated **D2 logging return** when they log at least one additional meal between 18 and 42 elapsed hours after activation. **D2 app return** is an `app_opened` event in that same window.

The D2 denominator contains only activated testers in the D2 measurement cohort whose 42-hour observation window has elapsed. This deliberately uses elapsed hours and provider timestamps rather than local calendar dates, so midnight and timezone boundaries do not distort the result.

### Why a 7-day beta was not selected

This is historical justification for the 14-day protocol above, not an operating option. If activation is uniformly distributed across its 168-hour window and onboarding happens at `t0`, a 7-day beta can observe the full D2 window only for activation before hour 126. That is `126 / 168 = 75%` of activated testers: 15 of 20 or 37–38 of 50 if every invited tester activates. Actual N would be lower when activation is lower than 100%.

The approved 14-day protocol plus the day-5 onboarding cut-off leaves 216 hours for each eligible tester: 168 hours for activation, 42 hours for D2, and a 6-hour buffer.

### Learning outcome

At the end of the beta, show both cohort denominators and absolute N next to every percentage. Do not present activation rate and D2 return rate as one funnel because the D2 cohort is a strict subset of the full invited cohort.

Full cohort report:

- `N_invited`, `N_opened`, `N_onboarding_started`, `N_onboarding_completed`, and `N_activated_all`.

D2 cohort report:

- `N_onboarding_by_cutoff`, `N_D2_eligible`, `N_D2_app_return`, and `N_D2_logging_return`.

Then review:

- the same-session logging rate and the share of testers with `meal_logged_in_existing_session`;
- users with 3+ meal logs in the activation window, fewer than 2 new sessions, and at least one same-session diagnostic event; this is an upper-bound estimate of possible batch-logging suppression, not proof of backfilling;
- where users drop off inside onboarding;
- where photo logging fails or is abandoned;
- how often manual fallback is used;
- the five most repeated feedback themes.

No cohort-wide percentage threshold is set yet. The first closed beta establishes the baseline; its outcome is a decision to fix the core loop, iterate the beta, or proceed to broader testing.

## 4. Release Gates Before Inviting Testers

All items in this section must be true before the first invitation.

### Product and UX

- [ ] A new user can complete onboarding without author assistance.
- [ ] A user can add a first meal manually.
- [ ] A user can add a meal from camera and gallery when the backend is available.
- [ ] A clear manual fallback is available if photo analysis fails or is uncertain.
- [ ] The Home screen shows calories, macros, and the current day's logged meals clearly.
- [ ] A user can edit and delete a saved meal without confusing results.
- [ ] Empty states explain what to do next.

### Reliability

- [ ] Saved onboarding and meals survive a normal app restart on both platforms.
- [ ] The build is usable without network after onboarding when viewing already saved local data.
- [ ] API configuration is present in the beta build; testers do not need hidden setup.
- [ ] Photo API errors and timeouts show understandable copy and a manual fallback.
- [ ] Android and iOS smoke tests both pass on physical devices.

### Measurement and feedback

- [ ] The beta build records, at minimum: onboarding completion, first meal logged, new-session meal logs, same-session diagnostic logs, photo success, photo failure, manual fallback, meal edit, meal delete, and meals per active day.
- [ ] The data can identify the full-cohort and D2-cohort denominators, onboarding-step drop-off, 168-hour activation, same-session logging diagnostics, and eligible D2 app/logging return without collecting unnecessary personal data.
- [ ] A feedback email address and a short tester instruction are ready before invitations are sent.
- [ ] Testers know how to report a bug, attach a screenshot, and describe what they expected.

### Distribution and operations

- [ ] An iOS TestFlight build is uploaded and installable by an external tester.
- [ ] An Android closed-testing build is uploaded and installable by an external tester.
- [ ] The tester list, invite copy, feedback address, and support owner are prepared.
- [ ] Privacy policy and medical/nutrition disclaimer are ready for the beta distribution surfaces that require them.

## 5. Immediate No-Go Conditions

Do not invite or pause the beta if any of the following occurs:

- onboarding cannot be completed;
- a meal cannot be added manually;
- photo failure leaves the user without a workable manual path;
- a saved meal or onboarding result is lost after a normal restart;
- Home does not reflect a saved meal correctly;
- the app requires testers to enter hidden API values or perform developer setup;
- the beta build cannot be installed or launched on either target platform.

## 6. Manual Acceptance Script

Run this script on both iOS and Android before each beta candidate:

1. Start with no local app data and complete onboarding.
2. Add one meal manually; edit it; delete it; add it again.
3. Add a meal from the camera or gallery with a successful response.
4. Exercise the clarification and portion-confirmation paths when available.
5. Simulate a photo/API failure and confirm the manual fallback is clear and usable.
6. Close and relaunch the app; confirm onboarding, targets, and meals remain.
7. Confirm Home totals, session history, and the latest meal agree.
8. Verify that the required beta events and feedback path are available.

## 7. Tester Instruction: Required Content

The invitation or welcome message must explain:

- this is a 14-day closed beta for iOS and Android;
- the target task: log at least 3 meals across 2 sessions during the first week, then return and log again the following day;
- photo logging may be imperfect and manual entry is always acceptable;
- Home may show a `Today’s tip` based on current daily progress; it is deterministic guidance, not AI coaching or medical advice;
- how to send feedback, screenshots, device model, app version, and steps to reproduce;
- that nutrition estimates are informational and not medical advice.

## 8. Go / No-Go Decision

### Go

Start the closed beta only when every release gate in section 4 is checked and no immediate no-go condition exists.

### Pause or iterate

Pause invitations, fix the issue, and rerun the acceptance script when a no-go condition occurs or the feedback path/measurement is missing.

### End-of-beta review

After 14 days, summarize full-cohort and D2-cohort N, onboarding funnel, 168-hour activation, same-session logging diagnostics, eligible D2 app/logging return, photo/manual behavior, failures, and repeated feedback. Use those results to choose the next product or architecture task; do not add a larger feature solely because it was already on the roadmap.
