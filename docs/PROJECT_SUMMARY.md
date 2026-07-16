# AI Calorie Tracker — Project Summary

Статус на 2026-07-11: Flutter-приложение с работающим core food-logging loop находится на этапе internal alpha перед закрытой Beta v1. Документ предназначен для быстрого handoff: его должно быть достаточно, чтобы понять продукт, текущую реализацию, принятые решения и следующий приоритет без чтения всей истории проекта.

## 1. Что это за продукт

AI Calorie Tracker — mobile nutrition diary для iOS и Android. Пользователь фотографирует еду или добавляет её вручную, получает калории и БЖУ, видит прогресс дня и историю приёмов пищи.

Главная ценность:

`быстро залогировать еду → понять дневной прогресс → вернуться к привычке на следующий день`.

Продукт не является медицинским сервисом и не должен обещать похудение, диагноз или лечение.

## 2. Текущий пользовательский опыт

### Onboarding и план питания

- Welcome → выбор цели: похудение, поддержание, набор мышц или simple tracking.
- Базовый профиль: пол, возраст, рост, вес, единицы измерения.
- Уровень активности, pace и macro preference.
- Приложение рассчитывает дневные calorie и macro targets и показывает готовый план.
- Профиль можно редактировать; restart onboarding сохраняет существующую локальную историю блюд.

### Добавление еды

- Источники: камера, gallery или manual form.
- Photo flow поддерживает:
  - clarification для неоднозначной еды;
  - backend-driven portion confirmation;
  - понятный error state;
  - явный `Add manually` fallback, если анализ не удался.
- Manual form поддерживает название, калории, вес, белки/жиры/углеводы и тип приёма пищи.
- Submit action закреплён внизу формы и доступен на компактном экране/с клавиатурой.
- Пустое или состоящее из пробелов название не сохраняется.

### Home, история и profile

- Home показывает calories consumed/remaining, macros и `Today’s tip`: короткую deterministic-подсказку из текущего дневного прогресса, а не AI Coach.
- История группируется в meal sessions, а не в плоский список.
- Сессии отображаются в Breakfast, Lunch, Dinner и Snacks; классификация учитывает время и калорийность.
- Блюдо можно открыть, изменить или удалить. Manual edit поддерживает связанные пересчёты БЖУ/калорий, field locks, restore/reset и conflict handling.
- Profile честно показывает данные onboarding и текущий daily plan. Аккаунта, Premium entitlement и cloud sync в текущем приложении **нет**.

## 3. Техническая картина

| Область | Текущее решение |
| --- | --- |
| Client | Flutter / Dart, Material 3; основной orchestration/UI пока в `lib/main.dart`. |
| AI photo backend | Отдельный backend, не входит в этот репозиторий. Клиент вызывает `POST /v0/ai/photo-food` и `POST /v0/ai/photo-food/confirm-portion` с `X-API-Key`. |
| Local data | `SharedPreferences`: onboarding result/draft и история блюд сохраняются на устройстве. Это не база данных и не cloud backup. |
| Meal model | Локальные meal entries → session rebuild по дню → category/tier classification → Home/history. |
| Analytics | Provider-neutral `Analytics` interface; Android/iOS используют Firebase Analytics, desktop — debug implementation. События не передают meal names, фото, body measurements, raw dates, request IDs или API keys. |
| Firebase config | Конфиги Android/iOS локальны и игнорируются Git. Их нельзя добавлять в публичную историю; release/CI должен получать их безопасным способом. |
| Tests | Unit/widget tests покрывают onboarding, photo clarification/portion flows, API parsing, session logic, manual edit/autocalc, analytics и ключевые UI states. |

### Локальный запуск

Для photo analysis нужны `API_BASE_URL` и `API_KEY` через `--dart-define`. Backend должен быть доступен отдельно. Firebase Analytics и Firebase config нужны для Android/iOS builds; они не являются заменой backend API.

## 4. Аналитика и текущая проверка качества

### Встроенная Beta telemetry

События: `app_opened` (запуск и возврат приложения из фона), `onboarding_started`, `onboarding_step_viewed`, `onboarding_completed`, `first_meal_logged`, `meal_logged`, `meal_logged_in_existing_session`, `photo_analysis_succeeded`, `photo_analysis_failed`, `manual_fallback_used`, `meal_edited`, `meal_deleted`.

Это позволяет посчитать full/D2 cohort отдельно, app-open denominator, onboarding drop-off по шагам, activation, same-session logging diagnostic, D2 app/logging return, success/failure photo flow и manual fallback usage без отправки содержимого еды или личных измерений.

### Подтверждённое состояние

- `flutter analyze` — clean на 2026-07-11.
- `flutter test` — 70 тестов проходят на 2026-07-11.
- Android Firebase DebugView был подтверждён на физическом устройстве.
- Android internal-alpha walkthrough был начат; полный acceptance script ещё должен быть формально закрыт.

### Ещё не подтверждено / не реализовано

- Полный physical-device acceptance script на Android и iPhone.
- iOS Firebase DebugView verification.
- Crash/error monitoring для beta.
- Production API configuration, при которой тестеру не нужны hidden developer values.
- Feedback email, privacy policy, medical/nutrition disclaimer.
- External TestFlight build и Google Play Closed Testing build.

## 5. Beta v1 — согласованный scope

### Цель beta

Закрытая beta проверяет core habit loop, а не пытается быть готовым Public v1:

`complete onboarding → log meals → understand daily progress → return next day`.

### Формат и успех

