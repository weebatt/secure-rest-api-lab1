#set page(
  paper: "a4",
  margin: (left: 25mm, right: 15mm, top: 20mm, bottom: 20mm),
)
#set text(font: "Times New Roman", size: 12pt, lang: "ru")
#set par(justify: true, first-line-indent: 12.5mm, leading: 0.68em)
#set heading(numbering: "1.1")
#show raw: set text(font: "Menlo", size: 8.5pt)
#show heading.where(level: 1): it => block(above: 18pt, below: 12pt)[
  #set text(size: 14pt, weight: "bold")
  #align(center)[#it]
]
#show heading.where(level: 2): it => block(above: 13pt, below: 8pt)[
  #set text(size: 12.5pt, weight: "bold")
  #it
]
#show figure.caption: set text(size: 10.5pt)

#set page(numbering: none)
#align(center)[
  #set text(size: 14pt)
  Федеральное государственное автономное образовательное учреждение высшего образования \
  «Национальный исследовательский университет ИТМО»

  #v(28mm)
  #text(weight: "bold")[«Информационная безопасность»]

  #text(size: 16pt, weight: "bold")[Лабораторная работа № 1]

  #text(size: 15pt, weight: "bold")[Разработка защищенного REST API с интеграцией в CI/CD]
]

#v(70mm)
#grid(
  columns: (0fr, 1fr),
  [],
  [
    #set par(first-line-indent: 0pt)

    *Обучающийся:* \
    Александров Александр Александрович, P3406

    *Практик:* \
    Маркина Татьяна Анатольевна
  ],
)

#v(75mm)
#align(center)[2026]

#pagebreak()
#set page(numbering: "1", number-align: bottom + center)
#counter(page).update(2)

#outline(title: [Содержание], depth: 3, indent: auto)

#pagebreak()
= Цель и постановка задачи

Цель работы - получить практический опыт разработки безопасного backend-приложения и встроить автоматическую проверку безопасности в процесс непрерывной интеграции. В работе требуется учесть риски OWASP Top 10, реализовать JWT-аутентификацию, исключить хранение паролей в открытом виде, предотвратить SQL-инъекции и XSS, а также настроить SAST и SCA.

#set par(first-line-indent: 0pt)
В рамках работы необходимо реализовать не менее трех методов REST API:

+ `POST /auth/login` - проверка логина и пароля, выдача JWT;
+ `GET /api/data` - чтение данных только после аутентификации;
+ самостоятельно выбранный метод - в проекте это `POST /api/data`, создающий новую запись от имени текущего пользователя.

Для автоматической проверки должны выполняться тесты, статический анализ исходного кода или байткода и аудит сторонних зависимостей. Проверки должны запускаться на каждый push и pull request.

= Выбор технологий

Проект реализован на Java 21 и Spring Boot 3.5.16. Выбранная версия Java является LTS, а Spring Boot предоставляет готовую интеграцию веб-слоя, безопасности и JPA.

#table(
  columns: (30%, 70%),
  inset: 6pt,
  stroke: 0.5pt,
  table.header([*Компонент*], [*Назначение*]),
  [Spring Web], [REST-контроллеры, JSON-сериализация и обработка HTTP-запросов.],
  [Spring Security], [Проверка учётных данных, BCrypt, фильтрация JWT и контроль доступа.],
  [Spring Data JPA], [Работа с базой через ORM и параметризованные запросы.],
  [H2], [Файловая база данных для воспроизводимого учебного запуска.],
  [JJWT 0.13.0], [Формирование и криптографическая проверка JWT.],
  [JUnit 5 + MockMvc], [Интеграционные тесты API без внешнего HTTP-сервера.],
  [SpotBugs], [SAST: статический анализ скомпилированного Java-байткода.],
  [OWASP Dependency-Check], [SCA: сопоставление зависимостей с базами известных CVE.],
  [GitHub Actions], [Автоматический запуск тестов и сканеров.],
)

Сборка выполняется Maven Wrapper, поэтому на рабочей станции достаточно JDK 21. Все версии библиотек и плагинов закреплены в `pom.xml`, что делает сборку воспроизводимой.

#pagebreak()
= Архитектура приложения

Приложение имеет слоистую структуру:

+ `controller` принимает HTTP-запросы и возвращает DTO;
+ `service` содержит сценарии аутентификации и работы с данными;
+ `repository` изолирует доступ к базе данных;
+ `model` содержит JPA-сущности пользователя и записи;
+ `security` реализует создание и проверку JWT;
+ `config` задаёт правила Spring Security и начальные данные;
+ `error` формирует безопасные JSON-ответы об ошибках.

#figure(
  block(
    width: 100%,
    fill: rgb("f6f8fa"),
    stroke: 0.7pt + rgb("9aa4b2"),
    radius: 4pt,
    inset: 12pt,
  )[
    #align(center)[
      *Клиент* → `SecurityFilterChain` → `JwtAuthenticationFilter` → `Controller` \
      ↓ #h(38mm) ↓ \
      `401 JSON` #h(18mm) `Service` → `Repository` → `H2`
    ]
  ],
  caption: [Упрощённая схема обработки защищённого запроса],
)

