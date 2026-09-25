# Web demo API gateway

The GitHub Pages build uses `DEMO_API_BASE_URL` to call this Cloud Run service. The mobile `PHOTO_FOOD_API_KEY` stays in Secret Manager and is never placed in the public web bundle. The gateway forwards only photo analysis and portion confirmation.

Firestore transactions reserve a request before it reaches the AI API. Current UTC daily limits are 3 analyses and 9 confirmations per browser ID, with shared caps of 50 analyses and 150 confirmations. Clearing browser storage can reset the browser limit, but cannot bypass the shared cap. `demo_events` records the UTC time, action, pseudonymous visitor hash, and trace ID for admitted calls. Photos and profile data are not logged. Rejected calls appear in Cloud Run logs without a Firestore event to avoid unlimited write costs.

## Deployment prerequisites

- The Google Cloud project and region hosting the private photo API.
- A Firestore Native mode `(default)` database. The gateway service account needs `roles/datastore.user`.
- Secret Manager secrets for `PHOTO_FOOD_API_KEY` and a random `DEMO_HASH_SALT`. The service account needs `roles/secretmanager.secretAccessor` on both.
- Cloud Run, Cloud Build, Artifact Registry, Firestore, and Secret Manager APIs enabled.

Deploy this folder with a dedicated service account and production origin:

```sh
gcloud run deploy ai-nutrient-demo-gateway \
  --project PROJECT_ID \
  --region REGION \
  --source demo_gateway \
  --service-account SERVICE_ACCOUNT_EMAIL \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars DEMO_ALLOWED_ORIGINS=https://dolliuk.github.io,PHOTO_FOOD_API_BASE_URL=https://PRIVATE_API_HOST \
  --set-secrets PHOTO_FOOD_API_KEY=PHOTO_FOOD_API_KEY:VERSION,DEMO_HASH_SALT=DEMO_HASH_SALT:VERSION
```

Set repository variable `DEMO_API_BASE_URL` to the deployed gateway HTTPS URL. Set `WEB_DEMO_READY=true` only after verifying a real image analysis, daily limits, feedback delivery, and the complete browser flow. In repository Settings → Pages, select **GitHub Actions** as the publishing source. Every later push to `main` will run tests and deploy the current commit automatically.

Cloud Run and Firestore can still incur charges from unwanted traffic. The shared transaction cap bounds calls to the private AI service; Cloud Run max instances limits concurrent compute. Review Google Cloud budgets and billing alerts before advertising the demo publicly.
