use macroquad::prelude::*;
use std::process::Command;
use std::sync::mpsc::{channel, Receiver};
use std::thread;

const HUD_BG: Color = Color::new(0.02, 0.03, 0.05, 1.0);
const HUD_CYAN: Color = Color::new(0.58, 0.86, 0.94, 0.95);
const HUD_DIM: Color = Color::new(0.22, 0.42, 0.52, 0.60);
const HUD_DARK: Color = Color::new(0.08, 0.16, 0.22, 0.85);
const HUD_WHITE: Color = Color::new(0.96, 0.98, 1.00, 1.00);
const HUD_GREEN: Color = Color::new(0.28, 0.88, 0.54, 0.95);

struct VisorState {
    heading_deg: f32,
    radar_pulse: f32,
    battery_pct: f32,
    speed_kmh: f32,
    target_speed: f32,
    altitude_m: f32,
    sats: u8,
    sys_temp: f32,
    city: String,
    country: String,
    map_texture: Option<Texture2D>,
    map_loading: bool,
    map_offset: Vec2,
    step_timer: f32,
}

impl VisorState {
    fn new() -> Self {
        Self {
            heading_deg: 42.0,
            radar_pulse: 0.0,
            battery_pct: 92.0,
            speed_kmh: 0.0,
            target_speed: 0.0,
            altitude_m: 142.5,
            sats: 9,
            sys_temp: 38.4,
            city: "QUEENS".to_string(),
            country: "NEW YORK".to_string(),
            map_texture: None,
            map_loading: true,
            map_offset: Vec2::ZERO,
            step_timer: 0.0,
        }
    }

    fn update(&mut self, dt: f32) {
        self.radar_pulse += dt * 3.0;

        // Поворот головы (A / D или стрелки)
        if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
            self.heading_deg -= 55.0 * dt;
        }
        if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
            self.heading_deg += 55.0 * dt;
        }

        // Шаг вперед/назад
        let is_running = is_key_down(KeyCode::LeftShift) || is_key_down(KeyCode::RightShift);
        let max_spd = if is_running { 24.0 } else { 5.4 };

        let mut move_dir = 0.0;
        if is_key_down(KeyCode::W) || is_key_down(KeyCode::Up) {
            move_dir += 1.0;
            self.target_speed = max_spd;
        } else if is_key_down(KeyCode::S) || is_key_down(KeyCode::Down) {
            move_dir -= 0.6;
            self.target_speed = max_spd * 0.6;
        } else {
            self.target_speed = 0.0;
        }

        self.speed_kmh += (self.target_speed - self.speed_kmh) * dt * 4.0;

        if move_dir != 0.0 && self.speed_kmh > 0.1 {
            let rad = self.heading_deg.to_radians();
            let step_scale = if is_running { 55.0 } else { 18.0 };
            let forward = vec2(rad.sin(), -rad.cos()) * move_dir * dt * step_scale;
            self.map_offset += forward;

            self.step_timer += dt * if is_running { 12.0 } else { 7.0 };
            self.altitude_m = 142.5 + self.step_timer.sin() * 0.35;
        }

        self.battery_pct = (self.battery_pct - dt * 0.015).max(5.0);
    }
}

struct MapDownloadResult {
    city: String,
    country: String,
    png_bytes: Vec<u8>,
}

fn json_val(json: &str, key: &str) -> Option<String> {
    let key_pat = format!("\"{}\":", key);
    if let Some(pos) = json.find(&key_pat) {
        let tail = json[pos + key_pat.len()..].trim_start();
        if tail.starts_with('"') {
            let s = &tail[1..];
            if let Some(end) = s.find('"') {
                return Some(s[..end].to_string());
            }
        } else {
            let end = tail.find(|c: char| c == ',' || c == '}' || c.is_whitespace()).unwrap_or(tail.len());
            return Some(tail[..end].to_string());
        }
    }
    None
}

