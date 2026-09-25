# AI Nutrient Tracker — Discovery, Beta, and Launch Plan

Updated: 2026-09-08

> [PRODUCT_QUALITY_ROADMAP.md](../docs/PRODUCT_QUALITY_ROADMAP.md) owns the release-stage order and quality gates. [BETA_V1_CHECKLIST.md](../docs/BETA_V1_CHECKLIST.md) owns the 14-day closed-beta protocol. This document defines how to find evidence of demand and suitable participants before broader beta distribution.

## Current decision

AI calorie tracking is a crowded category. Fast photo logging, manual fallback, and a clear daily summary are valuable product foundations, but not yet a compelling reason for a stranger to replace an established tracker for a week. Do not optimise for downloads yet.

Validate this hypothesis instead:

`people who want to track calories but repeatedly fall out of the habit because of friction and routine will return when fast logging is paired with timely, non-judgmental proactive help`.

This is a research hypothesis, not an existing feature promise.

## Validation sequence

| Stage | Participants | Question |
| --- | ---: | --- |
| Problem discovery | 8–10 target users | Which recurring problem is painful enough, for whom? |
| Usability and concierge test | 5–10 users | Is the current flow understandable, and is proactive help useful when delivered manually? |
| Closed Beta v1 | 20–50 target testers | Do people return to the real app’s core loop? |

Never treat paid usability participants or random beta-directory installs as evidence of organic retention.

## 1. Problem discovery

Recruit people who used a calorie tracker for at least a week in the last six months, actively use or recently abandoned one, and can describe a real occasion when they stopped logging. Recruit through small coaches, creators, fitness communities, direct outreach, or paid research panels.

Use this 25-minute interview script before showing the app:

1. Tell me about the last time you tried calorie tracking. What was your goal?
2. How did you log food? What was slow or frustrating?
3. Tell me about the last meal you did not log. What happened?
4. Why did you pause or abandon the diary?
5. What tools have you tried, and what still works well in them?
6. When would help be most useful: before a meal, after a missed log, in the evening, or elsewhere?
7. What notification would help you return, and what would feel intrusive?
8. If you could change one thing about tracking, what would it be?
9. Then show the demo: what solves a real problem, and what does not?

Record direct wording, context, workaround, drop-off trigger, desired help, and willingness to test. Do not collect health diagnoses, body measurements, meal photos, or detailed diet data unless specifically necessary and consented to.

Advance only when an independently repeated scenario emerges and several people will try a concrete solution for a week.

## 2. Concierge test for proactive help

Before building automation, test the behaviour manually with five consenting participants for seven days. Send at most one optional, respectful check-in per day; participants can stop messages immediately. Use voluntary updates or screenshots rather than accessing private meal data without explicit consent.

Examples:

- “Your diary is still empty today. If you want to return, you do not need to reconstruct the day—logging the last meal is enough.”
- “You mentioned evenings are hardest. Want to capture dinner by photo right after eating?”
- “What is getting in the way this week: time, photo accuracy, or something else?”

Measure response, perceived usefulness, a subsequent meal log, annoyance/disable requests, and whether users would keep the help enabled. Automate only one behaviour that helped manually; stopping the direction is also a valid result.

## 3. Usability and closed beta

Run 5–10 usability sessions for onboarding, photo/manual logging, uncertainty fallback, daily-progress comprehension, and feedback reporting. [User Interviews](https://www.userinterviews.com/usability-tests) and [Respondent](https://www.respondent.io/) can recruit paid research participants when personal contacts are unavailable.

After discovery and usability, recruit the approved 20–50-person, 14-day Beta v1 cohort. Its protocol and metrics must stay aligned with [BETA_V1_CHECKLIST.md](../docs/BETA_V1_CHECKLIST.md). The preferred source is a small audience with existing trust—a trainer, nutrition coach, fitness creator, gym, or wellness community.

Suggested invitation:

> I am looking for 5–10 people who currently try to keep a food diary but sometimes abandon it because of routine. This is a free 14-day test: log at least three meals across two sessions and tell me honestly what gets in the way. It is not medical advice and not a subscription sale.

TestFlight and Google Play Closed Testing distribute builds; they do not recruit motivated users. [TestFlight external testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) and [Google Play Closed Testing](https://play.google.com/console/about/closed-testing/) are the distribution infrastructure.

## Channel decisions

| Channel | Role now | Decision |
| --- | --- | --- |
| Coaches, micro-creators, small fitness communities | Targeted cohorts | First priority |
| Paid research panels | Interviews and usability | Use in a limited, explicit research budget |
| Simple landing page / waitlist | Test messaging and collect interest | Build before broad launch |
| TestFlight / Google Play closed tracks | Build distribution | Required beta infrastructure |
| Tester directories | Compatibility or isolated feedback | Never use for retention conclusions |
| itch.io | Technically supports software but is game-focused | Not an acquisition channel |
| BetaList / Product Hunt | Broad discovery after a proven offer | Postpone |
| Large weight-loss subreddits | Rules commonly prohibit promotion | Do not recruit directly without moderator permission |

BetaList requires a proprietary-domain website, paid submission, and editorial acceptance; [its terms](https://betalist.com/terms/submissions) make it a later launch option, not validation. itch.io describes itself as an independent-game-focused marketplace despite supporting software. [About itch.io](https://itch.io/docs/general/about).

## Next 30 days

| Week | Action | Output |
| --- | --- | --- |
| 1 | Recruit and conduct 4–5 interviews | Problem map and direct quotes |
| 2 | Complete 4–5 more; choose one segment and scenario | Cohort offer and landing-page copy |
| 3 | Run a 7-day concierge test with five people plus 3–5 usability sessions | Evidence for or against proactive help |
| 4 | Fix the largest UX issues and make one next-step decision | Decision memo: automate one behaviour, test photo speed, or return to discovery |

## Related documents

- [BETA_V1_CHECKLIST.md](../docs/BETA_V1_CHECKLIST.md) — beta gates and metrics.
- [ANALYTICS.md](../docs/ANALYTICS.md) — current analytics event contract.
- [AI_NUTRITION_COACH.md](../docs/AI_NUTRITION_COACH.md) — future Coach hypothesis and safety boundary.
