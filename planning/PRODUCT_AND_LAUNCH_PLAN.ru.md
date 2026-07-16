# План разработки и вывода AI Calorie Tracker

Обновлено: 2026-07-06

> Примечание: порядок этапов и quality gates до Public v1 теперь задаёт [docs/PRODUCT_QUALITY_ROADMAP.md](../docs/PRODUCT_QUALITY_ROADMAP.md). Этот документ сохраняет стратегический и публичный контекст; при расхождении приоритет у master roadmap.

Этот документ фиксирует практичный путь от текущего состояния приложения к `Beta v1`, первым пользователям и публичному релизу. Главная идея: не просто выложить приложение в App Store / Google Play, а заранее подготовить продукт, аудиторию, фидбэк и понятную историю проекта.

## 1. Стратегия

Ближайшая цель: `Beta v1`.

`Beta v1` - это не финальный идеальный продукт. Это стабильная версия, которую можно дать реальным людям, чтобы проверить главный цикл:

`прошел onboarding -> добавил еду -> увидел прогресс дня -> понял следующий шаг -> вернулся позже`

Приоритеты:

- сначала доказать пользу core loop;
- собрать первых реальных пользователей и фидбэк;
- измерить retention и завершение ключевых сценариев;
- не торопиться со спонсорами, paywall и большой публичной кампанией до первых доказательств интереса.

Не стоит начинать с поиска спонсоров. Спонсору или партнеру проще поверить в проект, когда уже есть демо, beta-пользователи, screenshots, короткое видео и первые метрики.

## 2. Product Roadmap

### Pre-Beta

Цель: подготовить продукт к использованию не только автором.

Сделать:

- стабилизировать onboarding, home dashboard, photo flow, manual add/edit и session history;
- убедиться, что приложение не теряет локальные данные после перезапуска;
- проверить понятные fallback-сценарии, если AI-фото не сработало;
- убрать или явно ослабить UI, который выглядит как реальная аналитика, но пока является демонстрационным;
- подготовить production-style `API_BASE_URL` / `API_KEY` процесс без ручной путаницы;
- добавить базовую аналитику событий;
- подготовить privacy policy и понятный disclaimer, что приложение не является медицинским сервисом.

Минимальные события аналитики:

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

Цель: дать приложение 30-100 людям и понять, возвращаются ли они.

Критерии готовности:

- новый пользователь может пройти onboarding без объяснений;
- первый прием пищи можно добавить быстро;
- ошибки фото-анализа не ломают доверие, потому что есть ручной fallback;
- пользователь понимает, сколько калорий и БЖУ уже съел и сколько осталось;
- есть способ быстро отправить фидбэк.

Что измерять:

- onboarding completion rate;
- first meal logged rate;
- meals logged per active day;
- photo flow completion rate;
- manual fallback rate;
- day-2 retention;
- day-7 retention;
- qualitative feedback: что было непонятно, где пользователь бросил сценарий, чего не хватило.

### Public v1

Цель: публичный релиз после проверки, что beta не ломается на реальных людях.

Точный scope, включая account restore и Premium-подписку, задан в master roadmap и здесь не дублируется.

Сделать перед релизом:

- подготовить store screenshots и короткий demo video;
- сделать landing/project page;
- описать продукт одной фразой;
- подготовить FAQ: точность AI, privacy, медицинский disclaimer, зачем нужен ручной ввод;
- проверить crash/error monitoring;
- проверить App Store / Google Play metadata;
- подготовить launch posts для разных площадок.

Формулировка продукта:

`AI Calorie Tracker helps you log meals faster with photo analysis, manual fallback, and a clear daily calorie and macro summary.`

### Post-v1

Цель: развивать продукт только после того, как core loop показывает жизнь.

Возможные направления:

- персональный AI-нутрициолог;
- integrations с Apple Health, Android Health Connect, Fitbit/Google Health или другими источниками активности;
- push reminders;
- live sync нескольких устройств;
- более сильная локальная база данных.

Важно: monetization и AI coach не должны спасать слабый core loop. Они должны усиливать уже полезный дневник питания.

## 3. Launch Roadmap

### Шаг 1: ручные тестеры

Цель: 10-20 людей.

Где искать:

- друзья и знакомые, которые считают калории или ходят в зал;
- учеба / локальные чаты;
- фитнес-комьюнити;
- люди, которые уже пробовали MyFitnessPal, Yazio, Lifesum, Cronometer или похожие приложения.

Что дать тестерам:

- короткое объяснение: "Это приложение для быстрого логирования еды через фото или вручную";
- ссылку на build;
- просьбу залогировать хотя бы 2-3 приема пищи за день;
- 3 вопроса после теста:
  - где было непонятно?
  - что было быстрее или удобнее, чем в обычном трекере?
  - вернулся бы ты завтра?

### Шаг 2: закрытая beta

Цель: 30-100 пользователей.

