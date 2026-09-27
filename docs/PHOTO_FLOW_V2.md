# Photo Flow: whole plate and recoverable scans

Decision: 2026-09-26. One photo logs all edible food on the primary plate/bowl,
including sides. Drinks and separate background plates are excluded. Keep
specific names where supported; generalize only uncertain ingredients.

## Implemented behavior

- Capture diary date/time before picking the photo; preserve it through retries.
- Save a local pending operation before upload. Native apps use a flushed,
  atomically replaced metadata file and a separate photo file in application
  support storage, avoiding repeated base64 encoding on mobile. Web uses local
  preferences and fails before upload if browser storage cannot hold the photo.
- Verify backend v2 recovery capability before a paid upload; reuse the same
  random Idempotency-Key on recovery. One pending operation at a time.
- Store the response before updating the diary; remove the photo from the
  journal as soon as the result is saved. Remove the journal only after the
  diary persistence acknowledges it. Replays preserve existing user edits.
- A checked weight is distinct from model recognition confidence. The small
  check icon beside Weight lets the user mark it checked; changing weight also
  checks it when saved. Saving a rename alone does not. Legacy AI entries are
  conservatively unreviewed; manual entries are reviewed.
- Weight means all edible food including sides, excluding plate/container.
- Successful results are logged even when the portion sheet is dismissed.
- Unfinished scans can be checked again or explicitly discarded. Dismissing
  an error does not erase the saved scan. Force-closing does not guarantee
  continued mobile execution: recovery runs when the app is opened again.

## Backend rollout dependency

Do not release the new client against the old backend. `/v0/health` must expose
`photo_flow_version: 2` and `durable_operations: true`. Cloud Run needs a shared
Firestore operation journal with service-account access. SQLite is local only.
Production backend and gateway were deployed on 2026-09-27. The backend serves
revision `photo-food-api-00014-kuf`; the gateway serves
`ai-nutrient-demo-gateway-00003-qaw`. Both expose the v2 durable-operation
capability. Client source publication is a separate step.
The web demo gateway also needs its matching update to forward capabilities and
Idempotency-Key. Its existing daily request quotas remain in force, including
recovery requests; hitting the cap delays web recovery until quota is available.

A server crash after provider admission can leave an uncertain operation.
The same key never starts another paid analysis. The user can check for a late
result or explicitly discard and start a new scan. This is not a background job
queue and does not claim exactly-once provider billing after arbitrary crashes.

## Deferred by product decision: clarify composition

**Not implemented; reconsider only after the pilot.** An optional action could
let a user say "this is chicken, not pork" or "I left the fries" and recompute
the existing entry. Changing the whole plate's grams only scales its existing
composition; changing a label alone does not re-estimate nutrition. A future
flow would need component-aware calculation, explicit update of the same entry,
and safeguards against duplicate analysis/logging. Do not add a mandatory
ingredient editor or a composition clarification screen now.

## Verification

Controller/native-store and widget tests cover storage-before-upload, restart,
same-key recovery, concurrent retry, stable original date, journal/diary crash
windows, and preservation of user edits. Device lifecycle/background behavior
still require device testing. Deployed Firestore permissions, stored-result
replay, conflicting-key rejection and portion confirmation passed a production
smoke test on 2026-09-27 without calling the vision model.

## Lifecycle amendment, 2026-09-27

- Save capture context before opening camera/gallery and the photo before showing
  clarification. Recover interrupted Android capture with `retrieveLostData()`
  when the capture marker exists. Restore as a draft with Continue/Discard, without
  automatic upload or a modal interrupting launch.
- Save weight-confirmation intent (grams/mode and expected meal revision) before
  HTTP. Restart retries confirmation only, never photo analysis. Keep the intent
  until the resulting diary state is saved.
- Manual edits and accepted confirmations advance a revision. Late confirmation
  applies only to its original revision. Save deletion markers before diary
  acknowledgement, so replay cannot resurrect deleted meals.
- Recovery starts after home's first frame: no new bootstrap await, polling loop,
  artificial delay or photo recompression. Slow recovery allows navigation/manual
  logging. A thin progress bar replaces the full-screen loading overlay. Only a
  second photo operation waits for the current scan to be resolved.
- Tests hold storage/network futures open to verify interactivity and races,
  including restart after deletion. Native journal tests keep a 1 MiB photo out
  of small JSON updates. These checks do not replace release-mode startup/frame
  measurements on actual Android/iOS devices.

Future linked entries and deferred crop/consumption rules:
[PHOTO_FLOW_FUTURE_COMPONENTS.md](PHOTO_FLOW_FUTURE_COMPONENTS.md).
