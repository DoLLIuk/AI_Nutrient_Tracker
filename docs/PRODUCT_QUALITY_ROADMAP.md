# Master Roadmap качества до Public v1

Статус: канонический guideline развития продукта от текущей internal alpha до публичного релиза и первых 30 дней после него.

Последняя ревизия: 2026-07-11

## 1. Назначение и правило приоритета

Этот документ отвечает на четыре вопроса:

1. Какой следующий этап действительно нужен продукту.
2. Что обязательно должно работать качественно до перехода дальше.
3. Какие функции входят в Public v1, а какие сознательно отложены.
4. По каким данным принимать решение о запуске, паузе или следующей итерации.

Главный принцип:

`Качественный, понятный и честный core loop важнее количества функций.`

Новая функция не входит в ближайший этап только потому, что она интересная. Для неё должны быть понятны: пользовательская проблема, ожидаемая метрика, влияние на качество и стоимость поддержки.

### 1.1. Иерархия документов

- Этот roadmap задаёт порядок этапов и общие quality gates до Public v1.
- [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md) остаётся точным чеклистом закрытой beta.
- [ANALYTICS.md](ANALYTICS.md) остаётся источником правды для telemetry.
- [PROJECT_WORK_BACKLOG.md](PROJECT_WORK_BACKLOG.md) содержит короткие практические задачи.
- [MVP_PRD.md](MVP_PRD.md), [FUTURE_PRODUCT_GOALS.md](FUTURE_PRODUCT_GOALS.md) и документы из `planning/` дают детализацию. Если порядок этапов расходится, приоритет у этого roadmap.

## 2. Как пользоваться документом

### 2.1. Статусы

- `[ ]` — не начато.
- `[~]` — в работе или частично подтверждено.
- `[x]` — сделано и проверено в заявленном scope.
- `[!]` — блокер / no-go: нельзя идти дальше, пока не устранён.

### 2.2. Переход между этапами

- Нельзя начинать распространение следующего этапа при незакрытом `[!]` в текущем.
- `[x]` ставится только после проверки, указанной рядом с пунктом. Реализация без проверки остаётся `[~]`.
- Если beta или production показывают новый критический риск, roadmap возвращается к предыдущему quality gate; функциональность не расширяется до исправления.
- После каждого этапа обновляются: дата ревизии, фактические метрики, три главных вывода, список решённых и новых рисков.

### 2.3. Общий Definition of Quality

На любом этапе продукт считается качественным только если одновременно:

- пользователь понимает следующий шаг без объяснений автора;
- ручной путь всегда позволяет закончить основную задачу;
- данные не исчезают при обычном использовании;
- приложение честно сообщает об ограничениях AI и данных;
- ошибки наблюдаемы командой и понятны пользователю;
- все обещания в интерфейсе соответствуют существующей функциональности.

## 3. Продуктовый компас Public v1

### 3.1. Целевая аудитория и платформы

- Первый публичный рынок: English-first global.
- Платформы: Android и iOS.
- Русский язык используется для внутренней документации; публичный UI, store metadata, help и support-путь сначала проектируются на английском.
- Public v1 — зрелый публичный продукт, а не ранняя beta или демонстрация.

### 3.2. Главная польза

`Сфотографировать или вручную залогировать еду, увидеть честный дневной прогресс по калориям и макросам, затем вернуться к привычке на следующий день.`

### 3.3. Неизменяемые продуктовые границы

- Manual logging всегда доступен и никогда не расходует AI-лимит.
- AI photo analysis — ключевая функция v1, но не единственный путь.
- AI coach, чат-советы, расписание питания, proactive AI notifications и health integrations не входят в Public v1.
- Нельзя блокировать базовое логирование paywall, ошибкой AI или требованием создать аккаунт.

## 4. Public v1: feature и entitlement matrix

