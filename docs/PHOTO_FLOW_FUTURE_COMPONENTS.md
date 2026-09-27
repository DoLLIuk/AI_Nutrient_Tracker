# Future Photo Flow: linked component entries

Product decision: 2026-09-27. **Planned for a future release after product traction
and real-user feedback. Not implemented or required for the current pilot.**

## Intended experience

One photo of one plate can produce multiple linked diary entries when it contains
clearly separate foods. A cheeseburger and fries become two entries with independent
names, weights, calories, protein, fat and carbohydrates. They belong to the same
photographed meal and remain visually grouped.

If the user finishes the burger but eats half the fries, changing the fries portion
must leave the burger unchanged. The group total is the sum of the component totals.
Never also log an aggregate plate entry: that would double count.

This is not a mandatory ingredient editor. Do not split a burger into bun/meat/cheese
or decompose an inseparable stew merely because several ingredients are recognized.
Prefer one entry when foods cannot be separated reliably. Validate the precise
separation rules and UI with real mobile photos before making them default.

## Contract and persistence to design together

- Versioned JSON response with a component array. Each component needs a stable ID,
  name, estimated edible grams, nutrition per 100 g and totals.
- A scan/group ID links entries to one analysis. Keep it separate from the existing
  meal-session grouping, which may contain several scans.
- Preserve common capture date/time and operation identity. A photo reference does
  not imply permanent retention or additional uploads of the image.
- Save a component group atomically; deduplicate by group + component ID on replay.
  Recovery must never create half a group or duplicate its components.
- Each component owns its weight-review status, edit revision and deletion state.
  A late response must not undo edits or resurrect a removed component.
- Recompute the group from current components. Specify removal of one component
  versus the whole group, with no double-counting in diary summaries.
- Keep existing single-entry meals compatible. Do not infer components from an old
  name or arbitrarily split its calories during migration.

## Future acceptance examples

1. Burger + fries: two linked entries; their sum equals group totals, no plate row.
2. Halve fries grams: fries macros halve; burger grams/macros stay unchanged.
3. Edit/delete a component and replay an old response: newer user action wins.
4. Crash during persistence: restart yields the complete group exactly once.
5. Mixed soup/stew or ambiguous separation: a coherent single entry.
6. Background drinks/plates stay excluded; components do not widen photo scope.

Measure omitted/double-counted foods, separation quality, portion errors and the
additional user effort alongside nutrition accuracy.

## Other deferred decisions (2026-09-27)

**Cropped photos:** distinguish cropped plate rims with all food visible, food
extending beyond the frame, and ordinary overlap. A precise retake/warning rule
remains deferred; no new prompt or UI rule is introduced now. Do not claim the
pilot's crop behavior has been newly standardized.

**Food served versus eaten:** current estimates describe the photographed serving.
Reducing whole-plate grams scales every component proportionally and cannot model
eating a full burger while leaving fries. Shared plates have the same scope issue.
New copy, consumption controls and component editing are deferred. This limitation
is accepted for the current version.
