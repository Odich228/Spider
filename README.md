# Stark Tech Spider-Man HUD (Визор Человека-Паука)

Проект создания аутентичного кибер-интерфейса (Heads-Up Display) шлема Человека-Паука в стиле Stark Tech из фильмов Marvel для оптических Micro-OLED визоров и микрокомпьютера Raspberry Pi.

---

## ✨ Возможности
* **Реальная карта OpenStreetMap:** Автоматическое определение города по IP/GPS и загрузка настоящей спутниковой карты улиц с инверсией в фирменный ночной Stark-стиль (без платных API-ключей!).
* **Физическая навигация:** Улицы плавно скользят под взглядом при ходьбе, спидометр показывает реальную скорость, а компас вращает радар в сторону взгляда.
* **Векторный сглаженный шрифт:** Встроенный тактический шрифт *Share Tech Mono* с 8-кратным аппаратным сглаживанием MSAA.
* **Телеметрия костюма:** Батарея повербанка, высота, GPS-спутники, температура процессора.
* **Чистый центр визора:** Сверхтонкие авиационные риски горизонта не загораживают реальный мир.

---

## 🎮 Управление в симуляторе
* **`W` / `S` (или стрелки `↑` / `↓`):** Шаг вперёд / назад (спидометр разгоняется до `5.4 km/h`, карта скользит под ногами).
* **`Shift + W`:** Бег на скорости `24.0 km/h`.
* **`A` / `D` (или стрелки `←` / `→`):** Поворот головы / компаса (радар поворачивается по азимуту).

---

## 🚀 Запуск и сборка

### Системные пакеты (для Linux / Raspberry Pi OS):
```bash
sudo apt update && sudo apt install -y build-essential pkg-config libx11-dev libxi-dev libgl1-mesa-dev libasound2-dev curl
```

### Запуск проекта:
```bash
cargo run --release
```

---

## 📁 Структура проекта
* [src/main.rs](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/src/main.rs) — Полный исходный код HUD на Rust.
* [font.ttf](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/font.ttf) — Векторный тактический шрифт *Share Tech Mono*.
* [Cargo.toml](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/Cargo.toml) — Зависимости и конфигурация сборки.
* [hud_preview.py](file:///C:/Users/Ilya/.gemini/antigravity/worktrees/Spider/rust_cross_platform_compilation/hud_preview.py) — Автономный предпросмотр на Python/Tkinter.
