#!/usr/bin/env python3
"""
STARK TECH SPIDER-MAN HUD // BLUETOOTH & TELEMETRY DAEMON
=========================================================
Мост между смартфоном (Android / iOS) и визором шлема Человека-Паука.

Поддерживает:
1. RFCOMM Bluetooth Serial Server (SPP) - прямое подключение с телефона
2. BlueZ MPRIS Media Tracker - чтение названия треков из плеера телефона
3. Interactive CLI консоль - отправка тестовых команд и уведомлений в HUD
"""

import sys
import time
import socket
import json
import threading
import subprocess

HUD_HOST = "127.0.0.1"
HUD_PORT = 9099
BT_SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"

def send_to_hud(packet_str: str):
    """Отправка датаграммы в Rust HUD через локальный сокет"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(packet_str.encode("utf-8"), (HUD_HOST, HUD_PORT))
        sock.close()
    except Exception as e:
        print(f"[DAEMON-ERR] Ошибка отправки в HUD: {e}")

# -------------------------------------------------------------
# 1. СЕРВЕР BLUETOOTH SERIAL (RFCOMM / SPP)
# -------------------------------------------------------------
def run_rfcomm_server():
    """Запуск RFCOMM сервера для приема сообщений со смартфона по Bluetooth"""
    try:
        import bluetooth
    except ImportError:
        print("\x1b[33m[BT-DAEMON] Модуль pybluez не установлен. Прямой RFCOMM доступен через socket.\x1b[0m")
        # Попытка через стандартный socket.AF_BLUETOOTH на Linux
        try:
            server_sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            server_sock.bind(("", 1))
            server_sock.listen(1)
            print("\x1b[32m[BT-DAEMON] Bluetooth RFCOMM сервер ожидает подключения смартфона на канале 1...\x1b[0m")
            print("\x1b[36m[BT-DAEMON] Подключитесь со смартфона через 'Serial Bluetooth Terminal' к устройству STARK-SPIDER-HUD\x1b[0m")

            while True:
                client_sock, client_info = server_sock.accept()
                print(f"\x1b[32m[BT-DAEMON] Смартфон подключен: {client_info}\x1b[0m")
                send_to_hud("STATUS|1|PHONE CONNECTED|90")

                try:
                    while True:
                        data = client_sock.recv(1024)
                        if not data:
                            break
                        line = data.decode("utf-8", errors="ignore").strip()
                        if line:
                            print(f"[BT RECV] {line}")
                            handle_phone_message(line)
                except Exception as e:
                    print(f"[BT-DAEMON] Соединение разорвано: {e}")
                finally:
                    client_sock.close()
                    send_to_hud("STATUS|0|DISCONNECTED|0")
        except Exception as e:
            print(f"\x1b[33m[BT-DAEMON] Нативный RFCOMM сокет недоступен: {e}\x1b[0m")
            print("\x1b[36m[BT-DAEMON] Используется фоновый MPRIS трекер и интерактивная консоль.\x1b[0m")
        return

    # Если установлен pybluez
    try:
        server_sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        server_sock.bind(("", bluetooth.PORT_ANY))
        server_sock.listen(1)
        port = server_sock.getsockname()[1]

        bluetooth.advertise_service(
            server_sock,
            "StarkSpiderHUD",
            service_id=BT_SPP_UUID,
            service_classes=[BT_SPP_UUID, bluetooth.SERIAL_PORT_CLASS],
            profiles=[bluetooth.SERIAL_PORT_PROFILE],
        )

        print(f"\x1b[32m[BT-DAEMON] RFCOMM сервис зарегистрирован на канале {port}\x1b[0m")

        while True:
            client_sock, client_info = server_sock.accept()
            print(f"\x1b[32m[BT-DAEMON] Смартфон подключен: {client_info}\x1b[0m")
            send_to_hud("STATUS|1|SMARTPHONE|95")

            try:
                while True:
                    data = client_sock.recv(1024)
                    if not data:
                        break
                    line = data.decode("utf-8", errors="ignore").strip()
                    if line:
                        print(f"[BT RECV] {line}")
                        handle_phone_message(line)
            except Exception as e:
                print(f"[BT-DAEMON] Соединение разорвано: {e}")
            finally:
                client_sock.close()
                send_to_hud("STATUS|0|DISCONNECTED|0")
    except Exception as e:
        print(f"[BT-DAEMON] Ошибка запуска pybluez: {e}")

def handle_phone_message(msg: str):
    """Обработка команд и уведомлений от смартфона"""
    # Если пришел pipe формат или JSON - пересылаем напрямую
    if msg.startswith("NOTIF|") or msg.startswith("MEDIA|") or msg.startswith("HR|") or msg.startswith("STATUS|") or msg.startswith("{"):
        send_to_hud(msg)
        return

    # Удобные сокращения от Bluetooth терминала:
    # notif:Telegram:Peter:Hello!
    if ":" in msg:
        parts = msg.split(":", 3)
        cmd = parts[0].strip().lower()
        if cmd == "notif" and len(parts) >= 4:
            send_to_hud(f"NOTIF|{parts[1].strip()}|{parts[2].strip()}|{parts[3].strip()}")
            return
        elif cmd == "track" and len(parts) >= 3:
            status = parts[3].strip() if len(parts) > 3 else "PLAY"
            send_to_hud(f"MEDIA|{parts[1].strip()}|{parts[2].strip()}|{status}")
            return
        elif cmd in ("hr", "pulse") and len(parts) >= 2:
            send_to_hud(f"HR|{parts[1].strip()}")
            return
        elif cmd in ("sense", "danger") and len(parts) >= 2:
            send_to_hud(f"SENSE|1|{parts[1].strip()}")
            return

    # По умолчанию пересылаем как уведомление с телефона
    send_to_hud(f"NOTIF|BLUETOOTH|PHONE|{msg}")

# -------------------------------------------------------------
# 2. АВТОМАТИЧЕСКИЙ ТРЕКЕР МЕДИАПЛЕЕРА LINUX/BLUEZ (MPRIS)
# -------------------------------------------------------------
def run_mpris_tracker():
    """Следит за треками со смартфона при сопряжении по Bluetooth A2DP"""
    last_title = ""
    while True:
        try:
            res = subprocess.run(
                ["playerctl", "metadata", "--format", "{{status}}||{{artist}}||{{title}}"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            if res.returncode == 0 and res.stdout.strip():
                line = res.stdout.strip()
                if line != last_title:
                    parts = line.split("||")
                    if len(parts) >= 3:
                        status, artist, title = parts[0], parts[1], parts[2]
                        is_playing = "play" in status.lower()
                        send_to_hud(f"MEDIA|{title}|{artist}|{'PLAY' if is_playing else 'PAUSE'}")
                        last_title = line
        except Exception:
            pass
        time.sleep(1.2)

# -------------------------------------------------------------
# 3. ИНТЕРАКТИВНАЯ ТЕСТОВАЯ КОНСОЛЬ
# -------------------------------------------------------------
def run_cli_console():
    """Позволяет отправлять любые команды и сообщения в HUD прямо из терминала"""
    print("\n" + "="*60)
    print("STARK HUD // BLUETOOTH & TELEMETRY CONTROL CONSOLE")
    print("="*60)
    print("Команды:")
    print("  notif <app> <sender> <text>   - Всплывающее уведомление")
    print("  media <title> <artist> [play] - Название трека и эквалайзер")
    print("  hr <bpm>                      - Пульс и частота ЭКГ")
    print("  sense <1|0> [danger text]     - Паучье чутьё")
    print("  karen <text>                  - Голосовая реплика Карен")
    print("  status <1|0> <device> [bat]   - Статус сопряжения Bluetooth")
    print("  exit                          - Выход")
    print("="*60 + "\n")

    while True:
        try:
            line = input("\x1b[36mstark-hud>\x1b[0m ").strip()
            if not line:
                continue
            if line.lower() in ("exit", "quit"):
                break

            parts = line.split(maxsplit=3)
            cmd = parts[0].lower()

            if cmd == "notif" and len(parts) >= 4:
                app, sender, text = parts[1], parts[2], parts[3]
                send_to_hud(f"NOTIF|{app}|{sender}|{text}")
                print(f"[SENT] Уведомление от {sender} ({app})")
            elif cmd == "media" and len(parts) >= 3:
                title, artist = parts[1], parts[2]
                status = parts[3] if len(parts) > 3 else "PLAY"
                send_to_hud(f"MEDIA|{title}|{artist}|{status}")
                print(f"[SENT] Трек: {artist} - {title}")
            elif cmd == "hr" and len(parts) >= 2:
                send_to_hud(f"HR|{parts[1]}")
                print(f"[SENT] Пульс: {parts[1]} BPM")
            elif cmd == "sense":
                active = parts[1] if len(parts) > 1 else "1"
                text = parts[2] if len(parts) > 2 else "<! DANGER: HIGH THREAT DETECTED !>"
                send_to_hud(f"SENSE|{active}|{text}")
                print(f"[SENT] Паучье чутьё: {active}")
            elif cmd == "karen" and len(parts) >= 2:
                msg = line[len(cmd):].strip()
                send_to_hud(f"KAREN|{msg}")
                print(f"[SENT] Карен: {msg}")
            elif cmd == "status" and len(parts) >= 3:
                conn, dev = parts[1], parts[2]
                bat = parts[3] if len(parts) > 3 else "85"
                send_to_hud(f"STATUS|{conn}|{dev}|{bat}")
                print(f"[SENT] Bluetooth статус: {dev} ({bat}%)")
            else:
                # Если введен произвольный текст
                send_to_hud(f"NOTIF|TELEGRAM|TONY STARK|{line}")
                print(f"[SENT] Произвольное уведомление: {line}")
        except (KeyboardInterrupt, EOFError):
            break

def main():
    # Запуск фонового MPRIS трекера
    t_mpris = threading.Thread(target=run_mpris_tracker, daemon=True)
    t_mpris.start()

    # Запуск фонового RFCOMM Bluetooth сервера
    t_rfcomm = threading.Thread(target=run_rfcomm_server, daemon=True)
    t_rfcomm.start()

    # Приветственный статус в HUD
    send_to_hud("STATUS|1|BLUETOOTH READY|100")

    # Запуск интерактивной консоли
    run_cli_console()

if __name__ == "__main__":
    main()
