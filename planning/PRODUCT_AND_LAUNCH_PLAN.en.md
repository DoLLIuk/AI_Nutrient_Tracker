# AI Calorie Tracker Product And Launch Plan

Updated: 2026-07-06

> Note: [docs/PRODUCT_QUALITY_ROADMAP.md](../docs/PRODUCT_QUALITY_ROADMAP.md) now defines the canonical stage order and quality gates through Public v1. This document remains useful for strategic and public-planning context; the master roadmap wins if they differ.

This document outlines a practical path from the current app to `Beta v1`, early users, and a public launch. The goal is not just to publish the app in the stores. The goal is to prepare the product, audience, feedback loop, and project story before launch.

## 1. Strategy

Near-term goal: `Beta v1`.

`Beta v1` is not the final perfect product. It is a stable version that can be tested by real users to validate the core loop:

`complete onboarding -> log a meal -> see daily progress -> understand the next step -> return later`

Priorities:

- prove that the core loop is useful;
- recruit real early users and collect feedback;
- measure retention and key flow completion;
- avoid rushing into sponsorships, paywalls, or a large public campaign before there is evidence of user interest.

The project should not start with sponsor outreach. Sponsors and partners are easier to convince when there is already a demo, beta users, screenshots, a short video, and early usage signals.

## 2. Product Roadmap

### Pre-Beta

Goal: make the product usable by people other than the creator.

Work to complete:

- stabilize onboarding, home dashboard, photo flow, manual add/edit, and session history;
- confirm local data survives normal app restarts;
- make fallback paths clear when AI photo analysis fails;
- remove or soften UI that looks like real analytics but is currently only demonstrational;
- prepare a production-style `API_BASE_URL` / `API_KEY` workflow that avoids manual confusion;
- add basic event analytics;
- prepare a privacy policy and a clear medical disclaimer.

Minimum analytics events:

- `onboarding_completed`
- `first_meal_logged`
- `meal_logged_photo`
- `meal_logged_manual`
- `photo_analyze_success`
- `photo_analyze_fail`
- `manual_fallback_used`
- `meal_edited`
- `day_2_returned`
- `day_7_returned`

### Beta v1

Goal: give the app to 30-100 users and learn whether they come back.

Readiness criteria:

- a new user can complete onboarding without explanation;
- the first meal can be logged quickly;
- photo-analysis errors do not destroy trust because manual fallback is obvious;
- users understand how many calories and macros they have consumed and how much remains;
- users have a quick way to send feedback.

Metrics to watch:

- onboarding completion rate;
- first meal logged rate;
- meals logged per active day;
- photo flow completion rate;
- manual fallback rate;
- day-2 retention;
- day-7 retention;
- qualitative feedback: what was unclear, where users dropped, and what felt missing.

### Public v1

Goal: launch publicly after the beta version survives real usage.

The exact scope, including account restore and Premium subscriptions, is defined in the master roadmap and is intentionally not duplicated here.

Before launch:

- prepare store screenshots and a short demo video;
- create a landing/project page;
- define the product in one sentence;
- prepare FAQ content about AI accuracy, privacy, medical disclaimer, and manual input;
- verify crash/error monitoring;
- prepare App Store / Google Play metadata;
- prepare launch posts for different channels.

Product sentence:

`AI Calorie Tracker helps you log meals faster with photo analysis, manual fallback, and a clear daily calorie and macro summary.`

### Post-v1

Goal: expand only after the core loop shows real engagement.

Possible directions:

- personalized AI nutrition coach;
- integrations with Apple Health, Android Health Connect, Fitbit/Google Health, or other activity sources;
- push reminders;
- live multi-device sync;
- stronger local database.

Important: monetization and AI coaching should not be used to rescue a weak core loop. They should strengthen a food diary that is already useful.

## 3. Launch Roadmap

### Step 1: Manual testers

Goal: 10-20 people.

Where to find them:

- friends and acquaintances who track calories or go to the gym;
- school or local chats;
- fitness communities;
- people who have tried MyFitnessPal, Yazio, Lifesum, Cronometer, or similar apps.

What to give testers:

- a short explanation: "This is an app for fast meal logging by photo or manual input";
- a build link;
- a request to log at least 2-3 meals in one day;
- 3 follow-up questions:
  - what was unclear?
  - what felt faster or easier than a normal tracker?
  - would you return tomorrow?