| Функция | Free | Premium | Этап появления | Критерий качества | Измерение | Статус |
| --- | --- | --- | --- | --- | --- | --- |
| Manual food logging | Unlimited | Unlimited | Beta v1 | Добавление, edit/delete и история не требуют оплаты | `meal_logged`, edit/delete success | `[~]` |
| AI photo analysis | 5 анализов за календарный день — `[~]` предварительно до Pricing/Entitlement gate | Повышенный конфигурируемый лимит | Beta v1 → Public v1 entitlement | Лимит виден до расходования; сбой всегда ведёт к manual fallback | photo success/failure, limit reached, fallback | `[~]` |
| Recent history | Сегодня + 2 предыдущих календарных дня — `[~]` предварительно до Pricing/Entitlement gate | Полная история | Public v1 | Граница истории понятна, ничего не удаляется из данных при скрытии Free UI | history open, upgrade intent | `[~]` |
| Weekly in-app report | — | Да, после полной недели данных | Public v1 | Никаких медицинских обещаний; отчёт объясняет источники данных и пропуски | report generated/opened | `[ ]` |
| Account backup/restore | Optional | Optional, не Premium-only | Public v1 | Пользователь может восстановить onboarding и историю после переустановки | sign-in, backup, restore success/failure | `[ ]` |
| Proactive AI Nutrition Coach, routine and push reminders | — | Premium | После Public v1 | Explicit routine, consent, safety review, recipe/food base и доказанный спрос | coach/routine metrics | `[ ]` |

### 4.1. Pricing и entitlement gate

До Public v1 release candidate обязательно закрыть:

- [ ] Подтвердить или изменить предварительный Free photo limit (5 анализов в календарный день) на основе стоимости фото-анализа, beta usage и abuse-risk.
- [ ] Подтвердить или изменить предварительное Free history window (сегодня + 2 предыдущих календарных дня) вместе с value/cost review.
- [ ] Подтвердить точный Premium photo limit на основе стоимости фото-анализа, beta usage и abuse-risk.
- [ ] Выбрать цену, месячный/годовой план и trial только после проверки unit economics.
- [ ] Определить понятный Free-to-Premium copy без ложной срочности.
- [ ] Проверить, что restore purchases, billing error, cancellation и support path работают на обеих платформах.
- [ ] Не хранить purchase entitlement только на устройстве.

До закрытия этого gate значения `5` и `2` выше — не финальное пользовательское обещание, а проверяемые рабочие гипотезы.

## 5. Account и данные: политика Public v1

### 5.1. Пользовательский опыт

- Аккаунт необязателен: новый пользователь может пройти onboarding и вести дневник локально.
- В Profile появляется понятный entry point: `Sign in to back up your data`.
- Провайдеры Public v1: Google и Apple.
- После входа пользователь понимает, какие данные будут сохранены в cloud и зачем это нужно.
- v1 предоставляет backup/restore после переустановки или смены устройства; live sync двух одновременно используемых устройств сознательно отложен.

### 5.2. Первый вход и конфликт данных

Если на устройстве есть local data, а в account уже есть cloud data:

- [ ] Показать явный выбор: `Restore cloud data` или `Back up this device`.
- [ ] Не объединять записи автоматически и не удалять ни один набор без подтверждения.
- [ ] До подтверждения показать, какой набор будет заменён и когда он был обновлён.
- [ ] Восстановление должно быть транзакционным: при ошибке local data остаётся доступным.

### 5.3. Privacy и контроль

- [ ] Privacy policy описывает local data, cloud backup, analytics, subscriptions, retention и third parties.
- [ ] Медицинский/nutrition disclaimer виден там, где пользователь принимает решение на основе данных приложения.
- [ ] Пользователь может удалить account и cloud data из приложения без обращения в support.
- [ ] Пользователь может запросить или экспортировать свои данные; точный формат фиксируется до release candidate.
- [ ] Support flow для login/restore/billing не требует отправлять чувствительные данные в открытом виде.

## 6. Этап 0 — текущий snapshot и Internal Alpha

### Цель

