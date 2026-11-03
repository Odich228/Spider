#!/usr/bin/env python3
"""
STARK TECH SPIDER-MAN HUD // HEAD TRACKING IMU READER (MPU-6050 / BNO-055)
==========================================================================
Считывает данные с физического гироскопа/акселерометра MPU-6050 по шине I2C
и отправляет угол поворота и наклон головы в визор (127.0.0.1:9099).

Подключение к Raspberry Pi:
  VCC -> 3.3V (Pin 1)
  GND -> GND  (Pin 6 или 9)
  SDA -> GPIO 2 / SDA1 (Pin 3)
  SCL -> GPIO 3 / SCL1 (Pin 5)
"""

import sys
import time
import math
import socket

HUD_HOST = "127.0.0.1"
HUD_PORT = 9099
MPU6050_ADDR = 0x68

# Регистры MPU-6050
PWR_MGMT_1   = 0x6B
ACCEL_XOUT_H = 0x3B
GYRO_XOUT_H  = 0x43

def send_to_hud(sock, msg: str):
    try:
        sock.sendto(msg.encode("utf-8"), (HUD_HOST, HUD_PORT))
    except Exception:
        pass

def read_word_2c(bus, reg):
    high = bus.read_byte_data(MPU6050_ADDR, reg)
    low = bus.read_byte_data(MPU6050_ADDR, reg + 1)
    val = (high << 8) + low
    if val >= 0x8000:
        return -((65535 - val) + 1)
    return val

def run_hardware_mpu():
    try:
        import smbus2 as smbus
    except ImportError:
        try:
            import smbus
        except ImportError:
            print("\x1b[31m[IMU] Библиотека smbus/smbus2 не найдена. Установите: sudo apt install python3-smbus2\x1b[0m")
            return False

    try:
        bus = smbus.SMBus(1)
        # Пробуждаем MPU-6050 (сбрасываем бит sleep)
        bus.write_byte_data(MPU6050_ADDR, PWR_MGMT_1, 0)
        print("\x1b[32m[IMU] Датчик MPU-6050 обнаружен по адресу 0x68 на I2C-1!\x1b[0m")
    except Exception as e:
        print(f"\x1b[33m[IMU] Не удалось подключиться к MPU-6050: {e}\x1b[0m")
        return False

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    pitch = 0.0
    roll = 0.0
    yaw = 0.0
    last_time = time.time()

    print("\x1b[32m[IMU] Поток трекинга головы активен. Вращайте шлем!\x1b[0m")

    while True:
        try:
            now = time.time()
            dt = max(now - last_time, 0.001)
            last_time = now

            # Чтение акселерометра (шкала +-2g: 16384 LSB/g)
            ax = read_word_2c(bus, ACCEL_XOUT_H) / 16384.0
            ay = read_word_2c(bus, ACCEL_XOUT_H + 2) / 16384.0
            az = read_word_2c(bus, ACCEL_XOUT_H + 4) / 16384.0

            # Чтение гироскопа (шкала +-250 deg/s: 131 LSB/(deg/s))
            gx = read_word_2c(bus, GYRO_XOUT_H) / 131.0
            gy = read_word_2c(bus, GYRO_XOUT_H + 2) / 131.0
            gz = read_word_2c(bus, GYRO_XOUT_H + 4) / 131.0

            # Расчёт углов наклона по акселерометру
            accel_pitch = math.degrees(math.atan2(-ax, math.sqrt(ay * ay + az * az)))
            accel_roll = math.degrees(math.atan2(ay, az))

            # Комплементарный фильтр (Fusion)
            pitch = 0.95 * (pitch + gy * dt) + 0.05 * accel_pitch
            roll = 0.95 * (roll + gx * dt) + 0.05 * accel_roll
            yaw = (yaw - gz * dt).rem_euclid(360.0)

            # Отправка в HUD
            send_to_hud(sock, f"IMU|{yaw:.1f}|{pitch:.1f}|{roll:.1f}")

            time.sleep(0.016) # ~60 Hz
        except Exception as e:
            print(f"[IMU-ERR] Ошибка чтения I2C: {e}")
            time.sleep(0.5)

def run_simulation():
    """Тестовый симулятор для ПК / WSL (плавное покачивание головы)"""
    print("\x1b[36m[IMU-SIM] Запуск режима симуляции гироскопа головы...\x1b[0m")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    t = 0.0
    while True:
        t += 0.02
        yaw = ((t * 25.0) % 360.0)
        pitch = math.sin(t * 1.5) * 12.0 # наклон вверх/вниз +-12 градусов
        roll = math.sin(t * 0.8) * 8.0   # наклон влево/вправо +-8 градусов
        send_to_hud(sock, f"IMU|{yaw:.1f}|{pitch:.1f}|{roll:.1f}")
        time.sleep(0.02)

if __name__ == "__main__":
    if "--sim" in sys.argv or "--test" in sys.argv:
        run_simulation()
    else:
        success = run_hardware_mpu()
        if not success:
            print("\x1b[33m[IMU] Аппаратный I2C недоступен. Переключаемся на симулятор (--sim)...\x1b[0m")
            run_simulation()
