#!/usr/bin/env bash
# ==============================================================================
# НАСТРОЙКА BLUETOOTH ДЛЯ ШЛЕМА ЧЕЛОВЕКА-ПАУКА (RASPBERRY PI / LINUX)
# ==============================================================================

set -e

echo -e "\x1b[36m[STARK TECH] Настройка Bluetooth для Stark HUD...\x1b[0m"

# 1. Установка необходимых системных пакетов
sudo apt-get update
sudo apt-get install -y bluez bluez-tools playerctl python3-pip

# 2. Включение службы Bluetooth
sudo systemctl enable --now bluetooth

# 3. Настройка имени шлема и видимости
echo -e "\x1b[36m[STARK TECH] Назначение имени устройства: STARK-SPIDER-HUD\x1b[0m"
bluetoothctl system-alias "STARK-SPIDER-HUD"
bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl pairable on

# 4. Регистрация Serial Port Profile (SPP) для подключения смартфонов
if command -v sdptool &> /dev/null; then
    sudo sdptool add SP || true
fi

echo -e "\x1b[32m[STARK TECH] Bluetooth настроен и готов к сопряжению!\x1b[0m"
echo -e "\x1b[33mДля подключения со смартфона:\x1b[0m"
echo -e "1. Включите Bluetooth на телефоне и найдите 'STARK-SPIDER-HUD'."
echo -e "2. Выполните сопряжение (Pair)."
echo -e "3. Запустите HUD: cargo run --release"
echo -e "4. Запустите демон: python3 scripts/spider_bt_daemon.py"