Довести основу до состояния, в котором команда сама проходит core loop на реальных устройствах без подсказок и без потери данных.

### Уже подтверждено

- `[x]` Approved Beta v1 checklist существует.
- `[x]` Минимальная Firebase Analytics интеграция и event contract добавлены.
- `[x]` Android Firebase DebugView был подтверждён на физическом устройстве.
- `[x]` Manual form получила fixed submit action и валидацию имени; widget tests покрывают компактный экран.
- `[x]` Притворяющиеся account/premium/security поверхности были убраны или сделаны честнее.
- `[~]` Android physical-device walkthrough проведён; iOS physical-device walkthrough ещё не подтверждён.

### QoL и UX

- [ ] Новый пользователь проходит onboarding без объяснений автора.
- [ ] На каждом экране понятно, что будет после primary action.
- [ ] Camera, gallery и manual add имеют одинаково понятные cancel/error states.
- [ ] Empty states объясняют, как получить первую ценность.
- [ ] Meal edit/delete имеют подтверждение и не создают неожиданных изменений totals/history.
- [ ] Все тексты и обещания интерфейса соответствуют реально работающим функциям.

### Reliability, performance и offline

- [ ] Onboarding, meals и plan переживают обычный restart на Android и iOS.
- [ ] Уже сохранённые данные доступны без сети; отсутствие сети не маскируется под удаление данных.
- [ ] AI timeout, invalid response, permission denial и cancelled picker завершаются понятным recoverable state.
- [ ] Ключевой UI остаётся отзывчивым при истории с большим количеством записей.
- [ ] API configuration существует в beta build без скрытых `dart-define` действий от тестера.

### Tests и device matrix

- [ ] `flutter analyze` чист.
- [ ] Unit/widget test suite зелёный.
- [ ] Manual acceptance script из [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md) пройден на физическом Android.
- [ ] Тот же script пройден на физическом iPhone.
- [ ] Проверены как минимум один компактный и один большой экран на каждой платформе.
- [ ] Перед внешней beta подключён crash/error monitoring и проверен test crash/non-fatal error.

### Exit gate

- Нет `[!]` в core logging, persistence, photo fallback или build installation.
- Android и iOS physical smoke tests пройдены.
- Все beta no-go условия из [BETA_V1_CHECKLIST.md](BETA_V1_CHECKLIST.md) закрыты.

## 7. Этап 1 — Closed Beta v1

### Цель

Проверить, формируется ли привычка вокруг существующего loop, без преждевременного расширения продукта.

### Формат

- [ ] TestFlight external testing и Google Play Closed Testing готовы.
- [ ] 20–50 тестеров; beta длится 14 полных дней (`t0 → t0 + 336h`).
- [ ] Измеряемая D2 cohort завершает onboarding не позднее `t0 + 120h` (конец пятого дня); более поздние тестеры дают qualitative feedback, но не входят в финальную D2 cohort.
- [ ] Dedicated feedback email, support owner и короткая инструкция готовы до приглашений.
- [ ] Build имеет понятный version number, release notes и известные ограничения.

### Quality checklist

#### Product / QoL

- [ ] Тестер активируется: onboarding + минимум 3 блюда в минимум 2 отдельных app logging sessions. Session определяется diary day и gap не более 15 минут между timestamp логирования; batch-logging намеренно не доказывает повторное использование приложения.
- [ ] AI photo path полезен, но manual fallback всегда заметен и работает.
- [ ] Пользователь понимает Free scope без paywall, который мешает первому value moment.
- [ ] Не добавлять account, subscription, weekly report или coach в середине beta, если это не устраняет no-go bug.

#### Analytics и feedback

