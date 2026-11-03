"""
Stark Tech Spider-Man HUD Preview (Desktop Simulator)
Работает на чистом Python 3 без необходимости ставить сторонние библиотеки!

Управление:
- Q / ЛКМ: Выстрел левым веб-шутером (тратит полимер)
- E / ПКМ: Выстрел правым веб-шутером
- Стрелки Влево / Вправо или движение мыши: Поворот компаса и мини-карты улиц Квинса
- Пробел: Режим тактического захвата цели (Target Lock)
"""

import tkinter as tk
import math
import time

# Фирменная палитра Stark Industries
COLOR_BG = "#030609"
COLOR_CYAN = "#8FE0F0"
COLOR_DIM = "#2A4B5A"
COLOR_DARK = "#0D1B22"
COLOR_WHITE = "#F5FAFC"
COLOR_RED = "#F04444"
COLOR_GREEN = "#36E888"

class StarkHUDApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Stark Tech HUD — Spider-Man Visor [Live Preview]")
        self.root.geometry("1280x720")
        self.root.configure(bg=COLOR_BG)

        self.canvas = tk.Canvas(root, bg=COLOR_BG, highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Состояние системы
        self.web_left = 100.0
        self.web_right = 100.0
        self.shooting_left = False
        self.shooting_right = False
        self.heading_deg = 42.0
        self.scan_mode = False
        self.mouse_x = 640
        self.mouse_y = 360
        self.target_x = 640
        self.target_y = 360
        self.radar_tick = 0.0

        # Привязка клавиш и мыши
        self.root.bind("<Motion>", self.on_mouse_move)
        self.root.bind("<ButtonPress-1>", lambda e: self.set_shoot_left(True))
        self.root.bind("<ButtonRelease-1>", lambda e: self.set_shoot_left(False))
        self.root.bind("<ButtonPress-3>", lambda e: self.set_shoot_right(True))
        self.root.bind("<ButtonRelease-3>", lambda e: self.set_shoot_right(False))

        self.root.bind("<KeyPress-q>", lambda e: self.set_shoot_left(True))
        self.root.bind("<KeyRelease-q>", lambda e: self.set_shoot_left(False))
        self.root.bind("<KeyPress-e>", lambda e: self.set_shoot_right(True))
        self.root.bind("<KeyRelease-e>", lambda e: self.set_shoot_right(False))

        self.root.bind("<Left>", lambda e: self.rotate_heading(-8))
        self.root.bind("<Right>", lambda e: self.rotate_heading(8))
        self.root.bind("<space>", lambda e: self.toggle_scan())

        self.last_time = time.time()
        self.update_loop()

    def set_shoot_left(self, state):
        self.shooting_left = state

    def set_shoot_right(self, state):
        self.shooting_right = state

    def rotate_heading(self, delta):
        self.heading_deg = (self.heading_deg + delta) % 360

    def toggle_scan(self):
        self.scan_mode = not self.scan_mode

    def on_mouse_move(self, event):
        self.mouse_x = event.x
        self.mouse_y = event.y

    def draw_bracket(self, x, y, w, h, length=12, color=COLOR_CYAN, width=1):
        # Верхний левый
        self.canvas.create_line(x, y, x + length, y, fill=color, width=width)
        self.canvas.create_line(x, y, x, y + length, fill=color, width=width)
        # Верхний правый
        self.canvas.create_line(x + w, y, x + w - length, y, fill=color, width=width)
        self.canvas.create_line(x + w, y, x + w, y + length, fill=color, width=width)
        # Нижний левый
        self.canvas.create_line(x, y + h, x + length, y + h, fill=color, width=width)
        self.canvas.create_line(x, y + h, x, y + h - length, fill=color, width=width)
        # Нижний правый
        self.canvas.create_line(x + w, y + h, x + w - length, y + h, fill=color, width=width)
        self.canvas.create_line(x + w, y + h, x + w, y + h - length, fill=color, width=width)

    def draw_top_left(self):
        bx, by = 40, 35
        # Метаданные
        self.canvas.create_text(bx, by, text="[ 88 ]", fill=COLOR_DIM, font=("Courier", 11, "bold"), anchor="w")
        self.canvas.create_text(bx + 70, by, text="[ 16:9 ]", fill=COLOR_DIM, font=("Courier", 11, "bold"), anchor="w")
        self.canvas.create_text(bx + 155, by, text="[ RAW ]", fill=COLOR_DIM, font=("Courier", 11, "bold"), anchor="w")

        box_y = by + 20
        bw, bh = 200, 105
        self.draw_bracket(bx, box_y, bw, bh, length=14, color=COLOR_CYAN, width=2)

        self.canvas.create_text(bx + 15, box_y + 24, text="WIFI NET.", fill=COLOR_WHITE, font=("Courier", 13, "bold"), anchor="w")

        # Антенна
        ax, ay = bx + 165, box_y + 22
        for r in (5, 9, 13):
            self.canvas.create_arc(ax - r, ay - r, ax + r, ay + r, start=45, extent=90, style="arc", outline=COLOR_CYAN, width=1.5)
        self.canvas.create_oval(ax - 2, ay + 3, ax + 2, ay + 7, fill=COLOR_WHITE, outline="")

        self.canvas.create_text(bx + 15, box_y + 50, text="RDY 102", fill=COLOR_CYAN, font=("Courier", 11), anchor="w")
        self.canvas.create_text(bx + 15, box_y + 68, text="SEARCH RAD: 55.2", fill=COLOR_CYAN, font=("Courier", 10), anchor="w")

        self.canvas.create_text(bx + 15, box_y + 90, text="VPN CONN.", fill=COLOR_DIM, font=("Courier", 10), anchor="w")
        for i in range(5):
            bar_h = 4 + i * 3
            px = bx + 130 + i * 8
            py = box_y + 92 - bar_h
            self.canvas.create_rectangle(px, py, px + 5, box_y + 92, fill=COLOR_CYAN, outline="")

    def draw_top_right(self, w):
        mw, mh = 190, 160
        bx = w - mw - 45
        by = 35

        self.canvas.create_text(bx, by, text="LOCATION", fill=COLOR_DIM, font=("Courier", 10), anchor="w")
        self.canvas.create_text(bx, by + 18, text="QUEENS", fill=COLOR_WHITE, font=("Courier", 13, "bold"), anchor="w")
        self.canvas.create_text(bx, by + 34, text="NEW YORK", fill=COLOR_CYAN, font=("Courier", 11), anchor="w")

        box_y = by + 48
        self.canvas.create_rectangle(bx, box_y, bx + mw, box_y + mh, fill=COLOR_DARK, outline="")
        self.draw_bracket(bx, box_y, mw, mh, length=10, color=COLOR_CYAN, width=2)

        # Вращающаяся карта Квинса
        cx, cy = bx + mw / 2, box_y + mh / 2
        rad = math.radians(self.heading_deg)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)

        def rot(ox, oy):
            return cx + ox * cos_a - oy * sin_a, cy + ox * sin_a + oy * cos_a

        streets = [
            (-80, -35, 75, -25),
            (-70, 25, 80, 35),
            (-30, -70, -20, 70),
            (30, -70, 40, 70),
            (-60, -60, 50, 60),
            (-50, 50, 60, -50),
        ]
        for x1, y1, x2, y2 in streets:
            p1x, p1y = rot(x1, y1)
            p2x, p2y = rot(x2, y2)
            self.canvas.create_line(p1x, p1y, p2x, p2y, fill=COLOR_DIM, width=1.2)

        # Пульсирующий маркер Человека-Паука
        pulse = (math.sin(self.radar_tick * 4) * 0.5 + 0.5) * 6
        self.canvas.create_oval(cx - 3, cy - 3, cx + 3, cy + 3, fill=COLOR_WHITE, outline="")
        self.canvas.create_oval(cx - (7 + pulse), cy - (7 + pulse), cx + (7 + pulse), cy + (7 + pulse), outline=COLOR_CYAN, width=1.5)

        # Курсор направления
        tx, ty = rot(0, -18)
        self.canvas.create_line(cx, cy, tx, ty, fill=COLOR_WHITE, width=2.5)

        self.canvas.create_text(bx + 10, box_y + mh - 12, text=f"HDG: {int(self.heading_deg):03d}°", fill=COLOR_CYAN, font=("Courier", 10, "bold"), anchor="w")

    def draw_bottom_right(self, w, h):
        bx = w - 260
        by = h - 200

        self.draw_bracket(bx, by, 220, 70, length=10, color=COLOR_DIM, width=1.5)
        self.canvas.create_text(bx + 14, by + 20, text="WEB SYN.", fill=COLOR_WHITE, font=("Courier", 13, "bold"), anchor="w")
        self.canvas.create_text(bx + 14, by + 38, text="POLYMER 04", fill=COLOR_CYAN, font=("Courier", 11), anchor="w")
        self.canvas.create_text(bx + 14, by + 54, text=f"L: {self.web_left*4.5:.1f} / R: {self.web_right*4.5:.1f}", fill=COLOR_DIM, font=("Courier", 10), anchor="w")

        # RIGHT 100%
        ry = by + 88
        col_r = COLOR_RED if self.web_right < 20 else COLOR_CYAN
        self.canvas.create_text(bx + 5, ry, text=f"RIGHT {int(self.web_right):3d}%", fill=col_r, font=("Courier", 11, "bold"), anchor="w")
        self.canvas.create_line(bx, ry + 6, bx + 220, ry + 6, fill=COLOR_DIM, width=1)
        self.canvas.create_line(bx, ry + 20, bx + 220, ry + 20, fill=COLOR_DIM, width=1)
        self.canvas.create_rectangle(bx + 2, ry + 8, bx + 218, ry + 18, fill=COLOR_DARK, outline="")
        fill_r = (self.web_right / 100.0) * 216.0
        self.canvas.create_rectangle(bx + 2, ry + 8, bx + 2 + fill_r, ry + 18, fill=col_r, outline="")

        # LEFT 100%
        ly = by + 132
        col_l = COLOR_RED if self.web_left < 20 else COLOR_CYAN
        self.canvas.create_text(bx + 5, ly, text=f"LEFT  {int(self.web_left):3d}%", fill=col_l, font=("Courier", 11, "bold"), anchor="w")
        self.canvas.create_line(bx, ly + 6, bx + 220, ly + 6, fill=COLOR_DIM, width=1)
        self.canvas.create_line(bx, ly + 20, bx + 220, ly + 20, fill=COLOR_DIM, width=1)
        self.canvas.create_rectangle(bx + 2, ly + 8, bx + 218, ly + 18, fill=COLOR_DARK, outline="")
        fill_l = (self.web_left / 100.0) * 216.0
        self.canvas.create_rectangle(bx + 2, ly + 8, bx + 2 + fill_l, ly + 18, fill=col_l, outline="")

    def draw_crosshair(self):
        tx, ty = self.target_x, self.target_y
        r = 28
        self.canvas.create_oval(tx - r, ty - r, tx + r, ty + r, outline=COLOR_DIM, width=1.5)
        self.canvas.create_oval(tx - 4, ty - 4, tx + 4, ty + 4, outline=COLOR_WHITE, width=2)

        # Засечки
        self.canvas.create_line(tx - r - 10, ty, tx - r + 4, ty, fill=COLOR_CYAN, width=1.5)
        self.canvas.create_line(tx + r - 4, ty, tx + r + 10, ty, fill=COLOR_CYAN, width=1.5)
        self.canvas.create_line(tx, ty - r - 10, tx, ty - r + 4, fill=COLOR_CYAN, width=1.5)
        self.canvas.create_line(tx, ty + r - 4, tx, ty + r + 10, fill=COLOR_CYAN, width=1.5)

        if self.scan_mode:
            self.canvas.create_text(tx + 36, ty - 12, text="TARGET: LOCKED", fill=COLOR_GREEN, font=("Courier", 11, "bold"), anchor="w")
            self.canvas.create_text(tx + 36, ty + 6, text="RANGE: 18.4m", fill=COLOR_CYAN, font=("Courier", 10), anchor="w")

    def update_loop(self):
        now = time.time()
        dt = now - self.last_time
        self.last_time = now
        self.radar_tick += dt

        # Стрельба шутеров
        if self.shooting_left:
            self.web_left = max(0.0, self.web_left - 50.0 * dt)
        else:
            self.web_left = min(100.0, self.web_left + 18.0 * dt)

        if self.shooting_right:
            self.web_right = max(0.0, self.web_right - 50.0 * dt)
        else:
            self.web_right = min(100.0, self.web_right + 18.0 * dt)

        # Плавное движение прицела за взглядом
        self.target_x += (self.mouse_x - self.target_x) * 0.15
        self.target_y += (self.mouse_y - self.target_y) * 0.15

        # Перерисовка
        self.canvas.delete("all")
        w = self.canvas.winfo_width() or 1280
        h = self.canvas.winfo_height() or 720

        self.draw_top_left()
        self.draw_top_right(w)
        self.draw_bottom_right(w, h)
        self.draw_crosshair()

        # Нижняя подсказка
        self.canvas.create_text(
            40, h - 30,
            text="[Q/E или ЛКМ/ПКМ: Веб-шутеры]  [Стрелки влево/вправо: Поворот компаса]  [Пробел: Режим захвата цели]",
            fill=COLOR_DIM, font=("Courier", 10), anchor="w"
        )

        self.root.after(16, self.update_loop)

if __name__ == "__main__":
    root = tk.Tk()
    app = StarkHUDApp(root)
    root.mainloop()
