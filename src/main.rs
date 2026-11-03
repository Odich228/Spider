use macroquad::prelude::*;
use std::f32::consts::PI;

const HUD_CYAN: Color = Color::new(0.58, 0.86, 0.94, 0.95);
const HUD_DIM: Color = Color::new(0.22, 0.42, 0.52, 0.60);
const HUD_DARK: Color = Color::new(0.08, 0.16, 0.22, 0.85);
const HUD_WHITE: Color = Color::new(0.96, 0.98, 1.00, 1.00);
const HUD_RED: Color = Color::new(0.95, 0.26, 0.26, 0.95);
const HUD_GREEN: Color = Color::new(0.28, 0.88, 0.54, 0.95);

struct HudState {
    web_left: f32,
    web_right: f32,
    heading_deg: f32,
    lat: f64,
    lng: f64,
    radar_tick: f32,
    scan_mode: bool,
    target_pos: Vec2,
}

impl HudState {
    fn new() -> Self {
        Self {
            web_left: 100.0,
            web_right: 100.0,
            heading_deg: 42.0,
            lat: 40.7282,
            lng: -73.7949,
            radar_tick: 0.0,
            scan_mode: false,
            target_pos: vec2(screen_width() * 0.5, screen_height() * 0.5),
        }
    }

    fn update(&mut self, dt: f32) {
        self.radar_tick += dt * 3.0;

        // Левый веб-шутер (Клавиша Q или ЛКМ)
        if is_key_down(KeyCode::Q) || is_mouse_button_down(MouseButton::Left) {
            self.web_left = (self.web_left - 35.0 * dt).max(0.0);
        } else {
            self.web_left = (self.web_left + 15.0 * dt).min(100.0);
        }

        // Правый веб-шутер (Клавиша E или ПКМ)
        if is_key_down(KeyCode::E) || is_mouse_button_down(MouseButton::Right) {
            self.web_right = (self.web_right - 35.0 * dt).max(0.0);
        } else {
            self.web_right = (self.web_right + 15.0 * dt).min(100.0);
        }

        // Поворот головы / компаса (Стрелки влево/вправо или движение мыши)
        if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
            self.heading_deg -= 60.0 * dt;
        }
        if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
            self.heading_deg += 60.0 * dt;
        }

        // Переключение режима сканирования (Пробел)
        if is_key_pressed(KeyCode::Space) {
            self.scan_mode = !self.scan_mode;
        }

        // Движение прицела за взглядом
        let mouse = mouse_position();
        self.target_pos = self.target_pos.lerp(vec2(mouse.0, mouse.1), dt * 8.0);
    }
}

fn draw_bracket(x: f32, y: f32, w: f32, h: f32, len: f32, thick: f32, color: Color) {
    // Верх-лево
    draw_line(x, y, x + len, y, thick, color);
    draw_line(x, y, x, y + len, thick, color);
    // Верх-право
    draw_line(x + w, y, x + w - len, y, thick, color);
    draw_line(x + w, y, x + w, y + len, thick, color);
    // Низ-лево
    draw_line(x, y + h, x + len, y + h, thick, color);
    draw_line(x, y + h, x, y + h - len, thick, color);
    // Низ-право
    draw_line(x + w, y + h, x + w - len, y + h, thick, color);
    draw_line(x + w, y + h, x + w, y + h - len, thick, color);
}

