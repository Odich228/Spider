# Stark Tech Spider-Man HUD (Шлем Человека-Паука)

Проект создания аутентичного кибер-интерфейса (Heads-Up Display) шлема Человека-Паука в стиле Stark Tech из фильмов Marvel для оптических Micro-OLED визоров и микрокомпьютера Raspberry Pi с **реальным подключением к смартфону по Bluetooth**.

---

## ✨ Возможности системы

1. **Реальное подключение к смартфону по Bluetooth (Real BT Link):**
   * **Всплывающие уведомления:** Входящие сообщения (Telegram, WhatsApp, SMS, имя звонящего) плавно выезжают сверху на полупрозрачной голографической плашке.
   * **Визор-медиаплеер:** Отображение реального названия трека и исполнителя, играющего на смартфоне, и динамический 12-полосный кибер-эквалайзер.
   * **Статус связи:** Имя сопряжённого телефона, уровень сигнала и заряд батареи смартфона в верхнем левом блоке телеметрии.
2. **Кинематографичная стартовая анимация (Stark Boot Sequence):**
   * Калибровка механических линз маски Питера Паркера (глаза сужаются и фокусируются).
   * Лазерная проекция тактической паутины и угловатой эмблемы Паука Stark Industries.
   * Инициализация ИИ Карен и диагностика систем костюма.
3. **Реальное «Паучье чутьё» (Spider-Sense Danger Warning):**
   * Вспыхивающие зазубренные энергетические молнии по углам периметра визора и предупреждающий баннер об угрозе.
4. **Биометрия костюма (Live ECG & Pulse):**
   * Пульс в BPM (ускоряется при беге или принимается с реального пульсометра/часов по Bluetooth).
   * Бегущая линия электрокардиограммы (P-Q-R-S-T) в реальном времени.
5. **Радар авиации в небе (Live ADS-B Radar):**
   * Отслеживание пролетающих над головой самолётов с позывными рейсов (AFL, S7) и эшелоном высоты прямо на мини-карте.
6. **Реальная карта OpenStreetMap:**
   * Автоопределение города по IP/GPS и процедурная инверсия спутниковых дорог в ночной Stark-стиль.
   * Улицы скользят под взглядом при ходьбе, компас поворачивает радар.
7. **Голосовой диалог с «Карен»:**
   * Визуализатор голосовой волны и реплики бортового ассистента.

---

## 🎮 Управление клавишами в симуляторе

| Клавиша | Действие |
|---|---|
| **`W` / `S`** | Шаг вперёд / назад (спидометр до `5.4 km/h`, карта скользит) |
| **`Shift + W`** | Спринт на скорости `24.0 km/h` (пульс разгоняется) |
| **`A` / `D`** | Поворот головы / компаса (радар поворачивается по азимуту) |
| **`P`** | Активация **«Паучьего чутья»** (Spider-Sense) |
| **`N`** | Тест **уведомления со смартфона** (Telegram / Tony Stark) |
| **`M`** | Пауза / Возобновление **медиаплеера** |
| **`K`** | Диалог с **ИИ Карен** (Karen AI voice waveform) |
| **`R`** | Перезагрузка системы (повтор стартовой анимации) |

---

## 📱 Реальное подключение смартфона по Bluetooth

Визор слушает локальный порт `127.0.0.1:9099 (UDP)` и автоматически принимает события от Bluetooth-демона.

### Способ 1: Сопряжение со смартфоном через Bluetooth Serial (RFCOMM / SPP)

1. На Raspberry Pi запустите скрипт первичной настройки (один раз):
   ```bash
   chmod +x scripts/setup_bluetooth.sh
   ./scripts/setup_bluetooth.sh
   ```
2. Включите Bluetooth на вашем телефоне (Android или iPhone) и подключитесь к устройству **`STARK-SPIDER-HUD`**.
3. Запустите Bluetooth-демон:
   ```bash
   python3 scripts/spider_bt_daemon.py
   ```
4. На смартфоне установите любое бесплатное приложение для Bluetooth-терминала (например, **Serial Bluetooth Terminal** из Google Play) или автоматизацию (MacroDroid / Tasker / KDE Connect):
   * Отправьте сообщение: `notif:Telegram:Aunt May:Peter, where are you?!` — оно тут же всплывёт на визоре!
   * Отправьте трек: `track:Sunflower:Post Malone:play` — заиграет эквалайзер!
   * Отправьте пульс: `hr:125` — изменится частота ЭКГ!
   * Отправьте тревогу: `sense:1:DANGER: PROXIMITY ALERT` — сработает Паучье чутьё!

### Способ 2: Автоматическое чтение музыки с телефона через BlueZ MPRIS
Если вы подключили смартфон к Raspberry Pi как Bluetooth-гарнитуру/колонку (A2DP Audio Sink), то при воспроизведении музыки в Spotify, Apple Music или YouTube на телефоне, визор **автоматически** читает название песни и имя артиста через Linux BlueZ / `playerctl` без каких-либо приложений на телефоне!

### Способ 3: Интерактивная консоль тестирования
Вы можете тестировать любые сообщения прямо с клавиатуры через консоль демона:
```bash
python3 scripts/spider_bt_daemon.py
```
Команды в консоли:
```text
stark-hud> notif Telegram "Ned Leeds" "Did you bring the suit?"
stark-hud> media "Sunflower" "Post Malone" play
stark-hud> hr 118
stark-hud> sense on "SNIPER LASER LOCK"
stark-hud> karen "Peter, two drones detected behind the billboard."
stark-hud> status on "Ilya's iPhone 15" 89
```

---

## 🚀 Сборка и запуск

### Зависимости (для Linux / Raspberry Pi OS):
```bash
sudo apt update && sudo apt install -y build-essential pkg-config libx11-dev libxi-dev libgl1-mesa-dev libasound2-dev curl bluez bluez-tools playerctl python3
```

### Запуск визора:
```bash
cargo run --release
```

---

## 📁 Структура проекта
* [src/main.rs](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/src/main.rs) — Полный высокопроизводительный движок HUD на Rust (OSM карта, Bluetooth-ресивер, ЭКГ, радар ADS-B, Spider-Sense).
* [scripts/spider_bt_daemon.py](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/scripts/spider_bt_daemon.py) — Bluetooth & Telemetry Daemon (RFCOMM, BlueZ MPRIS, CLI).
* [scripts/setup_bluetooth.sh](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/scripts/setup_bluetooth.sh) — Скрипт конфигурации Bluetooth и прав в Linux.
* [font.ttf](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/font.ttf) — Векторный шрифт *Share Tech Mono*.
