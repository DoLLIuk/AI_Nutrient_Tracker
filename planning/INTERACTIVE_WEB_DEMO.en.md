# Interactive web demo

Status: published on GitHub Pages. Updated 2026-09-26.

Live site: https://dolliuk.github.io/AI_Nutrient_Tracker/

The implementation and operating reference is [docs/WEB_DEMO.md](../docs/WEB_DEMO.md). This brief records the product boundaries and remaining gaps.

## Implemented experience

- Consistent **AI Nutrient Tracker** branding and English copy.
- A live Flutter app, brief usage guidance, and feedback only. Video remains a separate asset for posts, presentations, and GitHub.
- A clearly labeled sample profile on the basic-profile onboarding step; the rest of onboarding remains interactive.
- Five generated sample meal photos and upload of the visitor's own photo, both using the real AI backend.
- Manual logging, editing, portion confirmation, daily totals, and browser-local persistence.
- Desktop: app and feedback side by side with a three-step guide. Left heading aligns with the app frame; content spacing below the header is 24 px. Mobile layout keeps its existing spacing and persistent feedback button.
- Feedback posts directly to Formspree `xoevlpvb`; message required, reply email optional. No photos or profile data are attached. Recipient routing and service-plan limits belong to Formspree settings, not this repository.
- GitHub Actions builds and publishes pushed `main` commits with base href `/AI_Nutrient_Tracker/`.

## Implemented protection and measurement

- The public web build contains no AI API key. Cloud Run gateway reads the key from Secret Manager.
- Firestore enforces UTC daily browser/shared caps: 3/50 analyses, 9/150 confirmations, and 60/1200 app events.
- Browser identity is a random local ID, hashed on the server. It is not authenticated or attested. Clearing site storage can reset the browser allowance, but not the shared cap.
- Web events use a custom gateway/Firestore adapter, not Firebase Analytics Web. Only event name and optional onboarding step are sent; the gateway adds operational metadata.
- CORS is restricted to the production Pages origin. It is not an authorization or bot-defense mechanism.
- Gateway deployment remains separate from automatic site deployment.

## Remaining gaps and limits

- Owner confirmation of Formspree email delivery is still outstanding.
- No per-IP quota, dedicated burst limiter, bot attestation, or monetary spend cap was added. Global AI request caps do not eliminate Cloud Run/Firestore traffic costs.
- No custom analytics dashboard, automatic event retention, or visitor identity lookup is implemented.
- A dedicated site-level reset control, visible build identifier, and prerecorded-response fallback were proposed in the original brief but are not implemented. They are not current product guarantees.
- The web demo does not close the mobile beta's device testing, privacy, monitoring, or distribution gates.

See the runbook for deployment, local preview, Firestore collections, quota changes, and troubleshooting. Preserve the existing mobile experience when changing desktop layout.