fn draw_telemetry_top_left(state: &HudState) {
    let base_x = 35.0;
    let base_y = 30.0;

    // Плашки камеры визора
    draw_text("[ 88 ]", base_x, base_y, 18.0, HUD_DIM);
    draw_text("[ 16:9 ]", base_x + 65.0, base_y, 18.0, HUD_DIM);
    draw_text("[ RAW ]", base_x + 145.0, base_y, 18.0, HUD_DIM);

    // Блок WiFi
    let box_y = base_y + 15.0;
    draw_bracket(base_x, box_y, 175.0, 95.0, 10.0, 1.5, HUD_CYAN);

    draw_text("WIFI NET.", base_x + 12.0, box_y + 22.0, 20.0, HUD_WHITE);

    // Иконка антенны Wi-Fi
    let icon_x = base_x + 148.0;
    let icon_y = box_y + 18.0;
    for r in 1..=3 {
        let radius = r as f32 * 5.0;
        draw_arc(icon_x, icon_y, 16, radius, -45.0, 90.0, HUD_CYAN);
    }
    draw_circle(icon_x, icon_y, 2.0, HUD_WHITE);

    draw_text("RDY 102", base_x + 12.0, box_y + 44.0, 16.0, HUD_CYAN);
    draw_text("SEARCH RAD: 55.2", base_x + 12.0, box_y + 60.0, 15.0, HUD_CYAN);

    draw_text("VPN CONN.", base_x + 12.0, box_y + 80.0, 16.0, HUD_DIM);

    // Столбики уровня сигнала
    for i in 0..5 {
        let bar_h = 3.0 + i as f32 * 3.0;
        let bx = base_x + 115.0 + i as f32 * 7.0;
        let by = box_y + 82.0 - bar_h;
        draw_rectangle(bx, by, 4.0, bar_h, HUD_CYAN);
    }
}

fn draw_minimap_top_right(state: &HudState) {
    let w = screen_width();
    let map_w = 170.0;
    let map_h = 145.0;
    let base_x = w - map_w - 40.0;
    let base_y = 30.0;

    draw_text("LOCATION", base_x, base_y, 16.0, HUD_DIM);
    draw_text("QUEENS", base_x, base_y + 18.0, 19.0, HUD_WHITE);
    draw_text("NEW YORK", base_x, base_y + 34.0, 15.0, HUD_CYAN);

    let box_y = base_y + 45.0;
    draw_rectangle(base_x, box_y, map_w, map_h, HUD_DARK);
    draw_bracket(base_x, box_y, map_w, map_h, 8.0, 1.5, HUD_CYAN);

    // Вращение карты улиц по компасу
    let center = vec2(base_x + map_w * 0.5, box_y + map_h * 0.5);
    let rad = state.heading_deg.to_radians();

    let rotate_pt = |ox: f32, oy: f32| -> Vec2 {
        let cos_a = rad.cos();
        let sin_a = rad.sin();
        vec2(
            center.x + ox * cos_a - oy * sin_a,
            center.y + ox * sin_a + oy * cos_a,
        )
    };

    // Сетка улиц Квинса
    let streets = [
        (-70.0, -30.0, 60.0, -20.0),
        (-60.0, 20.0, 70.0, 30.0),
        (-25.0, -60.0, -15.0, 60.0),
        (25.0, -60.0, 35.0, 60.0),
        (-50.0, -50.0, 40.0, 50.0),
    ];

    for (x1, y1, x2, y2) in streets {
        let p1 = rotate_pt(x1, y1);
        let p2 = rotate_pt(x2, y2);
        draw_line(p1.x, p1.y, p2.x, p2.y, 1.2, HUD_DIM);
    }

    // Маркер позиции (мигающий брейкпойнт игрока)
    let pulse = (state.radar_tick.sin() * 0.5 + 0.5).max(0.1);
    draw_circle(center.x, center.y, 3.5, HUD_WHITE);
    draw_circle_lines(center.x, center.y, 7.0 + pulse * 6.0, 1.2, HUD_CYAN);

    // Стрелочка курса вперед
    let tip = rotate_pt(0.0, -14.0);
    draw_line(center.x, center.y, tip.x, tip.y, 2.0, HUD_WHITE);

    // Азимут компаса
    draw_text(
        &format!("HDG: {:03.0}°", state.heading_deg.rem_euclid(360.0)),
        base_x + 8.0,
        box_y + map_h - 8.0,
        14.0,
        HUD_CYAN,
    );
}

