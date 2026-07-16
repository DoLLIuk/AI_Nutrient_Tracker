# Proactive AI Nutrition Coach

Status: decided Premium product vision. Shipping is a separate stage after Public v1; it is not Beta v1 or Public v1 scope.

Last updated: 2026-07-11

> [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md) defines the release order. This document is the canonical product specification for the first post-Public-v1 Premium Coach stage.

## 1. Product role

The Coach is a proactive nutrition agent. It adapts to the user's explicitly provided routine and food history, then initiates a useful contact before a meal instead of waiting for the user to open the app and ask.

It is a nutrition companion, not a general lifestyle chatbot, workout tracker, medical advisor, clinician replacement, or a dependency of the food-logging core loop.

## 2. Reference scenario

1. In future Coach settings, the user explicitly enters an approximate wake time and preferred meal times; they can edit these later.
2. About 20 minutes before a scheduled meal, the Coach sends an opt-in push notification.
3. The notification uses recent nutrition patterns and, when sufficient history exists, a concrete recipe/food recommendation with a portion and nutrition values from the verified recipe/food base.

Reference tone and format:

> "Привет! За последние дни тебе не хватало белка. Для продуктивной пятницы подойдёт завтрак: 4 сырника и [...]. Это даст хороший старт дня и заряд энергии до следующего приёма пищи."

The message is warm, motivating, concrete, and never shaming. It recommends a specific meal/portion rather than a vague instruction such as "eat more protein".

## 3. Locked product decisions

### Deficit analysis

- Use a rolling average across the previous 3 days, not a single-day deficit.
- This reduces false or judgmental reactions to normal one-day variation.

### Dish and nutrition source

- A verified recipe/food base selects the dish and supplies nutrition values and portions.
- The LLM may formulate the message tone and phrasing only. It must not invent meals, portions, calories, or macro values.

### Schedule source

- Meal timing comes from explicit manual user input in future Coach settings.
- The user can edit the schedule at any time.
- Learned behavioural schedules are outside this version of the Coach.

### Notification timing and delivery

- Target the notification for roughly 20 minutes before the configured meal time.
- Delivery within a soft ±30–40 minute window is acceptable; exact real-time delivery is not required.
- Push notifications require separate opt-in, quiet hours, and a clear one-tap disable path.

### Cold start

- During the first 3–7 days, before enough history exists, send only a general nutrition nudge without a specific recipe or dish.
- Example: a general suggestion to add protein today, without pretending to have personalised meal evidence.

### Medical boundary

- Use behavioural nutrition nudges such as "a good start to the day" and "energy until the next meal".
- Do not make medical, diagnostic, treatment, guaranteed weight-loss, or disease-prevention claims.
- Implementation must be reviewed against the product disclaimer and safety/copy rules; this document does not override them.

## 4. Open technical dependency: recipe/food base

The Coach requires a new verified recipe/food base before it can issue personalised dish recommendations with reliable portions and nutrition values.

The provider, licensing, API, data model, data-quality process, and update ownership are intentionally unresolved technical decisions. Do not select a vendor or implement an integration as part of this vision. Until this dependency is resolved, the Coach can use only the cold-start general-nudge behaviour, not personalised recipe recommendations.

## 5. Scope and sequence

- Beta v1 validates the existing loop: `onboarding → log meals → understand progress → return`.
- Beta v1 does not add a schedule onboarding question, fake-door demand test, Coach notification, recipe-base integration, or Coach logic.
- After beta, product and technical scoping may begin, but user-facing Coach shipping remains a separate Premium stage after Public v1.
- Public v1 still excludes the Coach, user meal schedule, proactive notifications, and the push-notification system.

Reactive chat (`Today + Ask`) is not an approved Coach capability in this vision. It requires a separate product decision and does not follow automatically from proactive notifications.

## 6. Trust, control, and quality gate

- The user understands which routine and nutrition context informed a notification.
- Every notification has a respectful tone, an opt-out path, and no hidden use of health data.
- The user can edit schedule, quiet hours, and notification preferences without losing access to manual logging or the diary.
- Before shipping, validate consent, delivery reliability, recipe-base quality, generated-copy safety, dismiss/disable behaviour, and any recurring safety incidents.
- Evaluate usefulness through notification open/dismiss/disable behaviour, meal logging, eligible D2 return, nutrition-target completion, and qualitative feedback—not message volume alone.