Для каждого запроса к `/api/**` цепочка фильтров извлекает Bearer-токен. При корректной подписи, издателе и сроке действия в `SecurityContext` помещается аутентифицированный пользователь. Только после этого запрос передаётся контроллеру.

== Модель данных

Таблица `app_users` содержит идентификатор, уникальное имя пользователя и BCrypt-хеш. Поле с открытым паролем в сущности отсутствует. Таблица `data_items` содержит заголовок, текст, владельца и время создания. Ограничения длины заданы одновременно в DTO и схеме базы.

Учебная учётная запись создаётся при первом старте. Пароль поступает из `APP_DEFAULT_PASSWORD`, хешируется и только после этого сохраняется в H2. Секрет JWT поступает из `JWT_SECRET`; он не включён в репозиторий.

= Реализация API

== Аутентификация: POST /auth/login

Метод принимает JSON с полями `username` и `password`. Bean Validation запрещает пустые и чрезмерно длинные значения. `AuthenticationManager` передаёт данные в `DaoAuthenticationProvider`, который получает хеш пользователя через JPA и сравнивает его с введённым паролем с помощью BCrypt.

Пример запроса:

```bash
curl -X POST http://localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"student","password":"StrongPassword123!"}'
```

Успешный ответ:

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresInSeconds": 900
}
```

При неверной паре логин-пароль возвращается статус `401 Unauthorized` с нейтральным сообщением. Оно не позволяет определить, существовал ли пользователь.

== Получение данных: GET /api/data

Метод доступен только с заголовком `Authorization: Bearer <token>`. Репозиторий возвращает записи в порядке убывания времени создания. Перед сериализацией все пользовательские строки экранируются.

```bash
curl http://localhost:8080/api/data \
  -H "Authorization: Bearer $TOKEN"
```

Запрос без токена получает `401`:

```json
{
  "status": 401,
  "error": "Authentication is required",
  "details": {}
}
```

== Создание данных: POST /api/data

Третий метод создаёт запись от имени аутентифицированного пользователя. Имя владельца берётся из `Authentication`, а не из тела запроса, поэтому клиент не может подменить автора.

```bash
curl -X POST http://localhost:8080/api/data \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Новая запись","content":"Содержимое"}'
```

При успехе возвращается `201 Created`. Заголовок ограничен 100 символами, содержимое - 500 символами.

= Реализованные меры защиты

== Защита от SQL-инъекций

Приложение не формирует SQL путём конкатенации строк. Для доступа к данным используется Spring Data JPA:

```java
Optional<AppUser> findByUsername(String username);
List<DataItem> findAllByOrderByCreatedAtDesc();
```

Hibernate связывает значения с параметрами подготовленного выражения. Строка пользователя не становится частью синтаксиса SQL. Отдельный интеграционный тест передаёт имя пользователя `' OR '1'='1` и ожидает `401`, что подтверждает невозможность обхода входа классической SQLi-нагрузкой.

== Защита от XSS

REST API возвращает JSON, но текст может позднее попасть в HTML-интерфейс. Поэтому поля `title`, `content` и `owner` централизованно экранируются при создании `DataResponse`:

```java
HtmlUtils.htmlEscape(item.getTitle());
HtmlUtils.htmlEscape(item.getContent());
HtmlUtils.htmlEscape(item.getOwner());
```

Тег `<script>` преобразуется в `&lt;script&gt;`. Дополнительно Spring Security задаёт `X-Content-Type-Options: nosniff`, запрещает встраивание во frame и возвращает CSP `default-src 'none'; frame-ancestors 'none'`.

== Защита аутентификации

Пароль кодируется `BCryptPasswordEncoder(12)`. BCrypt автоматически генерирует уникальную соль и использует регулируемую стоимость. Даже одинаковые пароли имеют разные хеши.

JWT создаётся после успешной проверки учётных данных. В него включены:

+ `sub` - имя пользователя;
+ `iss` - идентификатор сервера `secure-rest-api`;
+ `iat` - время выдачи;
+ `exp` - время окончания действия через 15 минут.

Подпись формируется HMAC-SHA-256 с секретом не менее 256 бит. `JwtAuthenticationFilter` проверяет подпись, `iss`, `exp` и наличие пользователя. Сервер работает без HTTP-сессий (`STATELESS`). Повреждённый или просроченный токен приводит к `401`.

== Broken Access Control и дополнительные меры

Все методы, кроме `/auth/login` и системного `/error`, требуют аутентификацию. Имя владельца записи определяется сервером. Ошибки не раскрывают stack trace. Входные DTO имеют ограничения размера. Секреты, база H2, логи и сборочные файлы исключены через `.gitignore`.

CSRF отключён осознанно: приложение не использует cookie для аутентификации, а Bearer-токен передаётся клиентом в заголовке Authorization. Если в будущем токен будет храниться в cookie, защиту CSRF потребуется включить. Для защиты цепочки сборки Maven Wrapper проверяет SHA-256 архива Maven, а `setup-java` проверяет подпись дистрибутива JDK в CI.

= Тестирование

Интеграционные тесты запускают полный Spring Context и отправляют запросы через MockMvc. Используется отдельная H2 in-memory база и тестовый секрет JWT.

#table(
  columns: (8%, 57%, 35%),
  inset: 5pt,
  stroke: 0.5pt,
  table.header([*№*], [*Проверка*], [*Ожидаемый результат*]),
  [1], [Корректный логин и пароль], [`200`, JWT, срок 900 секунд],
  [2], [GET без Authorization], [`401 Unauthorized`],
  [3], [GET с действующим JWT], [`200`, массив данных],
  [4], [SQLi в поле username], [`401`, вход не выполнен],
  [5], [POST с тегом `<script>`], [`201`, HTML экранирован],
  [6], [Значение пароля в БД], [BCrypt-хеш, не открытый пароль],
  [7], [Повреждённый Bearer-токен], [`401`, токен отклонён],
  [8], [Заголовок длиннее 100 символов], [`400`, ошибка валидации],
)

Результат локального запуска:

```text
Tests run: 8, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