fn draw_web_shooters_bottom_right(state: &HudState) {
    let w = screen_width();
    let h = screen_height();
    let base_x = w - 240.0;
    let base_y = h - 170.0;

    // Карточка WEB SYNTHESIS
    draw_bracket(base_x, base_y, 205.0, 62.0, 8.0, 1.2, HUD_DIM);
    draw_text("WEB SYN.", base_x + 12.0, base_y + 20.0, 18.0, HUD_WHITE);
    draw_text("POLYMER 04", base_x + 12.0, base_y + 36.0, 15.0, HUD_CYAN);
    draw_text(
        &format!("L: {:.1} / R: {:.1}", state.web_left * 4.5, state.web_right * 4.5),
        base_x + 12.0,
        base_y + 52.0,
        13.0,
        HUD_DIM,
    );

    // --- Правый веб-шутер (RIGHT 100%) ---
    let r_y = base_y + 75.0;
    draw_text(
        &format!("RIGHT {:.0}%", state.web_left),
        base_x + 5.0,
        r_y,
        15.0,
        if state.web_right < 20.0 { HUD_RED } else { HUD_CYAN },
    );
    draw_line(base_x, r_y + 4.0, base_x + 200.0, r_y + 4.0, 1.0, HUD_DIM);
    draw_line(base_x, r_y + 16.0, base_x + 200.0, r_y + 16.0, 1.0, HUD_DIM);

    draw_rectangle(base_x + 2.0, r_y + 6.0, 196.0, 8.0, HUD_DARK);
    let fill_r = (state.web_right / 100.0) * 196.0;
    draw_rectangle(
        base_x + 2.0,
        r_y + 6.0,
        fill_r,
        8.0,
        if state.web_right < 20.0 { HUD_RED } else { HUD_CYAN },
    );

    // --- Левый веб-шутер (LEFT 100%) ---
    let l_y = base_y + 115.0;
    draw_text(
        &format!("LEFT  {:.0}%", state.web_left),
        base_x + 5.0,
        l_y,
        15.0,
        if state.web_left < 20.0 { HUD_RED } else { HUD_CYAN },
    );
    draw_line(base_x, l_y + 4.0, base_x + 200.0, l_y + 4.0, 1.0, HUD_DIM);
    draw_line(base_x, l_y + 16.0, base_x + 200.0, l_y + 16.0, 1.0, HUD_DIM);

    draw_rectangle(base_x + 2.0, l_y + 6.0, 196.0, 8.0, HUD_DARK);
    let fill_l = (state.web_left / 100.0) * 196.0;
    draw_rectangle(
        base_x + 2.0,
        l_y + 6.0,
        fill_l,
        8.0,
        if state.web_left < 20.0 { HUD_RED } else { HUD_CYAN },
    );
}

fn draw_tactical_crosshair(state: &HudState) {
    let p = state.target_pos;
    let size = 24.0;

    draw_circle_lines(p.x, p.y, size, 1.2, HUD_DIM);
    draw_circle_lines(p.x, p.y, 4.0, 1.5, HUD_WHITE);

    // Засечки прицела
    draw_line(p.x - size - 8.0, p.y, p.x - size + 4.0, p.y, 1.5, HUD_CYAN);
    draw_line(p.x + size - 4.0, p.y, p.x + size + 8.0, p.y, 1.5, HUD_CYAN);
    draw_line(p.x, p.y - size - 8.0, p.x, p.y - size + 4.0, 1.5, HUD_CYAN);
    draw_line(p.x, p.y + size - 4.0, p.x, p.y + size + 8.0, 1.5, HUD_CYAN);

    // Тактические подсказки
    if state.scan_mode {
        draw_text("TARGET: LOCK", p.x + 30.0, p.y - 10.0, 14.0, HUD_GREEN);
        draw_text("DIST: 14.2m", p.x + 30.0, p.y + 6.0, 12.0, HUD_CYAN);
    }
}

fn window_conf() -> Conf {
    Conf {
        window_title: "Stark Tech Spider-Man HUD".to_string(),
        window_width: 1280,
        window_height: 720,
        high_dpi: true,
        fullscreen: false,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    let mut state = HudState::new();

    loop {
        let dt = get_frame_time();
        state.update(dt);

        clear_background(Color::new(0.02, 0.03, 0.05, 1.0));

        // Отрисовка всех модулей интерфейса визора
        draw_telemetry_top_left(&state);
        draw_minimap_top_right(&state);
        draw_web_shooters_bottom_right(&state);
        draw_tactical_crosshair(&state);

        // Инструкция внизу слева
        draw_text(
            "[Q/E или ЛКМ/ПКМ: Выстрел шутеров] [A/D или Мышь: Компас] [Пробел: Режим скан]",
            40.0,
            screen_height() - 25.0,
            14.0,
            HUD_DIM,
        );

        next_frame().await;
    }
}