- [ ] Виден путь: app open → onboarding started/step → onboarding completed → first meal → photo success/failure → manual fallback → D2 app/logging return.
- [ ] Dashboard/queries позволяют посчитать full cohort и D2 cohort отдельно: app-open denominator, onboarding drop-off, 168-hour activation, eligible D2 return и same-session logging diagnostic без лишних персональных данных.
- [ ] Каждая feedback item содержит platform, app version, expected result и reproduction steps, когда это возможно.
- [ ] Еженедельно сортировать feedback по severity: blocker, trust issue, friction, enhancement.

#### Reliability

- [ ] Нет повторяющегося crash или data-loss паттерна.
- [ ] Network/API incidents имеют support copy и план communication тестерам.
- [ ] Новая beta build не отправляется, пока прошлый critical issue не имеет reproduction и проверенного fix.

### No-go

- `[!]` Нельзя продолжать приглашения при data loss, невозможности добавить manual meal, отсутствии fallback, неустанавливаемом build или повторяющемся critical crash.

### Exit gate

- [ ] Собраны onboarding funnel, 168-hour activation, same-session logging diagnostic, eligible D2 app/logging return, photo/manual usage и пять главных feedback themes; оба набора cohort N указаны рядом с процентами.
- [ ] Для каждой критичной темы принято решение: fix before public, validate in next beta или explicitly defer.
- [ ] Есть evidence, что люди понимают продукт и возвращаются не только по просьбе автора.

## 8. Этап 2 — Beta learning и stabilization

### Цель

Превратить данные beta в изменения качества, а не в список случайных фич.

### Checklist

- [ ] Составить beta review: full/D2 cohort N, app opens, onboarding funnel, activation, same-session logging diagnostic, D2 return, AI success, fallback, bugs и quotes. Day-7 retention добавляется только после отдельного window definition.
- [ ] Отделить defects core loop от feature requests.
- [ ] Исправить top trust/reliability/friction issues и повторить acceptance script.
- [ ] Провести ещё одну короткую validation beta, если изменения затронули onboarding, data model, persistence или photo flow.
- [ ] Зафиксировать Public v1 scope и отдельный `Not in v1` list.

### Exit gate

- [ ] Нет незакрытого beta blocker.
- [ ] Public v1 additions имеют отдельные acceptance criteria и не отменяют подтверждённый manual-first core loop.

## 9. Этап 3 — Public v1 foundations

### Цель

Добавить обязательные для зрелого публичного продукта account restore, entitlements и legal/operational foundation без преждевременного AI coach.

### Account backup/restore

- [ ] Выбрать и задокументировать cloud data model, ownership, encryption/transport assumptions и retention.
- [ ] Реализовать Google и Apple sign-in.
- [ ] Реализовать backup нового local profile/history в пустой account.
- [ ] Реализовать restore после clean install/new device.
- [ ] Реализовать явный conflict choice из раздела 5.2.
- [ ] Проверить failed upload/download, cancellation, sign-out и account deletion на Android/iOS.
- [ ] Добавить observability для auth/backup/restore без передачи содержимого еды в analytics.

### Premium и weekly report

- [ ] Реализовать единый entitlement layer для Free/Premium, а не разрозненные UI checks.
- [ ] Реализовать Free history window: сегодня + два предыдущих дня, без удаления более старых данных.
- [ ] Реализовать Premium full history и higher configurable photo limit.
- [ ] Реализовать weekly in-app report только при достаточном количестве честно доступных данных; показать пропуски, а не выдумывать выводы.
- [ ] Billing, restore purchases, cancel, refund/support и paywall error states протестированы на обеих платформах.

### Security, privacy и operations

- [ ] Firebase/backend keys и environment configs не попадают в public Git history; CI/store build получает их безопасным способом.
- [ ] Применены server-side authorization rules для cloud data; client configuration не считается защитой данных.
- [ ] Privacy policy, terms, medical disclaimer и contact/support URL готовы для store surfaces.
- [ ] Утверждён incident process: кто видит alert, как отключается проблемный endpoint/feature, как сообщаются critical incidents.

### Exit gate

