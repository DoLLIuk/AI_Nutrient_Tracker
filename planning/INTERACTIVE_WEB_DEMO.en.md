# Interactive web demo brief

Status: responsive site shell and Formspree feedback are implemented locally. AI demo access, curated photos, onboarding shortcut, analytics, and GitHub Pages deployment remain to be built.

## Purpose and scope

- Present the mobile nutrition app as a polished, interactive English-language project demo for recruiters, friends, and early testers.
- Keep the site focused on the live app, short text that helps visitors use it, and feedback. Video is a separate asset for posts, presentations, and GitHub; it does not appear on the demo site.
- Use the real photo-analysis backend. Any recorded AI response is a clearly labeled fallback for an outage or a closed demo, not the default experience.
- Publish a Flutter Web build automatically from the latest pushed commit on the chosen GitHub branch. Unpushed local changes are not published.

## Name and copy

- The chosen display name is **AI Nutrient Tracker**. Use it across the demo, browser metadata, app labels, and repository-facing copy. The Dart package and platform application IDs remain stable.
- This name describes the project but is not a claim of brand uniqueness. Perform a fuller name and domain check before public commercial use.
- Use concise, natural English throughout the demo, including loading, error, quota, empty, and success states.
- The first screen should explain the core loop in one sentence: set a goal, analyze a meal photo, and see daily progress.

## Demo journey

1. The visitor can complete the real onboarding flow. Only the basic-profile step (sex, age, height, weight) gets a one-click **Continue with a sample profile** option. The sample values must be visible and clearly labeled; the normal manual-entry path remains available. Goal, activity, pace, and macro preference are still selected by the visitor.
2. After onboarding, show 4-5 curated sample meal photos plus an **Upload your own photo** action. Both paths send the image to the real AI service. Mobile browser camera capture may be offered when supported; file upload remains the reliable path.
3. Curate samples that exercise a simple meal, a mixed dish, and a portion or clarification path. Use original or properly licensed images.
4. Show the AI estimate, confirmation/editing, saved meal, and updated dashboard/history. Keep the manual meal path available.
5. Provide a visible **Reset demo** action because onboarding and meal history persist locally in the browser.
6. Explain clearly that example-profile values are fictional and AI nutrition values are estimates. Show a helpful state when analysis fails or the demo quota is exhausted.

## Page layout and feedback

- Desktop: center the app at a phone-like width; keep a compact feedback form visible alongside it.
- Mobile: reserve a persistent site-level **Feedback** control outside the app's own controls. It opens a form and returns the visitor to the same app state when closed.
- Feedback is available throughout the journey, including during onboarding. No app-internal feedback feature is required.
- The form contains a required comment and an optional reply email. Attach only useful context such as demo version and current screen; do not attach photos, profile measurements, or meal details.
- The custom-styled site form submits to Formspree form ID `xoevlpvb`. A local test submission returned success; the owner should confirm that its notification arrived at the configured inbox. Formspree stores submissions in its dashboard and emails a notification to the project owner's configured address, which was supplied privately in conversation and must be set in the service rather than committed to the public repository. The Free plan currently allows 50 submissions per month and stores 30 days of history, so keep a copy of feedback that matters. The photo-analysis backend does not receive feedback. Keep spam filtering enabled.

## Hosting decision

- Use GitHub Pages for the first release. This public application repository can also host its project site: a GitHub Actions workflow builds Flutter Web and publishes only `build/web` on pushes to the release branch.
- GitHub Pages serves the static demo shell. The AI API remains on a separate protected backend, and feedback goes to Formspree. Free site hosting does not imply free AI inference or backend traffic.
- Rename the GitHub repository to `AI_Nutrient_Tracker` before enabling Pages. Configure the Flutter Web build with base path `/AI_Nutrient_Tracker/` for the default project-site URL. Update the local Git `origin` to the renamed repository URL.
- Cloudflare Pages is an alternative with Git-triggered builds and preview deployments. Firebase Hosting is an alternative that aligns with the existing Firebase and Google Cloud setup. Revisit hosting only if the initial Pages setup exposes a concrete limitation.

## Web-only API protection and measurement

- Give the web demo a separately scoped backend path/service and credentials. Never compile the current shared `X-API-Key` into the public web bundle; it also guards backend log endpoints.
- Add verified anonymous visitor identity/app attestation or an equivalent bot check, plus durable server-side per-visitor, per-IP, burst, and global cost quotas for demo photo requests. Do not rely on browser-side counters or CORS as an authorization mechanism.
- Keep the mobile client's current behavior outside the scope of this demo. A complete production authorization/quota design for mobile remains a later project.
- Enable Firebase Analytics for Web; the current app initializes the Firebase adapter only for Android and iOS. Track the existing onboarding and meal-flow events without photos or body measurements.
- Log demo API outcomes with time, anonymous visitor/session identifier, request ID, status, and quota result so feedback and failures can be investigated without collecting unnecessary contents.
- Show quota exhaustion as a normal product state, with manual logging still usable.

## Quality and release criteria

- All visible site and demo copy is polished English. Branding is consistent and no default Flutter metadata remains.
- The primary path is understandable without instructions from the author and can be tried quickly by a recruiter.
- Test desktop and mobile browsers, especially file upload, onboarding, feedback submission, local persistence/reset, AI errors, and quota behavior.
- The feedback form works from any app screen without losing app state.
- The published build corresponds to a pushed GitHub commit and shows a version/build identifier for support.
- Describe photo processing and analytics accurately in a short, accessible privacy note.

## Details to finalize before integration

- Confirm that the GitHub repository has been renamed to `AI_Nutrient_Tracker` and the remote is reachable.
- Verify Formspree notification delivery to the privately supplied email address and decide whether 30-day submission retention is sufficient.
- Initial demo request limits and total daily AI spend ceiling.
- Final deployment URL after GitHub Pages is enabled.