### Step 2: Closed beta

Goal: 30-100 users.

Channels:

- Apple TestFlight: https://developer.apple.com/testflight/
- Google Play testing tracks: https://support.google.com/googleplay/android-developer/answer/9845334

Focus:

- stability;
- onboarding;
- first meal logging;
- AI photo flow;
- manual fallback;
- Home screen feedback.

Do not add too many new features at this stage. Improving the main path is more valuable than widening the product.

### Step 3: Landing/project page

Goal: give the project a clear public home.

The page should include:

- product name;
- short promise;
- 4-6 screenshots;
- 20-40 second demo video or GIF;
- core feature list;
- beta / waitlist / feedback form link;
- privacy/disclaimer links;
- GitHub link if it helps trust.

This should not be a heavy marketing landing page. For this project, a clear product page is better: what the app does, who it is for, and what already works.

### Step 4: Public launch

Goal: create several waves of attention instead of silently uploading the app to the stores.

Waves:

- launch day: GitHub README update, landing page, short video;
- first week: personal social posts, fitness/weight-loss communities, indie maker communities;
- after first feedback: Product Hunt or a similar launch platform;
- after improvements: "what changed after beta feedback" content.

Product Hunt reference: https://www.producthunt.com/launch

Use Reddit carefully. Do not join communities only to drop links. Participate first, answer questions, be honest, and clearly disclose that it is your own project. Reference: https://www.reddit.com/r/reddit.com/wiki/selfpromotion/

## 4. Attention Strategy

Main angle:

`A simple AI calorie tracker focused on fast meal logging, clear daily progress, and manual fallback when AI is uncertain.`

Content to prepare:

- short demo video: onboarding -> photo meal -> confirmation -> day summary;
- before/after: manual meal logging vs photo logging;
- thread/post: "What I learned building an AI calorie tracker";
- UX post: why AI should clarify and ask for confirmation when uncertain;
- screenshots for README and store pages;
- small changelog after each beta iteration.

Channels:

- GitHub;
- X / Threads / LinkedIn if there is an audience there;
- Reddit, with respect for community rules;
- Product Hunt when the demo is ready;
- local fitness / gym / weight-loss groups;
- personal network and school chats.

## 5. Sponsors And Partners

Do not pursue sponsors before beta. Early users matter more.

Good timing:

- 50-100 beta users;
- a clear demo video;
- 3-5 strong testimonials;
- evidence that people log more than one meal;
- early retention numbers.

Who to contact:

- local fitness trainers;
- small gyms;
- nutrition coaches;
- student wellness communities;
- creators who talk about nutrition and fitness.

What to offer:

- not "fund an idea";
- instead: "here is a working beta product, your audience can get early access";
- a shared feedback cohort;
- a public case study;
- partner promo code later if premium exists.

## 6. Summer Work Plan

### Week 1

- run the full core flow on a real device;
- record a demo video;
- write down bugs and UX friction;
- choose 10 manual testers.

### Week 2

- fix the top 5 issues from self-testing;
- prepare a feedback form;
- give the build to first testers;
- record user phrases, not just bugs.

### Week 3

- improve onboarding and first meal flow based on feedback;
- add or verify basic analytics;
- prepare screenshots and a short product description.

### Week 4

- start closed beta;
- recruit 30+ users;
- watch first meal logged rate and day-2 retention;
- avoid major new features until the main path is reliable.

### After Month 1

- decide whether to continue beta, prepare public v1, or return to core UX;
- if the core loop works, prepare the landing page and public launch;
- if retention is weak, investigate logging speed, AI trust, and Home screen clarity.

## 7. Decisions To Delay

Do not decide too early:

- exact subscription price;
- complex paywall strategy;
- full AI coach;
- live multi-device sync;
- multiple health platform integrations at once;
- partnerships before beta.

These decisions will be better after real users.

## 8. References

- Apple TestFlight: https://developer.apple.com/testflight/
- Google Play testing: https://support.google.com/googleplay/android-developer/answer/9845334
- Product Hunt Launch Guide: https://www.producthunt.com/launch
- Reddit self-promotion guide: https://www.reddit.com/r/reddit.com/wiki/selfpromotion/