- [ ] Account restore, entitlement и billing не создают data-loss или блокируют manual logging.
- [ ] Legal/support/privacy gates готовы для регионов первой публикации.
- [ ] Все Premium claims проверяемы в реальном store sandbox.

## 10. Этап 4 — Public v1 release candidate

### Цель

Собрать финальные store-ready builds и доказать, что они соответствуют обещаниям продукта.

### UX и content

- [ ] English UI, onboarding, error copy, support copy и paywall copy вычитаны.
- [ ] Store screenshots показывают реальные функции, а не макеты будущих возможностей.
- [ ] Короткое demo video показывает onboarding → photo/manual meal → daily progress → history.
- [ ] Store screenshots, demo video, landing copy и beta invite не называют deterministic `Today’s tip` AI Coach и не обещают будущие AI-функции.
- [ ] Landing/project page, FAQ и contact path опубликованы.

### Release engineering

- [ ] Versioning, signing, production API configuration и release notes готовы для iOS и Android.
- [ ] Clean-install smoke test, upgrade smoke test и signed-out/signed-in restore test пройдены на обеих платформах.
- [ ] Crash/error monitoring, analytics dashboard и support inbox проверены на production-like build.
- [ ] CI запускает analyze/tests перед release candidate; manual test evidence приложен к candidate.
- [ ] Rollback/kill-switch strategy для photo API, account restore и paywall задокументирована.

### Store readiness

- [ ] App Store Connect и Google Play listing заполнены честным описанием, privacy disclosure и age/content settings.
- [ ] Purchase metadata, restore purchase и cancellation wording соответствуют продукту.
- [ ] Privacy policy и medical disclaimer доступны по стабильным URL.

### No-go

- `[!]` Нельзя выпускать Public v1 при непроверенном restore, billing bug, critical privacy/security issue, recurring crash или misleading store claim.

### Exit gate

- [ ] Release candidate прошёл полный manual script на iOS и Android.
- [ ] Все Public v1 feature matrix rows имеют owner, telemetry и support path.
- [ ] Решение о публикации принято на основании checklist, а не только готовности build.

## 11. Этап 5 — Public v1 launch

### Цель

Запустить продукт контролируемо и не потерять качество в первой волне реальных пользователей.

### Checklist

- [ ] Публикация поэтапная: сначала ограниченная первая волна, затем расширение при отсутствии critical signals.
- [ ] Landing page, store links, feedback address, FAQ и privacy/disclaimer доступны до announcement.
- [ ] Подготовлены launch copy, screenshots, demo video и changelog.
- [ ] Не обещать AI coach, notifications, live sync или integrations до их фактического выпуска.
- [ ] Есть owner для daily monitoring и support response.

### Первые 72 часа

- [ ] Проверять install, onboarding, meal logging, photo API, billing, auth/restore и crash alerts ежедневно.
- [ ] Critical incident: остановить promotion, отключить безопасно отключаемую проблемную функцию, сообщить пользователям при необходимости, выпустить hotfix.
- [ ] Не менять pricing/limits из-за одного отзыва; фиксировать evidence.

## 12. Этап 6 — первые 30 дней после Public v1

### Цель

Понять, стабилен ли продукт в реальном масштабе и что заслуживает следующей инвестиции.

### Weekly operating rhythm

- [ ] Еженедельный review: activation, eligible D2 app/logging return, photo success, manual fallback, Free-to-Premium conversion, restore success, crashes и support themes. Day-7 retention добавляется только после отдельного window definition.
- [ ] Каждой проблеме назначены severity, owner, target build и verification.
- [ ] Новые feature requests попадают в backlog только с user problem и ожидаемой метрикой.
- [ ] Pricing, photo quota и weekly report пересматриваются по usage/cost, а не интуиции.

### 30-day decision gate

- [ ] Сформировать public v1 review с количественными метриками и пользовательскими цитатами.
- [ ] Решить: стабилизировать v1, улучшать retention, расширять Premium или начинать следующий отдельный этап.
- [ ] Premium AI coach может начаться только после отдельного PRD, safety/copy rules, consent model и доказанного спроса на него.
- [ ] Live multi-device sync может начаться только после того, как backup/restore не создаёт data-loss incidents.