Каналы:

- Apple TestFlight: https://developer.apple.com/testflight/
- Google Play testing tracks: https://support.google.com/googleplay/android-developer/answer/9845334

Фокус:

- стабильность;
- onboarding;
- первый meal log;
- AI photo flow;
- ручной fallback;
- фидбэк по Home screen.

Не добавлять на этом этапе много новых функций. Лучше исправить главный путь, чем расширять продукт горизонтально.

### Шаг 3: landing/project page

Цель: чтобы у проекта была понятная публичная точка.

Страница должна содержать:

- название продукта;
- короткое обещание;
- 4-6 screenshots;
- 20-40 секунд demo video или GIF;
- список core features;
- ссылку на beta / waitlist / feedback form;
- privacy/disclaimer ссылки;
- GitHub ссылку, если это помогает доверю.

Не делать страницу как большой маркетинговый лендинг. Для этого проекта лучше честная product page: что делает приложение, для кого оно, что уже работает.

### Шаг 4: публичный релиз

Цель: не просто "выложить в стор", а создать несколько волн внимания.

Волны:

- день релиза: GitHub README update, landing page, короткое видео;
- первая неделя: посты в личных соцсетях, fitness/weight-loss communities, indie maker communities;
- после первых отзывов: Product Hunt или похожая площадка;
- после улучшений: повторный контент "что изменилось после beta feedback".

Product Hunt reference: https://www.producthunt.com/launch

Reddit использовать аккуратно. Не приходить в сообщество только ради ссылки. Сначала участвовать, отвечать, быть честным и явно помечать, что это свой проект. Reference: https://www.reddit.com/r/reddit.com/wiki/selfpromotion/

## 4. Как привлекать внимание

Главный angle:

`A simple AI calorie tracker focused on fast meal logging, clear daily progress, and manual fallback when AI is uncertain.`

Контент, который стоит подготовить:

- короткий demo video: onboarding -> photo meal -> confirmation -> day summary;
- before/after: как долго логировать еду вручную vs через фото;
- thread/post: "What I learned building an AI calorie tracker";
- пост про UX: почему AI должен уметь уточнять и просить confirmation;
- screenshots для README и store pages;
- маленький changelog после каждой beta-итерации.

Площадки:

- GitHub;
- X / Threads / LinkedIn, если там есть аудитория;
- Reddit, но только с уважением к правилам;
- Product Hunt, когда будет понятное демо;
- локальные fitness / gym / weight-loss группы;
- личные знакомства и учебные чаты.

## 5. Спонсоры и партнеры

Искать спонсоров до beta не нужно. На раннем этапе важнее пользователи.

Когда можно начинать:

- есть 50-100 beta-пользователей;
- есть понятный demo video;
- есть 3-5 сильных отзывов;
- видно, что люди логируют больше одного приема пищи;
- есть первые retention numbers.

Кому писать:

- локальные фитнес-тренеры;
- небольшие залы;
- nutrition coaches;
- студенческие wellness communities;
- creators, которые говорят про питание и спорт.

Что предлагать:

- не "дайте денег на идею";
- а "вот рабочий beta-продукт, можно дать вашей аудитории early access";
- совместный feedback cohort;
- публичный case study;
- партнерский промокод позже, если появится premium.

## 6. Летний рабочий план

### Неделя 1

- пройти весь core flow на реальном устройстве;
- записать demo video;
- составить список багов и UX-трений;
- выбрать 10 ручных тестеров.

### Неделя 2

- исправить top-5 проблем из собственного теста;
- подготовить feedback form;
- дать build первым тестерам;
- записывать не только баги, но и фразы пользователей.

### Неделя 3

- улучшить onboarding и first meal flow по фидбэку;
- добавить/проверить базовую аналитику;
- подготовить screenshots и короткое описание продукта.

### Неделя 4

- запустить закрытую beta;
- собрать 30+ пользователей;
- смотреть на first meal logged rate и day-2 retention;
- не добавлять крупные новые фичи, пока главный путь не стал надежным.

### После первого месяца

- решить: продолжать beta, готовить public v1 или возвращаться к core UX;
- если core loop работает, готовить landing page и public launch;
- если retention слабый, искать проблему в скорости логирования, доверии к AI или понятности Home screen.

## 7. Решения, которые пока не принимать

Не решать слишком рано:

- точную цену подписки;
- сложный paywall;
- полноценный AI coach;
- live sync нескольких устройств;
- интеграции с несколькими health platforms одновременно;
- партнерства до beta.

Эти решения будут качественнее после первых пользователей.

## 8. References

- Apple TestFlight: https://developer.apple.com/testflight/
- Google Play testing: https://support.google.com/googleplay/android-developer/answer/9845334
- Product Hunt Launch Guide: https://www.producthunt.com/launch
- Reddit self-promotion guide: https://www.reddit.com/r/reddit.com/wiki/selfpromotion/
