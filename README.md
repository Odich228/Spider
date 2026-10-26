# Паутина / Spider

Читалка комиксов для Windows, macOS, Android и iOS на Flutter. Репозиторий: [Odich228/Spider](https://github.com/Odich228/Spider).

## Первая рабочая версия

- Тёмный адаптивный интерфейс: библиотека, серии, коллекции, хронология и профиль.
- Импорт CBZ/ZIP, CBT/TAR, PDF, JPG, PNG и WebP. Файлы копируются в управляемую библиотеку приложения.
- Чтение с масштабированием, клавишами ←/→, переходом к странице и сохранением прогресса.
- Несколько серий в коллекции; одна серия может входить в разные коллекции. Свой порядок выпусков сохраняется отдельно для каждой коллекции.
- Замена и восстановление обложки; оригинальный комикс не меняется.
- SQLite/Drift, очередь изменений, раздельные библиотеки аккаунтов.
- В сборке с подключённым Supabase: email/пароль, синхронизация метаданных, прогресса и пользовательских обложек; конфликты решает пользователь.
- GitHub Actions: проверки и четыре сборки на каждый push в `main`, затем общий GitHub Release.

CBR/RAR, CB7/7z и EPUB пока не реализованы. Для них выделена граница декодера; приложение не выдаёт их за поддержанные форматы. Исходные файлы комиксов пока не переносятся через облако: на другом устройстве добавьте тот же файл, и он получит тот же идентификатор по SHA-256.

## Запуск

Версия Flutter закреплена в `pubspec.yaml`: **3.47.7**, Dart **3.13.5**. `pubspec.lock` хранится в Git.

```sh
flutter pub get --enforce-lockfile
flutter run -d windows
# На Mac:
flutter run -d macos
# Подключённый телефон / симулятор:
flutter devices
flutter run -d <device-id>
```

Без настроек сервера приложение работает локально. Демонстрационные обложки и страница открываются только по явной кнопке «Посмотреть демонстрационную библиотеку».

## Подключение аккаунтов и облака

1. Создайте проект Supabase и примените `supabase/migrations/202610260001_library.sql` через SQL Editor или Supabase CLI.
2. Включите email/password в Supabase Auth. Если включено подтверждение почты, после подтверждения вернитесь в приложение и войдите паролем.
3. Передайте URL и **publishable/anon client key** при сборке:

```sh
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

В GitHub эти два значения задаются как Repository Variables `SUPABASE_URL`, `SUPABASE_ANON_KEY`. Ключ `service_role` в клиент не передаётся. При входе открывается библиотека аккаунта; гостевая библиотека сохраняется отдельно на устройстве.

## Проверки

```sh
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
python -m unittest discover -s tool/ci/tests -v
```

Проверки PostgreSQL/RLS/CAS отдельно выполняются в CI на PostgreSQL 17. `tool/sql/test_bootstrap.sql` предназначен только для тестового пустого PostgreSQL, не для вашего Supabase.

## Документация

- [Архитектура и протокол синхронизации](docs/architecture.md)
- [CI/CD, артефакты и секреты подписи](docs/ci-cd.md)
- [Следующие этапы](docs/roadmap.md)

Релизы из `main` пока помечаются как prerelease. Без Apple signing secrets iOS-артефакт — неподписанный `.app.zip`, который нельзя установить на iPhone. Подключение сертификата и профиля переключает CI на подписанный IPA.
