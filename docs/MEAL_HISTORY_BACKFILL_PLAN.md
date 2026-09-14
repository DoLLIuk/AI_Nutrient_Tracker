# Meal History: Delayed Logging And Category Moves

Status: implementation complete; optional meal-time picker deferred.

Last updated: 2026-07-16

## Goal

Let a user add or move a meal to Breakfast, Lunch, Dinner, or Snacks after the fact without corrupting time-based sessions or moving neighbouring meals.

Example: at 14:00 a user adds breakfast manually. The entry belongs at the end of Breakfast without a visible time; it must not become part of a 14:00 Lunch session.

## Product Decision

History distinguishes a **timed** meal from a **category-only** meal.

- A timed meal has a known eating time and participates in the existing 15-minute session grouping.
- A category-only meal has an explicit category but no displayed eating time. It never participates in a time session and is rendered at the end of that category.
- Daily calories and macros include both kinds of meal identically.

For the first implementation, a newly added or edited meal becomes category-only when its explicitly selected category differs from the category inferred from its recorded meal time. Returning it to the inferred category restores normal timed behaviour. This gives a clear, reversible rule without adding another control to the edit sheet.

## Required Data Model

Do not overload one timestamp with two meanings. Preserve these values separately:

| Field | Purpose |
| --- | --- |
| `loggedAt` | Immutable technical time when the record was created. |
| `consumedAt` | Known local eating time for a timed meal; may be absent for a category-only meal. |
| `userSelectedType` | Explicit Breakfast / Lunch / Dinner / Snack choice, when the user makes one. |
| `historyMode` | `timed` or `categoryOnly`; controls grouping and time visibility. |
| `categoryPlacedAt` | Time of the latest move into a category-only bucket; used only to append those meals deterministically. |

Migration rule: existing saved meals retain their current timestamp as both `loggedAt` and the legacy `consumedAt` value. Records with a legacy explicit category that conflicts with their timestamp migrate to `categoryOnly` so their prior category intent is preserved; every other legacy record starts in `timed` mode.

## History And Session Rules

1. Split entries into `timed` and `categoryOnly` before building sessions.
2. Build the current rolling 15-minute sessions from timed entries only.
3. Keep the existing chronological rendering, session headers, and per-item time for timed entries.
4. Render category-only entries after all timed sessions in their selected category, sorted by `categoryPlacedAt`; omit both the session range and the individual time.
5. A category-only entry must not change another entry's type, session total, session tier, or placement.
6. Category progress totals still include every entry assigned to that category.

The current "last override wins for the whole 15-minute bucket" behaviour must be removed for category-only entries. It is the root cause of a later Breakfast edit moving nearby Lunch items into Breakfast.

## Editing An Existing Saved Meal

When the user changes only the category:

- preserve nutrition values, source, AI confidence, photo data, `loggedAt`, and the diary date;
- remove only that meal from its previous timed session and rebuild the remaining session normally;
- put only that meal at the end of the newly selected category without a time when the selected category conflicts with its known time;
- set `categoryPlacedAt` at the confirmed save, not while the edit form is open;
- cancel leaves the saved record and all sessions untouched;
- changing back to the category inferred from `consumedAt` restores timed rendering and allows normal session grouping again.

Moving a meal does not re-run AI analysis, alter calories/macros, or silently change the diary date.

## Edge Cases And Expected Behaviour

| Situation | Expected result |
| --- | --- |
| At 14:00, add Breakfast manually | Entry is last in Breakfast, has no time, and does not join Lunch. |
| Edit a saved 13:34 Lunch to Breakfast | Only that meal moves; other 13:34 Lunch items stay in Lunch. |
| Several late Breakfast entries | They stay at the end of Breakfast in order of confirmed placement. |
| Move a category-only meal back to its time-derived category | Its normal time reappears and it can join the appropriate session. |
| Edit a meal but press close/cancel | No placement, session, or nutrition change is persisted. |
| Delete a category-only meal | Remove it from its category and recalculate totals; no other session moves. |
| Add to a previously selected past diary day | Keep that selected diary date; `loggedAt` remains technical metadata and does not create a session for today. |
| Add near midnight | Diary date is explicit and uses the device's local timezone; never move the record to another day solely because of grouping. |
| Restart after a move | `historyMode`, category, deterministic placement order, and totals restore unchanged. |
| Photo meal is edited into another category | Treat the category change exactly like a manual meal; retain the AI result as record provenance. |

The Latest Added card should show the selected category and kcal for a category-only meal, but omit the eating time. It can use the existing "Latest added" label to communicate recency without inventing a meal time.

## Later: Optional "When did you eat?" Field

This is intentionally deferred from the first category-only implementation.

- Add an optional date-and-time picker in Add Meal and Edit Meal.
- Providing a time changes `historyMode` to `timed` and places the record into the matching time session.
- If the selected time implies a different category, ask the user to choose: use the time-derived category, keep the selected category without time, or choose another time. Never silently change a category.
- Changing the date moves the meal's day totals and history entry together; changing only time keeps the selected diary day.
- Validate local midnight, timezone changes, and daylight-saving transitions.

## Completion Evidence And Remaining Validation

Implemented and covered by automated tests:

- [x] Timed/category-only splitting, deterministic category placement, persistence, and legacy-record migration.
- [x] Manual backfill into a different category without a visible eating time.
- [x] Moving one saved meal without moving neighbouring timed meals.

Still required before external beta invitations (tracked by the beta release checklist rather than as unfinished feature work):

- [ ] Manual Android and iOS smoke tests, including a past diary day, midnight, and a meal edited beside another timed meal.

## Scope Boundary

This plan changes history semantics only. It does not add recurring meals, meal planning, cloud sync, a full meal-time schedule, or nutrition-coach logic.