fn start_map_fetch(tx: std::sync::mpsc::Sender<MapDownloadResult>) {
    thread::spawn(move || {
        println!("\x1b[36m[MAP] Определение реальной геолокации по IP...\x1b[0m");

        let output = Command::new("curl")
            .args(&["-s", "--connect-timeout", "4", "http://ip-api.com/json"])
            .output();

        let (mut city, mut country, mut lat, mut lon) = (
            "MOSCOW".to_string(),
            "RUSSIA".to_string(),
            55.7558_f64,
            37.6173_f64,
        );

        if let Ok(out) = output {
            if let Ok(json) = String::from_utf8(out.stdout) {
                if let (Some(c), Some(co), Some(la), Some(lo)) = (
                    json_val(&json, "city"),
                    json_val(&json, "country"),
                    json_val(&json, "lat"),
                    json_val(&json, "lon"),
                ) {
                    city = c.to_uppercase();
                    country = co.to_uppercase();
                    if let (Ok(parsed_la), Ok(parsed_lo)) = (la.parse::<f64>(), lo.parse::<f64>()) {
                        lat = parsed_la;
                        lon = parsed_lo;
                    }
                }
            }
        }

        println!("\x1b[32m[MAP] Локация: {}, {} ({:.4}, {:.4})\x1b[0m", city, country, lat, lon);

        let zoom = 15;
        let n = 2.0_f64.powi(zoom);
        let x = (((lon + 180.0) / 360.0) * n).floor() as u32;
        let lat_rad = lat.to_radians();
        let y = (((1.0 - (lat_rad.tan() + 1.0 / lat_rad.cos()).ln() / std::f64::consts::PI) / 2.0) * n).floor() as u32;

        let tile_url = format!("https://tile.openstreetmap.org/{}/{}/{}.png", zoom, x, y);
        println!("\x1b[36m[MAP] Загрузка открытых спутниковых дорог: {}\x1b[0m", tile_url);

        let tile_output = Command::new("curl")
            .args(&["-s", "-A", "StarkVisor/1.0", "--connect-timeout", "6", &tile_url])
            .output();

        if let Ok(tile_out) = tile_output {
            if !tile_out.stdout.is_empty() {
                let _ = tx.send(MapDownloadResult {
                    city,
                    country,
                    png_bytes: tile_out.stdout,
                });
                println!("\x1b[32m[MAP] Реальная карта интегрирована в радар!\x1b[0m");
            }
        }
    });
}

fn txt(font: Option<&Font>, text: &str, x: f32, y: f32, size: u16, color: Color) {
    if let Some(f) = font {
        draw_text_ex(
            text,
            x,
            y,
            TextParams {
                font: Some(f),
                font_size: size * 2,
                font_scale: 0.5,
                color,
                ..Default::default()
            },
        );
    } else {
        draw_text(text, x, y, size as f32, color);
    }
}

fn draw_bracket(x: f32, y: f32, w: f32, h: f32, len: f32, thick: f32, color: Color) {
    draw_line(x, y, x + len, y, thick, color);
    draw_line(x, y, x, y + len, thick, color);
    draw_line(x + w, y, x + w - len, y, thick, color);
    draw_line(x + w, y, x + w, y + len, thick, color);
    draw_line(x, y + h, x + len, y + h, thick, color);
    draw_line(x, y + h, x, y + h - len, thick, color);
    draw_line(x + w, y + h, x + w - len, y + h, thick, color);
    draw_line(x + w, y + h, x + w, y + h - len, thick, color);
}

fn draw_telemetry_top_left(font: Option<&Font>) {
    let base_x = 35.0;
    let base_y = 35.0;

    txt(font, "[ 88 ]", base_x, base_y, 18, HUD_DIM);
    txt(font, "[ 16:9 ]", base_x + 70.0, base_y, 18, HUD_DIM);
    txt(font, "[ RAW ]", base_x + 155.0, base_y, 18, HUD_DIM);

    let box_y = base_y + 15.0;
    draw_bracket(base_x, box_y, 190.0, 105.0, 12.0, 1.5, HUD_CYAN);

    txt(font, "WIFI NET.", base_x + 14.0, box_y + 26.0, 20, HUD_WHITE);

    let icon_x = base_x + 160.0;
    let icon_y = box_y + 20.0;
    for r in 1..=3 {
        let radius = r as f32 * 5.0;
        draw_arc(icon_x, icon_y, 16, radius, -45.0, 90.0, 1.5, HUD_CYAN);
    }
    draw_circle(icon_x, icon_y, 2.0, HUD_WHITE);

    txt(font, "RDY 102", base_x + 14.0, box_y + 50.0, 16, HUD_CYAN);
    txt(font, "SEARCH RAD: 55.2", base_x + 14.0, box_y + 68.0, 15, HUD_CYAN);

    txt(font, "VPN CONN.", base_x + 14.0, box_y + 90.0, 15, HUD_DIM);
    for i in 0..5 {
        let bar_h = 4.0 + i as f32 * 3.0;
        let bx = base_x + 120.0 + i as f32 * 8.0;
        let by = box_y + 92.0 - bar_h;
        draw_rectangle(bx, by, 5.0, bar_h, HUD_CYAN);
    }
}