- iOS и Android; закрытая группа 20–50 тестеров; строго 14 полных дней.
- Измеряемая D2 cohort завершает onboarding до конца пятого дня (`t0 + 120h`); поздние тестеры могут давать feedback, но не входят в финальный D2 result.
- Activation: в первые 168 часов после onboarding — минимум 3 блюда и минимум 2 новые app logging sessions. Session строится по diary day и gap не более 15 минут между timestamp логирования: batch-logging не считается повторным использованием приложения.
- D2 logging return: хотя бы одно блюдо через 18–42 часа после activation; D2 app return измеряет открытие приложения в том же окне. В отчёте full cohort и eligible D2 cohort всегда имеют отдельные N и знаменатели.
- Решение после beta принимается по activation/return, same-session logging diagnostic, photo/manual behavior, failures и повторяющемуся feedback.

### Beta не включает

- accounts или cloud sync;
- subscriptions/paywall;
- ограничение Free history;
- weekly reports;
- AI coach, schedule или notifications;
- health integrations.

Полный checklist и no-go rules: [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md).

## 6. Public v1 — уже принятые решения

Public v1 — качественный публичный релиз для English-first global аудитории, а не просто build из beta.

### Free

- Unlimited manual logging навсегда.
- `[~]` Предварительно: 5 AI photo analyses в календарный день.
- `[~]` Предварительно: история сегодня и 2 предыдущих календарных дня.

### Premium

- Более высокий, но конфигурируемый photo-analysis limit.
- Полная история.
- Weekly in-app report после полной недели данных; отчёт не делает медицинских обещаний.
- Точные цена, trial, Premium photo quota, Free photo limit и Free history window подтверждаются или меняются только в Pricing/Entitlement gate после beta cost/usage review и до Public v1 release candidate. До этого цифры Free выше не являются финальным обещанием пользователю.

### Optional account backup/restore

- Entry point находится в Profile: `Sign in to back up your data`.
- Провайдеры: Google и Apple.
- Account не блокирует onboarding и ручное логирование.
- Public v1 делает backup/restore после reinstall/new device, но не live sync двух одновременно используемых устройств.
- Если local и cloud data оба существуют, пользователь явно выбирает `Restore cloud data` или `Back up this device`; automatic merge запрещён.
- Public v1 обязан включать понятное удаление account/cloud data, privacy policy, disclaimer и support/recovery path.

## 7. Явно после Public v1

Первый post-v1 Premium этап — [Proactive AI Nutrition Coach](AI_NUTRITION_COACH.md):

- пользователь вручную задаёт и редактирует routine/meal times в Coach settings;
- opt-in push приходит примерно за 20 минут до meal time с допустимым soft delivery window ±30–40 минут;
- дефицит оценивается по rolling average предыдущих 3 дней; первые 3–7 дней — только честный общий cold-start nudge;
- конкретное блюдо, порция и КБЖУ должны поступать из отдельной verified recipe/food base, а LLM формулирует только текст;
- editable schedule, quiet hours, off switch и safety rules: без shame, medical claims или автоматических изменений цели.

Recipe/food base — новая обязательная инфраструктурная зависимость Coach; её provider, licence, API и data model ещё не выбраны.

Также после v1: live multi-device sync, Health Connect/HealthKit и другие integrations, broader fitness tracking, реклама и social features.

## 8. Самые важные риски и как их читать

| Риск | Почему важен | Правильная реакция |
| --- | --- | --- |
| Photo backend недоступен/неточен | Это ключевой, но внешний dependency | Не ломать diary: показывать понятную ошибку и manual fallback; измерять failures. |
| Local-only persistence | Данные не восстановятся после reinstall/new device | Для beta честно сообщать local-only; Public v1 требует optional backup/restore. |
| Недостаточная physical QA | Widget tests не заменяют camera, permissions, release build и реальные устройства | Закрыть manual acceptance script на Android и iPhone до приглашений. |
| Нет crash monitoring | Нельзя увидеть реальные production crashes | Подключить и проверить monitoring до beta. |
| API/config secrets | Неправильный release process может раскрыть или сломать config | Не коммитить secret configs; настроить безопасный build/CI workflow. |
| Слишком ранние фичи | Coach, subscriptions или sync могут скрыть слабый core loop | Следовать stage gates, а не добавлять фичи до evidence. |

## 9. Ближайший порядок действий

1. Закрыть Internal Alpha quality gates: full acceptance script на физическом Android и iPhone, включая camera/gallery/manual/edit/delete/restart/offline/error paths.
2. Настроить crash/error monitoring и проверить его на реальном build.
3. Подготовить production API configuration, feedback email, privacy policy и medical disclaimer.
4. Собрать installable TestFlight и Google Play Closed Testing builds.
5. Провести Closed Beta v1 и принять решение по реальным метрикам, а не по количеству новых фич.
6. Только после beta стабилизации начать Public v1 foundations: account restore и Premium entitlements/history/reports.

## 10. Документы для углубления

- [PRODUCT_QUALITY_ROADMAP.md](PRODUCT_QUALITY_ROADMAP.md) — полный порядок этапов и quality gates.
- [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md) — конкретный beta release checklist.
- [ANALYTICS.md](ANALYTICS.md) — event contract и privacy boundary.
- [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md) — Premium coach после Public v1.
- [agent_guide.md](agent_guide.md) — инженерная карта проекта.

## 11. Короткий вывод для нового человека

Продукт уже умеет качественно вести дневник питания через фото и вручную, но сейчас его задача — доказать это на закрытой beta, а не расширять функциональность. Главный ближайший фокус: real-device reliability, production readiness и feedback loop. Public v1 добавит optional backup/restore и Premium monetization; персональный AI coach с распорядком и reminders — следующий Premium этап после того, как публичный дневник доказал ценность.
