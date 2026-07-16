# Manual Meal Forms and Nutrition Calculation

## Purpose

This document records the product rules for the Flutter client's `Add Meal` and `Edit Meal` forms. The calculation and state logic lives on-device: `lib/meal_edit_draft.dart` contains the draft rules, and `lib/main.dart` owns the manual meal sheet UI.

## Add Meal status

**Status: production-ready for the closed beta.**

`Add Meal` is feature-frozen. Do not introduce new controls, new calculation models, or new interaction patterns to this form during the beta. Changes are limited to bug fixes that preserve the contracts below. Any product change requires an explicit post-beta decision backed by user feedback.

`Edit Meal` has a separate, legacy-compatible interaction model and is not covered by that feature freeze.

## Shared nutrition facts

The nutrition fields are `Weight`, `Protein`, `Fat`, `Carbs`, and `Calories`. Protein, fat, and carbs are shown in grams; calories are shown in kcal.

Calories use the standard formula:

```text
protein * 4 + fat * 9 + carbs * 4
```

`Weight` is always a physical, user-controlled value. It is never inferred from calories or macros. No flow may invent or auto-fill weight in grams.

## Add Meal

### Form and input behavior

- The form order is name, a 2x2 `Weight` / `Protein` / `Fat` / `Carbs` grid, `Calories`, then meal type.
- Unit context is inside the inputs (`g` for the four gram fields and `kcal` for calories); the labels do not repeat the unit.
- All nutrition inputs request a decimal numeric keyboard on mobile.
- A new meal starts with empty numeric controllers. Examples such as `e.g. 250` are placeholders, not values. They disappear after the first focus and never enter calculations or saved data.
- A typed `0` is a real value. New Add Meal input does not add a trailing `.0` automatically.
- The default meal type is derived from the current time rather than always being breakfast.
- Add Meal does not expose the old yellow locks, lock icons, reset action, or revert action.

### Calculated calories

- Calories remain unavailable until the user has entered all three macros: protein, fat, and carbs.
- Once all three are present, calories are calculated with the formula above, displayed as a calculated value, and labelled as such.
- `Weight` never affects that calculation.
- Selecting calculated calories opens a short explanation. The recommended primary action is `Keep calculated`; `Edit anyway` is secondary.
- `Edit anyway` makes only calories manually editable. It must not auto-adjust weight or any macro, either immediately or after later macro edits.
- `Use calculated calories` restores the macro formula while preserving the current weight and macro values.

This is intentionally a one-way Add Meal calculation model: macros may produce calories, but calories never produce grams or macros.

## Edit Meal

Editing an already saved meal deliberately preserves the existing values and uses the legacy session-scoped locking model. Existing numeric values are real values, not examples.

### Session-scoped locking

Each edit session begins when the sheet opens and ends when it closes.

- A manually edited field becomes locked for that session.
- A nutrition field may also be locked with a double tap before changing it.
- Locked fields receive a yellow outline and an unlock icon.
- Auto-calculation changes only unlocked values.
- Locks and manual intent reset when the sheet is closed and reopened; they are not persisted.

The state keeps both `lockedFields` and `manuallyEditedMacroFields`:

- `lockedFields` control the editor UI and which values auto-calculation may change.
- `manuallyEditedMacroFields` records explicit macro edits for the locked-calories confirmation flow.

Double-tap locking does not count as a manual macro edit by itself.

### Recalculation rules

When editing a saved meal:

- Changing `Weight` proportionally scales only unlocked calories and macros. Weight is never derived from another value.
- Changing protein, fat, or carbs locks that macro and recalculates calories when calories are not locked.
- Changing calories locks calories and proportionally rebalances only unlocked macros where a valid rebalance is possible.
- If valid rebalancing is impossible, the inconsistency remains visible instead of guessing.

### Locked-calories confirmation

The confirmation appears only when calories are locked, the values conflict, and at least one other macro can safely be auto-adjusted.

It offers:

- `Save as entered`, which saves the current values unchanged.
- `Auto-adjust & save`, which keeps calories and all manually fixed macros unchanged, and rebalances only the remaining allowed macros.

If calories and all macros are manually fixed, no confirmation is shown. The user is asked to unlock a macro or recalculate from macros instead.

### Edit-only actions

- `Recalculate from macros` clears edit-session locks and manual macro intent, calculates calories from the current macros, and leaves weight unchanged.
- `Revert changes` returns the sheet to the exact snapshot captured when that edit session opened, including name, meal type, nutrition values, and lock state.

Historical meal consistency uses a 15% calorie-vs-macro tolerance so small rounding differences do not force a recalculation.

## Debug tracking

There is no external analytics SDK. Debug builds use `_trackMealEditEvent` and `debugPrint` for the legacy edit flow. If production analytics is added, this helper is the intended replacement point.

## Test coverage

`test/widget_test.dart` covers, among other behavior:

- empty Add Meal placeholders and their focus behavior;
- decimal keyboard configuration and in-field units;
- Add Meal calculated calories, manual override, and restoration;
- no auto-derived weight or macros in Add Meal;
- time-based default meal type;
- legacy Edit Meal locks, recalculation, conflict handling, recalculation, and revert behavior;
- grouped-history edit save behavior.

## Refactor guidance

The current implementation is suitable for the present app size because it is private to one screen and covered by widget tests. Keep the separated Add Meal and Edit Meal contracts intact. Move the draft logic into a dedicated `lib/meal_edit/` folder only if more nutrition-editing surfaces are added or `lib/main.dart` becomes meaningfully hard to navigate.