// Радар с плавающим смещением
fn draw_minimap_top_right(font: Option<&Font>, state: &VisorState) {
    let w = screen_width();
    let map_w = 185.0;
    let map_h = 155.0;
    let base_x = w - map_w - 40.0;
    let base_y = 35.0;
    let box_y = base_y + 45.0;
    let center = vec2(base_x + map_w * 0.5, box_y + map_h * 0.5);
    let rad = state.heading_deg.to_radians();
    let cos_a = rad.cos();
    let sin_a = rad.sin();

    // 1. Отрисовка карты строго вокруг центра визора
    if let Some(ref tex) = state.map_texture {
        let tex_size = 280.0;
        let pivot_point = vec2(tex_size * 0.5, tex_size * 0.5);

        draw_texture_ex(
            tex,
            center.x - tex_size * 0.5 - state.map_offset.x,
            center.y - tex_size * 0.5 - state.map_offset.y,
            Color::new(0.9, 0.95, 1.0, 0.9),
            DrawTextureParams {
                dest_size: Some(vec2(tex_size, tex_size)),
                rotation: rad,
                pivot: Some(pivot_point),
                ..Default::default()
            },
        );
    } else {
        draw_rectangle(base_x, box_y, map_w, map_h, HUD_DARK);
        if state.map_loading {
            txt(font, "CONNECTING...", base_x + 35.0, box_y + map_h * 0.5, 14, HUD_CYAN);
        }
    }

    // 2. МАСКИРОВАНИЕ
    let pad = 140.0;
    draw_rectangle(base_x - pad, box_y - pad, map_w + pad * 2.0, pad, HUD_BG);
    draw_rectangle(base_x - pad, box_y + map_h, map_w + pad * 2.0, pad, HUD_BG);
    draw_rectangle(base_x - pad, box_y, pad, map_h, HUD_BG);
    draw_rectangle(base_x + map_w, box_y, pad, map_h, HUD_BG);

    // 3. Заголовки поверх шторки
    txt(font, "LOCATION", base_x, base_y, 15, HUD_DIM);
    txt(font, &state.city, base_x, base_y + 18.0, 20, HUD_WHITE);
    txt(font, &state.country, base_x, base_y + 36.0, 16, HUD_CYAN);

    draw_bracket(base_x, box_y, map_w, map_h, 10.0, 1.5, HUD_CYAN);

    // Маркер позиции (строго по центру)
    let pulse = (state.radar_pulse.sin() * 0.5 + 0.5).max(0.1);
    draw_circle(center.x, center.y, 3.5, HUD_WHITE);
    draw_circle_lines(center.x, center.y, 8.0 + pulse * 6.0, 1.5, HUD_CYAN);

    // Стрелочка курса
    let tip = vec2(center.x - 16.0 * sin_a, center.y - 16.0 * cos_a);
    draw_line(center.x, center.y, tip.x, tip.y, 2.5, HUD_WHITE);

    // Азимут компаса
    txt(
        font,
        &format!("HDG: {:03.0}°", state.heading_deg.rem_euclid(360.0)),
        base_x + 10.0,
        box_y + map_h - 10.0,
        15,
        HUD_CYAN,
    );
}

