# GitHub Actions и выпуск

Workflow: `.github/workflows/release.yml`. Push в `main` и ручной запуск запускают проверки, затем Android/Windows/macOS/iOS параллельно. Pull request в `main` запускает анализ, тесты и проверку базы без доступа к signing secrets и публикации релиза.

## Порядок

1. Закреплённый Flutter, `pub get --enforce-lockfile`, форматирование, проверка генерируемой Drift-схемы, анализ, Flutter-тесты и Python-тесты упаковки.
2. Отдельный PostgreSQL 17 проверяет настоящую миграцию: владельцев, RLS, конфликты и идемпотентный повтор.
3. Четыре runner: Ubuntu 24.04 (Android), Windows 2022, два macOS 15 (macOS и iOS).
4. Каждая сборка создаёт бинарники и `manifest-<platform>.json` с версией, SHA коммита, номером и SHA-256 файлов.
5. Публикующий job принимает только полный согласованный набор четырёх платформ. Создаёт draft, загружает все файлы и лишь затем публикует prerelease. Права `contents: write` выданы только этому job.

Тег: `v0.2.0-build.<github.run_number>`. Номер сборки берётся из workflow run; исходная версия — из `pubspec.yaml`. Повторный запуск не перезаписывает уже опубликованный релиз, но может закончить незавершённый draft. Обновление версии SDK и библиотек выполняется отдельным коммитом вместе с lockfile.

## Артефакты

| Платформа | Без signing secrets | После настройки |
|---|---|---|
| Windows | Portable ZIP со всеми DLL и данными, без Authenticode | Authenticode с временной меткой |
| Android | Release-mode APK с тестовой debug-подписью, имя `debug-key-preview` | APK и AAB с постоянным upload key |
| macOS | `.app.zip`, ad-hoc, без notarization | Developer ID и, при наличии notary key, notarization |
| iOS | `UNSIGNED.app.zip`, не устанавливается на iPhone | Подписанный IPA, тип экспорта определяется provisioning profile |

Для распространения iOS через GitHub на зарегистрированные устройства нужен профиль Ad Hoc / release-testing с UDID этих устройств. App Store profile создаёт IPA для загрузки в App Store Connect; сам GitHub Release не заменяет TestFlight. Публикация в магазины не включена.

## Repository Variables

Settings → Secrets and variables → Actions → Variables:

| Имя | Значение |
|---|---|
| `SUPABASE_URL` | URL проекта Supabase |
| `SUPABASE_ANON_KEY` | Publishable/anon **клиентский** ключ, не service_role |
| `IOS_EXPORT_METHOD` | Необязательно: `release-testing`, `app-store-connect`, `enterprise` |

Первые два значения задаются вместе. Если они отсутствуют, все четыре приложения собираются с локальным режимом и понятным экраном неподключённого облака.

## Android Secrets

В Odich228/Spider постоянный ключ создан и четыре секрета настроены. Приватная резервная копия передана владельцу отдельно от репозитория. Последующие сборки используют этот же ключ; новая подпись отличается от прежних debug-preview.

Settings → Secrets and variables → Actions → Secrets:

- `ANDROID_KEYSTORE_BASE64` — содержимое постоянного upload `.jks` в Base64;
- `ANDROID_KEYSTORE_PASSWORD`;
- `ANDROID_KEY_ALIAS`;
- `ANDROID_KEY_PASSWORD`.

Группа задаётся полностью. Частичная настройка завершит job ошибкой. Временные `android/app/ci-upload.jks` и `android/key.properties` удаляются после сборки и исключены из Git. Без группы используется только preview с тестовой подписью: обновление поверх предыдущего CI-preview может потребовать удаления приложения, поскольку ключ runner не постоянный.

## iOS Secrets

- `IOS_CERTIFICATE_BASE64` — экспортированный Apple Distribution `.p12`, включая закрытый ключ;
- `IOS_CERTIFICATE_PASSWORD` — пароль этого `.p12` (может быть пустым, если сертификат экспортирован без пароля);
- `IOS_PROVISION_PROFILE_BASE64` — соответствующий `.mobileprovision` для приложения.

Сертификат и профиль нужны вместе. CI создаёт временный keychain, устанавливает профиль, получает Team ID и Bundle ID из него и формирует export options. После сборки восстанавливает Xcode-конфигурацию и список keychain, удаляет только созданные временные файлы. Содержимое секретов в лог не выводится.

По умолчанию Bundle ID проекта — `io.pautina.pautina`. Для своего зарегистрированного идентификатора измените нативные конфигурации и профиль. Signing script использует явный Bundle ID профиля для release-сборки iOS.

## Первая настройка GitHub

В репозитории должны быть включены Actions. Политика организации должна разрешать используемые Actions и запись `GITHUB_TOKEN` в releases. Отдельный PAT для публикации не требуется. Все внешние Actions закреплены полными SHA; Dependabot предлагает их обновления.

При ошибке любой сборки общий релиз не публикуется. Логи и успешные промежуточные артефакты остаются в Actions на 14 дней. Контрольные суммы опубликованы в `SHA256SUMS.txt`.

## Windows Authenticode

`WINDOWS_CERTIFICATE_BASE64` — экспортируемый PFX сертификат с закрытым ключом; `WINDOWS_CERTIFICATE_PASSWORD` — пароль (допускается пустой). CI временно импортирует сертификат в CurrentUser/My, подписывает pautina.exe через signtool с SHA-256 и временной меткой DigiCert, проверяет подпись и удаляет только импортированный сертификат. Уже установленный сертификат с тем же thumbprint не заменяется. Аппаратные EV-ключи требуют отдельного провайдера и этим PFX-механизмом не поддерживаются.

## macOS Developer ID и notarization

- `MACOS_CERTIFICATE_BASE64`: Developer ID Application .p12 с закрытым ключом;
- `MACOS_CERTIFICATE_PASSWORD`: пароль .p12;
- `MACOS_NOTARY_KEY_BASE64`: App Store Connect API .p8 в Base64;
- `MACOS_NOTARY_KEY_ID`: ID этого ключа;
- `MACOS_NOTARY_ISSUER_ID`: issuer UUID.

Три NOTARY-значения нужны вместе. Developer ID используется во временном keychain, вложенные Mach-O и bundle подписываются с hardened runtime. notarytool ждёт Accepted; затем staple прикрепляет билет, и ZIP создаётся заново. Непринятая notarization останавливает выпуск. Без нотариальных ключей остаётся Developer ID-подпись без notarization; без сертификата выпускается ad-hoc preview.

macOS Release App Sandbox выключен для прямого GitHub-распространения и помощника обновлений. Это не конфигурация Mac App Store. Приватные ключи, PFX, P12 и P8 не коммитьте: используйте Secrets. Проверки подписанных путей требуют действительных сертификатов владельца; CI без них проверяет четыре preview-сборки.
