# Stark Tech Spider-Man HUD (Визор Человека-Паука)

Проект создания аутентичного кибер-интерфейса (Heads-Up Display) шлема Человека-Паука в стиле Stark Tech из фильмов Marvel.

---

## 🚀 1. Быстрый запуск на ПК прямо сейчас (Python Preview)

Чтобы прямо сейчас увидеть живой интерфейс на экране монитора со всеми анимациями:

```bash
python hud_preview.py
```

### Управление в симуляторе:
* **ЛКМ / Клавиша `Q`:** Выстрел левым веб-шутером (расход полимера).
* **ПКМ / Клавиша `E`:** Выстрел правым веб-шутером.
* **Стрелки `←` / `→`:** Вращение компаса (улицы Квинса на мини-карте поворачиваются в реальном времени).
* **Движение мыши:** Динамический тактический прицел визора.
* **Пробел:** Включение режима захвата цели (`TARGET: LOCKED`).

---

## 🦀 2. Сборка на Rust (Для Raspberry Pi и Windows)

Проект написан на **Rust** с использованием ультралёгкого движка `macroquad` (чистый Rust, без тяжёлых C-зависимостей).

### Локальный запуск на Windows:
```bash
cargo run --release
```

### Кросс-компиляция для Raspberry Pi Zero 2 W / Pi 4/5 (64-bit Linux):
```bash
# 1. Установка кросс-таргета для Raspberry Pi (ARM64)
rustup target add aarch64-unknown-linux-gnu

# 2. Сборка через утилиту cross:
cross build --target aarch64-unknown-linux-gnu --release
```
Готовый бинарный файл копируется на Raspberry Pi и запускается прямо в полноэкранный режим HDMI визора без X11!

---

## 📁 Структура проекта
* [Cargo.toml](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/Cargo.toml) — Конфигурация зависимостей Rust.
* [src/main.rs](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/src/main.rs) — Полная реализация визора на Rust.
* [hud_preview.py](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/hud_preview.py) — Мгновенный интерактивный симулятор на Python (без внешних библиотек).