fn draw_suit_telemetry_bottom_right(font: Option<&Font>, state: &VisorState) {
    let w = screen_width();
    let h = screen_height();
    let base_x = w - 245.0;
    let base_y = h - 175.0;

    draw_bracket(base_x, base_y, 210.0, 140.0, 10.0, 1.5, HUD_DIM);
    txt(font, "SUIT TELEMETRY", base_x + 14.0, base_y + 22.0, 17, HUD_WHITE);

    txt(font, &format!("PWR: {:.0}%", state.battery_pct), base_x + 14.0, base_y + 44.0, 15, HUD_CYAN);
    draw_rectangle(base_x + 85.0, base_y + 34.0, 110.0, 11.0, HUD_DARK);
    draw_rectangle(
        base_x + 85.0,
        base_y + 34.0,
        (state.battery_pct / 100.0) * 110.0,
        11.0,
        HUD_CYAN,
    );

    txt(font, &format!("GPS LOCK: {} SATS", state.sats), base_x + 14.0, base_y + 68.0, 14, HUD_GREEN);
    txt(font, &format!("ALT: {:.1}m", state.altitude_m), base_x + 14.0, base_y + 88.0, 14, HUD_DIM);
    txt(font, &format!("SPD: {:.1} km/h", state.speed_kmh), base_x + 14.0, base_y + 108.0, 14, HUD_CYAN);
    txt(font, &format!("CORE TEMP: {:.1}°C", state.sys_temp), base_x + 14.0, base_y + 128.0, 13, HUD_DIM);
}

fn draw_minimal_center_horizon() {
    let cx = screen_width() * 0.5;
    let cy = screen_height() * 0.5;

    draw_circle(cx, cy, 2.5, HUD_CYAN);
    draw_line(cx - 70.0, cy, cx - 30.0, cy, 1.2, HUD_DIM);
    draw_line(cx + 30.0, cy, cx + 70.0, cy, 1.2, HUD_DIM);
    draw_line(cx - 30.0, cy, cx - 30.0, cy + 6.0, 1.2, HUD_DIM);
    draw_line(cx + 30.0, cy, cx + 30.0, cy + 6.0, 1.2, HUD_DIM);
}

fn window_conf() -> Conf {
    Conf {
        window_title: "Stark Tech Helmet Visor".to_string(),
        window_width: 1280,
        window_height: 720,
        sample_count: 8,
        high_dpi: true,
        fullscreen: false,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    let font = match load_ttf_font("font.ttf").await {
        Ok(mut f) => {
            f.set_filter(FilterMode::Linear);
            Some(f)
        }
        Err(_) => None,
    };

    let mut state = VisorState::new();

    let (tx, rx): (std::sync::mpsc::Sender<MapDownloadResult>, Receiver<MapDownloadResult>) = channel();
    start_map_fetch(tx);

    loop {
        let dt = get_frame_time();
        state.update(dt);

        if let Ok(res) = rx.try_recv() {
            state.city = res.city;
            state.country = res.country;
            if let Ok(mut img) = Image::from_file_with_format(&res.png_bytes, Some(ImageFormat::Png)) {
                for chunk in img.bytes.chunks_exact_mut(4) {
                    let r = chunk[0] as f32;
                    let g = chunk[1] as f32;
                    let b = chunk[2] as f32;
                    let brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0;
                    let inv = 1.0 - brightness;

                    chunk[0] = (inv * 90.0) as u8;
                    chunk[1] = (inv * 210.0 + 15.0) as u8;
                    chunk[2] = (inv * 255.0 + 40.0).min(255.0) as u8;
                    chunk[3] = 240;
                }
                let tex = Texture2D::from_image(&img);
                tex.set_filter(FilterMode::Linear);
                state.map_texture = Some(tex);
                state.map_loading = false;
            }
        }

        clear_background(HUD_BG);

        draw_telemetry_top_left(font.as_ref());
        draw_minimap_top_right(font.as_ref(), &state);
        draw_suit_telemetry_bottom_right(font.as_ref(), &state);
        draw_minimal_center_horizon();

        txt(
            font.as_ref(),
            "[W/S: MOVE FWD/BACK]  [SHIFT+W: RUN 24 KM/H]  [A/D: TURN COMPASS]",
            40.0,
            screen_height() - 25.0,
            14,
            HUD_DIM,
        );

        next_frame().await;
    }
}