## 13. Cross-cutting quality checklist

Эти правила применяются к каждому изменению, а не только к release этапам.

### QoL

- [ ] Есть понятный empty/loading/error/success state.
- [ ] Primary action доступен на компактном экране и с открытой клавиатурой.
- [ ] Accessibility labels, tap targets, contrast и text scaling проверены для ключевого пути.
- [ ] Никаких мёртвых кнопок, placeholder accounts или фальшивых premium claims.

### Optimization и reliability

- [ ] Нет тяжёлой работы на UI thread в ключевом пути.
- [ ] Списки истории и изображения имеют проверенную стратегию загрузки/кэширования.
- [ ] Повторный tap, network retry, app background/foreground и interrupted flow не дублируют meal или purchase.
- [ ] Local persistence имеет migration/backup strategy до изменения схемы данных.

### Tests

- [ ] Unit tests покрывают расчёты, entitlement, quota, sync conflict и serialization.
- [ ] Widget tests покрывают onboarding, manual/photo flows, paywall states и account restore choices.
- [ ] Integration/manual tests покрывают real auth, store sandbox billing, camera/gallery, offline и restore after reinstall.
- [ ] Каждый fixed production/beta bug получает regression test, если это технически возможно.

### Observability

- [ ] Новый user-critical flow имеет success/failure events без лишних персональных данных.
- [ ] Crash/error reports содержат version/platform/context, но не содержимое еды, токены или config secrets.
- [ ] Dashboard отвечает на вопрос: где пользователь не получает value и что ломается чаще всего.

## 14. Явно не входит в Public v1

- Full AI nutrition coach, chat и proactive coaching.
- Пользовательское расписание питания и AI meal reminders.
- Push notification system.
- Health Connect, Apple HealthKit, wearables и fitness integrations.
- Live simultaneous multi-device sync и automatic conflict merge.
- Реклама, social features и broad fitness tracking.

Эти направления не отменены. Первым Premium-направлением после v1 станет proactive AI Coach с персонализацией, добровольным расписанием и opt-in push. Он требует отдельного scope, privacy/safety review, recipe/food base, измеримой причины и нового quality gate после Public v1.

## 15. Первый Premium-этап после Public v1: Personal AI Coach

### Цель

Добавить платную персонализацию только поверх уже проверенного дневника, а не подменять ею базовую ценность продукта.

Подробная спецификация и locked product decisions: [AI_NUTRITION_COACH.md](AI_NUTRITION_COACH.md).

### Premium capability

- [ ] Coach использует goal, targets, meal history и rolling average дефицита за предыдущие 3 дня.
- [ ] Пользователь вручную задаёт и редактирует wake/meal schedule только в будущих Coach settings; learned schedule не входит в этот этап.
- [ ] Opt-in push нацелен примерно за 20 минут до meal time; soft delivery window ±30–40 минут, quiet hours и понятный off switch обязательны.
- [ ] Первые 3–7 дней Coach даёт только общий cold-start nudge, без конкретного блюда или рецепта.
- [ ] Verified recipe/food base выбирает блюдо, порцию и КБЖУ; LLM формулирует только message copy. Provider, licence, API и data model базы — открытая technical dependency.
- [ ] Пользователь видит, какие данные повлияли на рекомендацию, и может dismiss/correct её.
- [ ] Weekly report и Coach не обещают гарантированное похудение, диагноз или медицинский результат.

### Границы и exit gate

- Free manual logging, базовые цели и история не ухудшаются из-за Premium coach.
- Coach не стартует до подтверждения спроса, consent/privacy review, recipe/food-base readiness и измеримого retention hypothesis.
- До расширения на health data подтверждаются: полезность coach cards, низкая доля жалоб/отключений и отсутствие safety incidents.