Дополнительно приложение проверено вручную последовательностью `curl`: получен JWT, доступ без токена запрещён, с токеном разрешён, новая запись создаётся со статусом 201.

#pagebreak()
= CI/CD и анализ безопасности

Workflow `.github/workflows/ci.yml` запускается на события `push` и `pull_request`. Разрешения workflow ограничены чтением содержимого репозитория. Секрет NVD, если он настроен, поступает через GitHub Secrets.

== SAST: SpotBugs

Задание `Tests and SAST (SpotBugs)` выполняет сборку, тесты, `spotbugs:spotbugs` и `spotbugs:check`. Порог `Medium` делает замечания среднего и высокого уровня блокирующими. HTML/XML-отчёты публикуются как GitHub Actions artifacts даже при ошибке.

Первый прогон обнаружил четыре предупреждения о возможной передаче изменяемых объектов наружу. Реализация была исправлена защитным копированием `Map` и `ObjectMapper`. Повторный запуск завершился результатом `BugInstance size is 0`, `Error size is 0`.

#figure(
  image("/docs/images/sast-spotbugs.png", width: 100%),
  caption: [Отчёт SpotBugs после исправления замечаний],
)

== SCA: OWASP Dependency-Check

Отдельное задание `SCA (OWASP Dependency-Check)` анализирует прямые и транзитивные зависимости. Сборка блокируется при обнаружении уязвимости с CVSS 7.0 и выше. База NVD кэшируется между запусками; для полного обновления обязателен repository secret `NVD_API_KEY`. Если секрет отсутствует, workflow завершается с понятной ошибкой, а неполная база не выдаётся за успешный аудит. HTML и JSON публикуются как artifacts.

Первый SCA-прогон выявил CVE-2026-34477 и CVE-2026-34479 в транзитивной зависимости `log4j-api 2.24.3`, управляемой Spring Boot. В соответствии с рекомендацией Apache Logging Services Log4j BOM обновлён до 2.26.1; повторный анализ не обнаружил уязвимых зависимостей выше установленного порога.

Локальный контрольный запуск выполнен по кэшированному снимку NVD и сохранён в HTML/JSON. Для итогового запуска GitHub Actions требуется `NVD_API_KEY`, после чего снимок успешных заданий из раздела Actions добавляется к материалам сдачи.

#figure(
  image("/docs/images/sca-dependency-check.png", width: 100%),
  caption: [Отчёт OWASP Dependency-Check],
)

Разделение SAST и SCA на два задания позволяет выполнять их параллельно и сразу понимать, связана ли ошибка с собственным кодом или со сторонней библиотекой.

= Заключение

В ходе работы создан защищённый REST API на Java 21 и Spring Boot. Реализованы три метода, JWT-аутентификация, BCrypt-хеширование, параметризованный доступ к данным через JPA и экранирование пользовательского содержимого. Защищённые маршруты возвращают 401 без действующего токена.

Настроен GitHub Actions pipeline, запускающий восемь интеграционных тестов, SpotBugs и OWASP Dependency-Check на каждый push и pull request. Статический анализ помог выявить и устранить четыре замечания о работе с изменяемыми объектами. Итоговая сборка и SAST завершаются успешно.

= Источники

1. OWASP Top 10. `https://owasp.org/www-project-top-ten/`.
2. OWASP Cheat Sheet Series. `https://cheatsheetseries.owasp.org/`.
3. JSON Web Token Introduction. `https://www.jwt.io/introduction`.
4. Spring Security Reference. `https://docs.spring.io/spring-security/reference/`.
5. GitHub Actions Documentation. `https://docs.github.com/actions`.
6. SpotBugs Maven Plugin. `https://spotbugs.github.io/spotbugs-maven-plugin/`.
7. OWASP Dependency-Check. `https://dependency-check.github.io/DependencyCheck/`.
8. Apache Logging Services Security. `https://logging.apache.org/security.html`.
