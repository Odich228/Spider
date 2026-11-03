use macroquad::prelude::*;
use std::net::UdpSocket;
use std::process::Command;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::thread;

const HUD_BG: Color = Color::new(0.02, 0.03, 0.05, 1.0);
const HUD_CYAN: Color = Color::new(0.58, 0.86, 0.94, 0.95);
const HUD_DIM: Color = Color::new(0.22, 0.42, 0.52, 0.60);
const HUD_DARK: Color = Color::new(0.08, 0.16, 0.22, 0.85);
const HUD_WHITE: Color = Color::new(0.96, 0.98, 1.00, 1.00);
const HUD_GREEN: Color = Color::new(0.28, 0.88, 0.54, 0.95);
const HUD_RED: Color = Color::new(0.95, 0.26, 0.26, 0.95);
const HUD_AMBER: Color = Color::new(1.00, 0.65, 0.15, 0.95);

#[derive(Debug, Clone)]
pub enum BtEvent {
    Notification { app: String, sender: String, text: String },
    MediaTrack { title: String, artist: String, is_playing: bool },
    HeartRate { bpm: f32 },
    SpiderSense { active: bool, text: String },
    KarenSpeech { text: String },
    Status { connected: bool, device_name: String, phone_battery: Option<u8> },
    ImuOrientation { yaw: f32, pitch: f32, roll: f32 },
}

#[derive(Debug, Clone)]
struct PlaneMarker {
    callsign: String,
    offset: Vec2,
    heading: f32,
    altitude_ft: u32,
    speed_kmh: u32,
}

struct VisorState {
    heading_deg: f32,
    pitch_deg: f32,
    roll_deg: f32,
    imu_active: bool,

    radar_pulse: f32,
    battery_pct: f32,
    speed_kmh: f32,
    target_speed: f32,
    altitude_m: f32,
    sats: u8,
    sys_temp: f32,
    city: String,
    country: String,
    player_lat: f64,
    player_lon: f64,
    map_texture: Option<Texture2D>,
    map_loading: bool,
    map_offset: Vec2,
    step_timer: f32,
    boot_timer: f32,

    // Аппаратный буфер отсечения карты (Render Target)
    radar_target: RenderTarget,
    radar_cam: Camera2D,

    // Модуль "Паучье чутьё"
    spider_sense_active: bool,
    spider_sense_timer: f32,
    spider_sense_text: String,

    // Модуль биометрии (ЭКГ + Пульс)
    heart_rate_bpm: f32,
    ecg_phase: f32,
    ecg_buffer: Vec<f32>,

    // Модуль медиаплеера (Bluetooth AVRCP / эквалайзер)
    eq_bars: [f32; 12],
    media_track_title: String,
    media_track_artist: String,
    media_is_playing: bool,

    // Модуль уведомлений со смартфона
    notification_timer: f32,
    notification_title: String,
    notification_body: String,

    // Модуль ИИ Карен
    karen_timer: f32,
    karen_text: Option<String>,

    // Живой радар реальных самолётов (Live ADS-B via OpenSky)
    planes: Vec<PlaneMarker>,
    real_adsb_count: usize,

    // Bluetooth статус
    bt_connected: bool,
    bt_device_name: String,
    bt_phone_battery: Option<u8>,
}

impl VisorState {
    fn new() -> Self {
        let map_w = 185.0;
        let map_h = 155.0;

        let radar_target = render_target(map_w as u32, map_h as u32);
        radar_target.texture.set_filter(FilterMode::Linear);

        let mut radar_cam = Camera2D::from_display_rect(Rect::new(0.0, 0.0, map_w, map_h));
        radar_cam.render_target = Some(radar_target.clone());

        let initial_map = create_procedural_cyber_map();

        Self {
            heading_deg: 0.0,
            pitch_deg: 0.0,
            roll_deg: 0.0,
            imu_active: false,

            radar_pulse: 0.0,
            battery_pct: 92.0,
            speed_kmh: 0.0,
            target_speed: 0.0,
            altitude_m: 142.5,
            sats: 9,
            sys_temp: 38.4,
            city: "MOSCOW".to_string(),
            country: "RUSSIA".to_string(),
            player_lat: 55.7558,
            player_lon: 37.6173,
            map_texture: Some(initial_map),
            map_loading: true,
            map_offset: Vec2::ZERO,
            step_timer: 0.0,
            boot_timer: 0.0,

            radar_target,
            radar_cam,

            spider_sense_active: false,
            spider_sense_timer: 0.0,
            spider_sense_text: "<! DANGER: REAR PROXIMITY 0.8M !>".to_string(),

            heart_rate_bpm: 74.0,
            ecg_phase: 0.0,
            ecg_buffer: vec![0.0; 60],

            eq_bars: [0.3; 12],
            media_track_title: "BACK IN BLACK".to_string(),
            media_track_artist: "AC/DC".to_string(),
            media_is_playing: true,

            notification_timer: 0.0,
            notification_title: String::new(),
            notification_body: String::new(),

            karen_timer: 0.0,
            karen_text: None,

            planes: vec![
                PlaneMarker { callsign: "AFL-214".to_string(), offset: vec2(-35.0, -45.0), heading: 125.0, altitude_ft: 28000, speed_kmh: 820 },
                PlaneMarker { callsign: "S7-1042".to_string(), offset: vec2(40.0, 30.0), heading: 310.0, altitude_ft: 31000, speed_kmh: 790 },
            ],
            real_adsb_count: 0,

            bt_connected: false,
            bt_device_name: "PORT: 9099 / BLUEZ".to_string(),
            bt_phone_battery: None,
        }
    }

    fn apply_bt_event(&mut self, event: BtEvent) {
        match event {
            BtEvent::Notification { app, sender, text } => {
                self.notification_title = format!("{} // {}", app.to_uppercase(), sender.to_uppercase());
                self.notification_body = text;
                self.notification_timer = 6.0;
            }
            BtEvent::MediaTrack { title, artist, is_playing } => {
                self.media_track_title = title;
                self.media_track_artist = artist;
                self.media_is_playing = is_playing;
            }
            BtEvent::HeartRate { bpm } => {
                self.heart_rate_bpm = bpm.clamp(40.0, 220.0);
            }
            BtEvent::SpiderSense { active, text } => {
                self.spider_sense_active = active;
                if active {
                    self.spider_sense_timer = 3.5;
                    self.spider_sense_text = text;
                }
            }
            BtEvent::KarenSpeech { text } => {
                self.karen_text = Some(text);
                self.karen_timer = 4.5;
            }
            BtEvent::Status { connected, device_name, phone_battery } => {
                self.bt_connected = connected;
                self.bt_device_name = device_name;
                self.bt_phone_battery = phone_battery;
            }
            BtEvent::ImuOrientation { yaw, pitch, roll } => {
                self.heading_deg = yaw;
                self.pitch_deg = pitch;
                self.roll_deg = roll;
                self.imu_active = true;
            }
        }
    }

    fn update(&mut self, dt: f32) {
        self.boot_timer += dt;

        // R - Перезагрузка анимации шлема
        if is_key_pressed(KeyCode::R) {
            self.boot_timer = 0.0;
        }

        // P - Тест "Паучьего чутья" (Spider-Sense)
        if is_key_pressed(KeyCode::P) {
            self.spider_sense_active = true;
            self.spider_sense_timer = 3.0;
            self.spider_sense_text = "<! DANGER: HIGH THREAT DETECTED !>".to_string();
        }
        if self.spider_sense_timer > 0.0 {
            self.spider_sense_timer -= dt;
            if self.spider_sense_timer <= 0.0 {
                self.spider_sense_active = false;
            }
        }

        // N - Тест уведомления со смартфона
        if is_key_pressed(KeyCode::N) {
            self.notification_timer = 6.0;
            self.notification_title = "TELEGRAM // TONY STARK".to_string();
            self.notification_body = "Peter, check the skies. High-altitude traffic incoming.".to_string();
        }
        if self.notification_timer > 0.0 {
            self.notification_timer -= dt;
        }

        // K - Диалог с ИИ Карен
        if is_key_pressed(KeyCode::K) {
            self.karen_timer = 4.5;
            self.karen_text = Some("KAREN: All systems nominal. Airspace scans synchronized.".to_string());
        }
        if self.karen_timer > 0.0 {
            self.karen_timer -= dt;
        }

        // M - Пауза/плей музыки
        if is_key_pressed(KeyCode::M) {
            self.media_is_playing = !self.media_is_playing;
        }

        // Анимация эквалайзера музыки
        for i in 0..12 {
            let target = if self.media_is_playing {
                ((get_time() as f32 * (4.0 + i as f32)).sin() * 0.5 + 0.5).powf(1.4)
            } else {
                0.08
            };
            self.eq_bars[i] += (target - self.eq_bars[i]) * dt * 15.0;
        }

        // Дрейф самолётов в небе по их вектору
        for plane in &mut self.planes {
            let p_rad = plane.heading.to_radians();
            let spd_factor = (plane.speed_kmh as f32 / 800.0).clamp(0.5, 2.0);
            plane.offset.x += p_rad.sin() * dt * 3.5 * spd_factor;
            plane.offset.y -= p_rad.cos() * dt * 3.5 * spd_factor;
        }

        self.radar_pulse += dt * 3.0;

        // Поворот головы / компаса с клавиатуры (если нет физического гироскопа)
        if !self.imu_active {
            if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
                self.heading_deg -= 55.0 * dt;
            }
            if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
                self.heading_deg += 55.0 * dt;
            }
            if is_key_down(KeyCode::Up) {
                self.pitch_deg = (self.pitch_deg + 30.0 * dt).min(35.0);
            } else if is_key_down(KeyCode::Down) {
                self.pitch_deg = (self.pitch_deg - 30.0 * dt).max(-35.0);
            } else {
                self.pitch_deg += (0.0 - self.pitch_deg) * dt * 3.0;
            }
        }

        // Движение вперед / назад (W / S)
        let is_running = is_key_down(KeyCode::LeftShift) || is_key_down(KeyCode::RightShift);
        let max_spd = if is_running { 24.0 } else { 5.4 };

        let mut move_dir = 0.0;
        if is_key_down(KeyCode::W) {
            move_dir += 1.0;
            self.target_speed = max_spd;
        } else if is_key_down(KeyCode::S) {
            move_dir -= 0.6;
            self.target_speed = max_spd * 0.6;
        } else {
            self.target_speed = 0.0;
        }

        self.speed_kmh += (self.target_speed - self.speed_kmh) * dt * 4.0;

        // Физиологический пульс
        if !self.bt_connected {
            let target_bpm = if is_running && move_dir > 0.0 {
                132.0
            } else if move_dir > 0.0 {
                96.0
            } else {
                72.0
            };
            self.heart_rate_bpm += (target_bpm - self.heart_rate_bpm) * dt * 1.5;
        }

        // Генерация высокоточной ЭКГ-волны (P-Q-R-S-T)
        let bps = self.heart_rate_bpm / 60.0;
        self.ecg_phase = (self.ecg_phase + dt * bps) % 1.0;
        let ecg_val = if self.ecg_phase > 0.15 && self.ecg_phase < 0.22 {
            28.0 * ((self.ecg_phase - 0.185) / 0.035 * std::f32::consts::PI).cos()
        } else if self.ecg_phase > 0.22 && self.ecg_phase < 0.26 {
            -8.0
        } else if self.ecg_phase > 0.35 && self.ecg_phase < 0.50 {
            5.0 * ((self.ecg_phase - 0.425) / 0.075 * std::f32::consts::PI).cos()
        } else {
            0.0
        };

        self.ecg_buffer.remove(0);
        self.ecg_buffer.push(ecg_val);

        if move_dir != 0.0 && self.speed_kmh > 0.1 {
            let rad = self.heading_deg.to_radians();
            let step_scale = if is_running { 60.0 } else { 20.0 };
            self.map_offset.x += rad.sin() * move_dir * dt * step_scale;
            self.map_offset.y -= rad.cos() * move_dir * dt * step_scale;

            self.step_timer += dt * if is_running { 12.0 } else { 7.0 };
            self.altitude_m = 142.5 + self.step_timer.sin() * 0.35;
        }

        self.battery_pct = (self.battery_pct - dt * 0.015).max(5.0);
    }
}

// -------------------------------------------------------------
// ГЕНЕРАТОР ПРОЦЕДУРНОЙ КИБЕР-КАРТЫ STARK (OFFLINE-FALLBACK)
// -------------------------------------------------------------
fn create_procedural_cyber_map() -> Texture2D {
    let size = 256;
    let mut bytes = vec![0u8; size * size * 4];

    for y in 0..size {
        for x in 0..size {
            let idx = (y * size + x) * 4;

            let mut r = 8u8;
            let mut g = 14u8;
            let mut b = 22u8;

            let is_major_road = (x % 48 < 3) || (y % 48 < 3);
            let is_minor_street = (x % 16 == 0) || (y % 16 == 0);

            let diag_dist = ((x as i32) - (y as i32) + 25).abs();
            let is_diagonal = diag_dist < 4;

            let river_center = 128.0 + ((x as f32) * 0.04).sin() * 35.0;
            let is_river = (y as f32 - river_center).abs() < 10.0;

            if is_river {
                r = 10;
                g = 35;
                b = 70;
            } else if is_diagonal {
                r = 140;
                g = 225;
                b = 250;
            } else if is_major_road {
                r = 85;
                g = 175;
                b = 215;
            } else if is_minor_street {
                r = 25;
                g = 55;
                b = 75;
            } else {
                let block_hash = ((x / 16) * 59 + (y / 16) * 31) % 4;
                if block_hash == 0 {
                    r = 14;
                    g = 24;
                    b = 34;
                }
            }

            bytes[idx] = r;
            bytes[idx + 1] = g;
            bytes[idx + 2] = b;
            bytes[idx + 3] = 255;
        }
    }

    let img = Image {
        bytes,
        width: size as u16,
        height: size as u16,
    };
    let tex = Texture2D::from_image(&img);
    tex.set_filter(FilterMode::Linear);
    tex
}

struct MapDownloadResult {
    city: String,
    country: String,
    lat: f64,
    lon: f64,
    png_bytes: Vec<u8>,
}

fn is_valid_png(bytes: &[u8]) -> bool {
    bytes.len() > 8 && bytes[0..8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
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

fn start_map_fetch(tx: Sender<MapDownloadResult>) {
    thread::spawn(move || {
        println!("\x1b[36m[MAP] Определение геолокации...\x1b[0m");

        let output = Command::new("curl")
            .args(&["-s", "-L", "--connect-timeout", "4", "http://ip-api.com/json"])
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

        let tile_mirrors = [
            format!("https://a.tile.openstreetmap.de/{}/{}/{}.png", zoom, x, y),
            format!("https://tile.openstreetmap.org/{}/{}/{}.png", zoom, x, y),
            format!("https://tile.openstreetmap.fr/osmfr/{}/{}/{}.png", zoom, x, y),
        ];

        let mut downloaded_png = None;

        for mirror_url in &tile_mirrors {
            let tile_output = Command::new("curl")
                .args(&[
                    "-s",
                    "-L",
                    "-A",
                    "SpiderManHUD/1.0 (Wearable; contact: dev@stark.local)",
                    "--connect-timeout",
                    "5",
                    mirror_url,
                ])
                .output();

            if let Ok(tile_out) = tile_output {
                if is_valid_png(&tile_out.stdout) {
                    println!("\x1b[32m[MAP] Реальная карта OSM успешно загружена ({} байт)!\x1b[0m", tile_out.stdout.len());
                    downloaded_png = Some(tile_out.stdout);
                    break;
                }
            }
        }

        if let Some(png_bytes) = downloaded_png {
            let _ = tx.send(MapDownloadResult {
                city,
                country,
                lat,
                lon,
                png_bytes,
            });
        } else {
            let _ = tx.send(MapDownloadResult {
                city,
                country,
                lat,
                lon,
                png_bytes: Vec::new(),
            });
        }
    });
}

// -------------------------------------------------------------
// ЖИВОЙ РАДАР РЕАЛЬНЫХ САМОЛЁТОВ ЧЕРЕЗ OPENSKY NETWORK (ADS-B)
// -------------------------------------------------------------
fn parse_opensky_states(json: &str, player_lat: f64, player_lon: f64) -> Vec<PlaneMarker> {
    let mut planes = Vec::new();
    if let Some(states_pos) = json.find("\"states\":[") {
        let tail = &json[states_pos + 10..];
        for item in tail.split("],[") {
            let clean = item.trim_start_matches('[').trim_end_matches(']').trim_end_matches('}');
            let tokens: Vec<&str> = clean.split(',').collect();
            // Index 1: callsign, 5: lon, 6: lat, 7: baro_altitude, 9: velocity, 10: true_track
            if tokens.len() >= 11 {
                let callsign = tokens[1].trim().trim_matches('"').trim();
                if callsign.is_empty() || callsign == "null" {
                    continue;
                }
                let lon = tokens[5].trim().parse::<f64>().unwrap_or(0.0);
                let lat = tokens[6].trim().parse::<f64>().unwrap_or(0.0);
                let alt_m = tokens[7].trim().parse::<f64>().unwrap_or(3000.0);
                let speed_ms = tokens[9].trim().parse::<f64>().unwrap_or(200.0);
                let heading = tokens[10].trim().parse::<f32>().unwrap_or(0.0);

                if lat != 0.0 && lon != 0.0 {
                    let d_lat_km = (lat - player_lat) * 111.0;
                    let d_lon_km = (lon - player_lon) * 111.0 * player_lat.to_radians().cos();

                    // Масштаб: 1 км = 2.4 пикселя радара
                    let offset_x = (d_lon_km * 2.4) as f32;
                    let offset_y = (-d_lat_km * 2.4) as f32;

                    if offset_x.hypot(offset_y) < 130.0 {
                        planes.push(PlaneMarker {
                            callsign: callsign.to_string(),
                            offset: vec2(offset_x, offset_y),
                            heading,
                            altitude_ft: (alt_m * 3.28084) as u32,
                            speed_kmh: (speed_ms * 3.6) as u32,
                        });
                    }
                }
            }
        }
    }
    planes
}

fn start_live_adsb_fetch(lat: f64, lon: f64, tx: Sender<Vec<PlaneMarker>>) {
    thread::spawn(move || {
        println!("\x1b[36m[ADS-B] Запуск живого радара OpenSky для координат ({:.3}, {:.3})...\x1b[0m", lat, lon);
        let box_radius = 0.45;
        let url = format!(
            "https://opensky-network.org/api/states/all?lamin={:.4}&lomin={:.4}&lamax={:.4}&lomax={:.4}",
            lat - box_radius,
            lon - box_radius * 1.5,
            lat + box_radius,
            lon + box_radius * 1.5
        );

        loop {
            let output = Command::new("curl")
                .args(&["-s", "--connect-timeout", "6", &url])
                .output();

            if let Ok(out) = output {
                if let Ok(json) = String::from_utf8(out.stdout) {
                    let planes = parse_opensky_states(&json, lat, lon);
                    if !planes.is_empty() {
                        println!("\x1b[32m[ADS-B] Обнаружено {} реальных бортов в небе!\x1b[0m", planes.len());
                        let _ = tx.send(planes);
                    }
                }
            }

            // Опрос каждые 12 секунд (бесплатный лимит OpenSky)
            thread::sleep(std::time::Duration::from_secs(12));
        }
    });
}

// -------------------------------------------------------------
// РЕАЛЬНЫЙ BLUETOOTH / IPC СЕРВИС
// -------------------------------------------------------------
fn parse_and_dispatch_bt_event(raw: &str, tx: &Sender<BtEvent>) {
    if raw.is_empty() {
        return;
    }

    let parts: Vec<&str> = raw.split('|').collect();
    match parts[0].to_uppercase().as_str() {
        "IMU" => {
            if parts.len() >= 4 {
                let yaw = parts[1].trim().parse::<f32>().unwrap_or(0.0);
                let pitch = parts[2].trim().parse::<f32>().unwrap_or(0.0);
                let roll = parts[3].trim().parse::<f32>().unwrap_or(0.0);
                let _ = tx.send(BtEvent::ImuOrientation { yaw, pitch, roll });
            }
        }
        "HDG" => {
            if let Some(val) = parts.get(1) {
                if let Ok(yaw) = val.trim().parse::<f32>() {
                    let _ = tx.send(BtEvent::ImuOrientation { yaw, pitch: 0.0, roll: 0.0 });
                }
            }
        }
        "NOTIF" => {
            let app = parts.get(1).unwrap_or(&"PHONE").to_string();
            let sender = parts.get(2).unwrap_or(&"UNKNOWN").to_string();
            let text = parts.get(3..).map(|p| p.join("|")).unwrap_or_else(|| "New message".to_string());
            let _ = tx.send(BtEvent::Notification { app, sender, text });
        }
        "MEDIA" => {
            let title = parts.get(1).unwrap_or(&"Unknown Track").to_string();
            let artist = parts.get(2).unwrap_or(&"Unknown Artist").to_string();
            let status = parts.get(3).unwrap_or(&"PLAY").to_uppercase();
            let is_playing = status.contains("PLAY") || status == "1" || status == "TRUE";
            let _ = tx.send(BtEvent::MediaTrack { title, artist, is_playing });
        }
        "HR" | "PULSE" => {
            if let Some(val_str) = parts.get(1) {
                if let Ok(bpm) = val_str.parse::<f32>() {
                    let _ = tx.send(BtEvent::HeartRate { bpm });
                }
            }
        }
        "SENSE" | "DANGER" => {
            let active = parts.get(1).map(|v| *v == "1" || v.to_uppercase() == "TRUE").unwrap_or(true);
            let text = parts.get(2).unwrap_or(&"<! DANGER: REAR PROXIMITY 0.8M !>").to_string();
            let _ = tx.send(BtEvent::SpiderSense { active, text });
        }
        "STATUS" | "BT" => {
            let connected = parts.get(1).map(|v| *v == "1" || v.to_uppercase() == "TRUE").unwrap_or(true);
            let device_name = parts.get(2).unwrap_or(&"SMARTPHONE").to_string();
            let phone_battery = parts.get(3).and_then(|b| b.parse::<u8>().ok());
            let _ = tx.send(BtEvent::Status { connected, device_name, phone_battery });
        }
        "KAREN" => {
            let text = parts.get(1..).map(|p| p.join("|")).unwrap_or_else(|| "Systems operational.".to_string());
            let _ = tx.send(BtEvent::KarenSpeech { text });
        }
        _ => {
            if raw.starts_with('{') {
                if let Some(event_type) = json_val(raw, "type").or_else(|| json_val(raw, "cmd")) {
                    match event_type.to_lowercase().as_str() {
                        "imu" => {
                            let yaw = json_val(raw, "yaw").and_then(|v| v.parse::<f32>().ok()).unwrap_or(0.0);
                            let pitch = json_val(raw, "pitch").and_then(|v| v.parse::<f32>().ok()).unwrap_or(0.0);
                            let roll = json_val(raw, "roll").and_then(|v| v.parse::<f32>().ok()).unwrap_or(0.0);
                            let _ = tx.send(BtEvent::ImuOrientation { yaw, pitch, roll });
                        }
                        "notif" | "notification" => {
                            let app = json_val(raw, "app").unwrap_or_else(|| "PHONE".to_string());
                            let sender = json_val(raw, "sender").unwrap_or_else(|| "MESSAGE".to_string());
                            let text = json_val(raw, "text").or_else(|| json_val(raw, "body")).unwrap_or_default();
                            let _ = tx.send(BtEvent::Notification { app, sender, text });
                        }
                        "media" => {
                            let title = json_val(raw, "title").unwrap_or_else(|| "Track".to_string());
                            let artist = json_val(raw, "artist").unwrap_or_else(|| "Artist".to_string());
                            let playing = json_val(raw, "playing").map(|p| p == "true" || p == "1").unwrap_or(true);
                            let _ = tx.send(BtEvent::MediaTrack { title, artist, is_playing: playing });
                        }
                        "hr" | "pulse" => {
                            if let Some(bpm_str) = json_val(raw, "bpm") {
                                if let Ok(bpm) = bpm_str.parse::<f32>() {
                                    let _ = tx.send(BtEvent::HeartRate { bpm });
                                }
                            }
                        }
                        "sense" => {
                            let active = json_val(raw, "active").map(|a| a == "true" || a == "1").unwrap_or(true);
                            let text = json_val(raw, "text").unwrap_or_else(|| "<! DANGER: REAR PROXIMITY 0.8M !>".to_string());
                            let _ = tx.send(BtEvent::SpiderSense { active, text });
                        }
                        "status" => {
                            let connected = json_val(raw, "connected").map(|c| c == "true" || c == "1").unwrap_or(true);
                            let device_name = json_val(raw, "device").unwrap_or_else(|| "SMARTPHONE".to_string());
                            let phone_battery = json_val(raw, "battery").and_then(|b| b.parse::<u8>().ok());
                            let _ = tx.send(BtEvent::Status { connected, device_name, phone_battery });
                        }
                        _ => {}
                    }
                }
            }
        }
    }
}

fn start_bluetooth_listener(tx: Sender<BtEvent>) {
    let tx_sock = tx.clone();
    thread::spawn(move || {
        let addr = "127.0.0.1:9099";
        if let Ok(socket) = UdpSocket::bind(addr) {
            println!("\x1b[32m[BT-HUD] Bluetooth/IPC ресивер активен на {}\x1b[0m", addr);
            let mut buf = [0u8; 2048];
            loop {
                if let Ok((len, _src)) = socket.recv_from(&mut buf) {
                    if let Ok(msg_str) = std::str::from_utf8(&buf[..len]) {
                        parse_and_dispatch_bt_event(msg_str.trim(), &tx_sock);
                    }
                }
            }
        }
    });

    thread::spawn(move || {
        let mut last_track = String::new();
        let mut last_device = String::new();
        loop {
            thread::sleep(std::time::Duration::from_millis(1000));

            if let Ok(out) = Command::new("playerctl")
                .args(&["metadata", "--format", "{{status}}||{{artist}}||{{title}}"])
                .output()
            {
                if out.status.success() {
                    let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
                    if !s.is_empty() && (s != last_track) {
                        let parts: Vec<&str> = s.split("||").collect();
                        if parts.len() >= 3 {
                            let status = parts[0];
                            let artist = parts[1];
                            let title = parts[2];
                            let is_playing = status.to_lowercase().contains("play");

                            let _ = tx.send(BtEvent::MediaTrack {
                                title: if title.is_empty() { "UNKNOWN TRACK".to_string() } else { title.to_string() },
                                artist: if artist.is_empty() { "UNKNOWN ARTIST".to_string() } else { artist.to_string() },
                                is_playing,
                            });
                            last_track = s.clone();
                        }
                    }
                }
            }

            if let Ok(out) = Command::new("bluetoothctl")
                .args(&["devices", "Connected"])
                .output()
            {
                if out.status.success() {
                    let text = String::from_utf8_lossy(&out.stdout);
                    let line = text.lines().next().unwrap_or("");
                    if !line.is_empty() {
                        let parts: Vec<&str> = line.split_whitespace().collect();
                        if parts.len() >= 3 {
                            let dev_name = parts[2..].join(" ");
                            if dev_name != last_device {
                                let _ = tx.send(BtEvent::Status {
                                    connected: true,
                                    device_name: dev_name.clone(),
                                    phone_battery: None,
                                });
                                last_device = dev_name;
                            }
                        }
                    }
                }
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

// -------------------------------------------------------------
// МОДУЛЬ: ПАУЧЬЕ ЧУТЬЁ (SPIDER-SENSE DANGER WARNING)
// -------------------------------------------------------------
fn draw_spider_sense_warning(font: Option<&Font>, t: f32, warning_text: &str) {
    let w = screen_width();
    let h = screen_height();
    let flash = (t * 12.0).sin().abs() > 0.3;
    let color = if flash { HUD_RED } else { HUD_AMBER };

    for corner in 0..4 {
        let (bx, by, dir_x, dir_y) = match corner {
            0 => (40.0, 40.0, 1.0, 1.0),
            1 => (w - 40.0, 40.0, -1.0, 1.0),
            2 => (40.0, h - 40.0, 1.0, -1.0),
            _ => (w - 40.0, h - 40.0, -1.0, -1.0),
        };
        for s in 0..3 {
            let offset_a = (s as f32) * 22.0;
            draw_line(bx, by, bx + (30.0 + offset_a) * dir_x, by + 15.0 * dir_y, 2.5, color);
            draw_line(bx + (30.0 + offset_a) * dir_x, by + 15.0 * dir_y, bx + (50.0 + offset_a) * dir_x, by + 40.0 * dir_y, 2.0, HUD_WHITE);
        }
    }

    let cx = w * 0.5;
    let bw = 380.0;
    draw_rectangle(cx - bw * 0.5, 85.0, bw, 32.0, HUD_DARK);
    draw_bracket(cx - bw * 0.5, 85.0, bw, 32.0, 8.0, 1.5, color);
    txt(font, warning_text, cx - bw * 0.5 + 16.0, 106.0, 15, color);
}

// -------------------------------------------------------------
// МОДУЛЬ: МЕДИАПЛЕЕР И БИОМЕТРИЯ (ЭКГ + ЭКВАЛАЙЗЕР)
// -------------------------------------------------------------
fn draw_mediaplayer_and_biometrics(font: Option<&Font>, state: &VisorState) {
    let base_x = 35.0;
    let base_y = screen_height() - 175.0;

    draw_bracket(base_x, base_y, 240.0, 135.0, 10.0, 1.5, HUD_DIM);

    let status_icon = if state.media_is_playing { "NOW PLAYING ▶" } else { "PAUSED ⏸" };
    let status_color = if state.media_is_playing { HUD_CYAN } else { HUD_DIM };

    txt(font, status_icon, base_x + 12.0, base_y + 18.0, 13, status_color);

    let track_full = format!("{} - {}", state.media_track_artist, state.media_track_title);
    let track_truncated = if track_full.len() > 28 {
        format!("{}...", &track_full[..25])
    } else {
        track_full
    };
    txt(font, &track_truncated, base_x + 12.0, base_y + 34.0, 13, HUD_WHITE);

    for i in 0..12 {
        let bar_h = state.eq_bars[i] * 20.0;
        let bx = base_x + 12.0 + (i as f32) * 8.5;
        let by = base_y + 60.0 - bar_h;
        draw_rectangle(bx, by, 5.0, bar_h, HUD_CYAN);
    }

    let is_elevated = state.heart_rate_bpm > 110.0;
    let bpm_color = if is_elevated { HUD_RED } else { HUD_GREEN };
    txt(
        font,
        &format!("PULSE: {:.0} BPM [{}]", state.heart_rate_bpm, if is_elevated { "ELEVATED" } else { "NORMAL" }),
        base_x + 12.0,
        base_y + 82.0,
        14,
        bpm_color,
    );
    txt(font, "SpO2: 99% [OK]", base_x + 12.0, base_y + 98.0, 12, HUD_DIM);

    let ecg_y = base_y + 118.0;
    draw_line(base_x + 12.0, ecg_y, base_x + 225.0, ecg_y, 1.0, HUD_DARK);
    for i in 0..(state.ecg_buffer.len() - 1) {
        let x1 = base_x + 12.0 + (i as f32) * 3.5;
        let y1 = ecg_y - state.ecg_buffer[i];
        let x2 = base_x + 12.0 + ((i + 1) as f32) * 3.5;
        let y2 = ecg_y - state.ecg_buffer[i + 1];
        draw_line(x1, y1, x2, y2, 1.5, bpm_color);
    }
}

// -------------------------------------------------------------
// МОДУЛЬ: УВЕДОМЛЕНИЯ СО СМАРТФОНА И ДИАЛОГ С КАРЕН
// -------------------------------------------------------------
fn draw_popups(font: Option<&Font>, state: &VisorState) {
    let cx = screen_width() * 0.5;

    if state.notification_timer > 0.0 {
        let pw = 420.0;
        let ph = 52.0;

        let progress = (6.0 - state.notification_timer).clamp(0.0, 0.35) / 0.35;
        let target_y = 25.0;
        let start_y = -60.0;
        let current_y = start_y + (target_y - start_y) * (1.0 - (1.0 - progress).powi(2));

        draw_rectangle(cx - pw * 0.5, current_y, pw, ph, HUD_DARK);
        draw_bracket(cx - pw * 0.5, current_y, pw, ph, 8.0, 1.5, HUD_CYAN);

        let bar_w = (state.notification_timer / 6.0) * pw;
        draw_rectangle(cx - pw * 0.5, current_y + ph - 2.0, bar_w, 2.0, HUD_CYAN);

        txt(font, &state.notification_title, cx - pw * 0.5 + 14.0, current_y + 18.0, 13, HUD_WHITE);
        txt(font, &state.notification_body, cx - pw * 0.5 + 14.0, current_y + 36.0, 13, HUD_CYAN);
    }

    if state.karen_timer > 0.0 {
        if let Some(ref msg) = state.karen_text {
            let kw = 460.0;
            draw_rectangle(cx - kw * 0.5, 140.0, kw, 38.0, HUD_DARK);
            draw_bracket(cx - kw * 0.5, 140.0, kw, 38.0, 6.0, 1.2, HUD_GREEN);

            let wave_x = cx - kw * 0.5 + 20.0;
            let wave_y = 158.0;
            for i in 0..4 {
                let h = ((get_time() as f32 * 10.0 + i as f32).sin() * 8.0).abs() + 3.0;
                draw_line(wave_x + (i as f32) * 5.0, wave_y - h, wave_x + (i as f32) * 5.0, wave_y + h, 1.8, HUD_GREEN);
            }

            txt(font, msg, cx - kw * 0.5 + 48.0, 163.0, 14, HUD_WHITE);
        }
    }
}

// -------------------------------------------------------------
// СТАРТОВАЯ АНИМАЦИЯ (BOOT SEQUENCE)
// -------------------------------------------------------------
fn draw_boot_sequence(font: Option<&Font>, t: f32) {
    let cx = screen_width() * 0.5;
    let cy = screen_height() * 0.5;

    if t < 1.1 {
        let progress = (t / 1.1).clamp(0.0, 1.0);
        let openness = (progress * std::f32::consts::PI * 1.5).sin().abs().max(0.12);

        let eye_w = 60.0;
        let eye_h = 32.0 * openness;

        let rx = cx + 45.0;
        draw_line(rx - eye_w * 0.5, cy, rx, cy - eye_h, 3.0, HUD_CYAN);
        draw_line(rx, cy - eye_h, rx + eye_w * 0.5, cy - eye_h * 0.2, 3.0, HUD_WHITE);
        draw_line(rx + eye_w * 0.5, cy - eye_h * 0.2, rx - eye_w * 0.5, cy, 2.5, HUD_CYAN);

        let lx = cx - 45.0;
        draw_line(lx + eye_w * 0.5, cy, lx, cy - eye_h, 3.0, HUD_CYAN);
        draw_line(lx, cy - eye_h, lx - eye_w * 0.5, cy - eye_h * 0.2, 3.0, HUD_WHITE);
        draw_line(lx - eye_w * 0.5, cy - eye_h * 0.2, lx + eye_w * 0.5, cy, 2.5, HUD_CYAN);

        txt(font, "STARK INDUSTRIES // VISOR PROTOCOL", cx - 130.0, cy + 45.0, 16, HUD_WHITE);
        txt(font, "CALIBRATING OPTICAL APERTURE...", cx - 115.0, cy + 65.0, 14, HUD_CYAN);

        draw_rectangle(cx - 100.0, cy + 85.0, 200.0, 3.0, HUD_DARK);
        draw_rectangle(cx - 100.0, cy + 85.0, 200.0 * progress, 3.0, HUD_CYAN);
    } else if t < 2.5 {
        let web_t = (t - 1.1) / 1.4;
        let max_r = 180.0 * web_t.clamp(0.1, 1.0);

        for i in 0..8 {
            let angle = (i as f32) * (std::f32::consts::PI / 4.0);
            let ex = cx + angle.cos() * max_r;
            let ey = cy + angle.sin() * max_r;
            draw_line(cx, cy, ex, ey, 1.2, HUD_DIM);
        }

        for ring in 1..=3 {
            let r_radius = (ring as f32) * (max_r / 3.0);
            for i in 0..8 {
                let a1 = (i as f32) * (std::f32::consts::PI / 4.0);
                let a2 = ((i + 1) as f32) * (std::f32::consts::PI / 4.0);
                let p1 = vec2(cx + a1.cos() * r_radius, cy + a1.sin() * r_radius);
                let p2 = vec2(cx + a2.cos() * r_radius, cy + a2.sin() * r_radius);
                draw_line(p1.x, p1.y, p2.x, p2.y, 1.0, HUD_CYAN);
            }
        }

        let s_scale = 1.2;
        draw_line(cx, cy - 14.0 * s_scale, cx, cy + 16.0 * s_scale, 4.0, HUD_WHITE);
        draw_circle(cx, cy - 8.0 * s_scale, 5.0, HUD_CYAN);
        draw_circle(cx, cy + 6.0 * s_scale, 6.0, HUD_WHITE);

        let draw_leg = |x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32| {
            draw_line(cx + x1 * s_scale, cy + y1 * s_scale, cx + x2 * s_scale, cy + y2 * s_scale, 2.2, HUD_CYAN);
            draw_line(cx + x2 * s_scale, cy + y2 * s_scale, cx + x3 * s_scale, cy + y3 * s_scale, 1.8, HUD_WHITE);
        };

        draw_leg(2.0, -8.0, 18.0, -20.0, 26.0, -12.0);
        draw_leg(3.0, -4.0, 24.0, -8.0, 32.0, 4.0);
        draw_leg(3.0, 4.0, 22.0, 14.0, 30.0, 26.0);
        draw_leg(2.0, 8.0, 16.0, 22.0, 20.0, 34.0);

        draw_leg(-2.0, -8.0, -18.0, -20.0, -26.0, -12.0);
        draw_leg(-3.0, -4.0, -24.0, -8.0, -32.0, 4.0);
        draw_leg(-3.0, 4.0, -22.0, 14.0, -30.0, 26.0);
        draw_leg(-2.0, 8.0, -16.0, 22.0, -20.0, 34.0);

        txt(font, "> SUIT DIAGNOSTICS: NOMINAL", cx - 110.0, cy + 95.0, 14, HUD_GREEN);
        txt(font, "> KAREN AI: ONLINE", cx - 110.0, cy + 115.0, 14, HUD_CYAN);
        txt(font, "> 6-DOF IMU & LIVE ADS-B: ACTIVE", cx - 110.0, cy + 135.0, 14, HUD_WHITE);
    } else if t < 3.4 {
        let expand_t = (t - 2.5) / 0.9;
        let ring_radius = 200.0 + expand_t * 600.0;
        draw_circle_lines(cx, cy, ring_radius, 2.0, HUD_CYAN);

        if ((t * 8.0) as i32) % 2 == 0 {
            txt(font, "[ SYSTEM READY // WELCOME PETER ]", cx - 145.0, cy, 18, HUD_GREEN);
        }
    }
}

// -------------------------------------------------------------
// 1. БЛОК СЕТИ, IMU И BLUETOOTH СЛЕВА СВЕРХУ
// -------------------------------------------------------------
fn draw_telemetry_top_left(font: Option<&Font>, state: &VisorState) {
    let base_x = 35.0;
    let base_y = 35.0;

    txt(font, "[ 88 ]", base_x, base_y, 18, HUD_DIM);
    txt(font, "[ 16:9 ]", base_x + 70.0, base_y, 18, HUD_DIM);
    txt(font, "[ RAW ]", base_x + 155.0, base_y, 18, HUD_DIM);

    let box_y = base_y + 15.0;
    draw_bracket(base_x, box_y, 205.0, 105.0, 12.0, 1.5, HUD_CYAN);

    let bt_status_text = if state.bt_connected { "BT: SYNCED" } else { "BT: READY" };
    let bt_status_color = if state.bt_connected { HUD_GREEN } else { HUD_CYAN };
    txt(font, bt_status_text, base_x + 14.0, box_y + 26.0, 18, HUD_WHITE);

    let icon_x = base_x + 180.0;
    let icon_y = box_y + 22.0;
    draw_line(icon_x, icon_y - 8.0, icon_x, icon_y + 8.0, 2.0, bt_status_color);
    draw_line(icon_x, icon_y - 8.0, icon_x + 6.0, icon_y - 2.0, 1.8, bt_status_color);
    draw_line(icon_x + 6.0, icon_y - 2.0, icon_x - 5.0, icon_y + 5.0, 1.8, bt_status_color);
    draw_line(icon_x - 5.0, icon_y - 5.0, icon_x + 6.0, icon_y + 2.0, 1.8, bt_status_color);
    draw_line(icon_x + 6.0, icon_y + 2.0, icon_x, icon_y + 8.0, 1.8, bt_status_color);

    // Статус датчика положения головы (IMU 6-DOF)
    if state.imu_active {
        txt(font, "HEAD: 6-DOF MPU [OK]", base_x + 14.0, box_y + 48.0, 13, HUD_GREEN);
    } else {
        let dev_label = if state.bt_connected {
            if state.bt_device_name.len() > 18 {
                format!("{}...", &state.bt_device_name[..15])
            } else {
                state.bt_device_name.clone()
            }
        } else {
            "PORT: 9099 / BLUEZ".to_string()
        };
        txt(font, &dev_label, base_x + 14.0, box_y + 48.0, 13, HUD_CYAN);
    }

    if let Some(bat) = state.bt_phone_battery {
        txt(font, &format!("PHONE BAT: {}%", bat), base_x + 14.0, box_y + 68.0, 14, HUD_CYAN);
    } else {
        txt(font, "SIGNAL: -58 dBm [OK]", base_x + 14.0, box_y + 68.0, 13, HUD_DIM);
    }

    txt(font, "LINK RSSI", base_x + 14.0, box_y + 90.0, 14, HUD_DIM);
    for i in 0..5 {
        let bar_h = 4.0 + i as f32 * 3.0;
        let bx = base_x + 130.0 + i as f32 * 8.0;
        let by = box_y + 92.0 - bar_h;
        let col = if state.bt_connected || i < 3 { HUD_CYAN } else { HUD_DARK };
        draw_rectangle(bx, by, 5.0, bar_h, col);
    }
}

// -------------------------------------------------------------
// 2. РАДАР С КАРТОЙ И ЖИВЫМИ САМОЛЁТАМИ (RENDER TARGET)
// -------------------------------------------------------------
fn draw_minimap_top_right(font: Option<&Font>, state: &VisorState) {
    let w = screen_width();
    let map_w = 185.0;
    let map_h = 155.0;
    let base_x = w - map_w - 40.0;
    let base_y = 35.0;
    let box_y = base_y + 45.0;
    let rad = state.heading_deg.to_radians();

    let radar_cx = map_w * 0.5;
    let radar_cy = map_h * 0.5;

    // 1. РЕНДЕРИНГ В ИЗОЛИРОВАННЫЙ RENDER TARGET (185x155)
    set_camera(&state.radar_cam);

    clear_background(HUD_DARK);

    // Радарная сетка
    draw_circle_lines(radar_cx, radar_cy, 35.0, 1.0, HUD_DIM);
    draw_circle_lines(radar_cx, radar_cy, 65.0, 1.0, HUD_DIM);
    draw_line(radar_cx - 70.0, radar_cy, radar_cx + 70.0, radar_cy, 1.0, HUD_DIM);
    draw_line(radar_cx, radar_cy - 60.0, radar_cx, radar_cy + 60.0, 1.0, HUD_DIM);

    // Отрисовка карты с вращением вокруг центра радара
    if let Some(ref tex) = state.map_texture {
        let tex_size = 320.0;
        let clamped_offset = vec2(
            state.map_offset.x.clamp(-70.0, 70.0),
            state.map_offset.y.clamp(-70.0, 70.0),
        );

        draw_texture_ex(
            tex,
            radar_cx - tex_size * 0.5 - clamped_offset.x,
            radar_cy - tex_size * 0.5 - clamped_offset.y,
            Color::new(0.9, 0.95, 1.0, 0.95),
            DrawTextureParams {
                dest_size: Some(vec2(tex_size, tex_size)),
                rotation: rad,
                pivot: Some(vec2(radar_cx, radar_cy)),
                ..Default::default()
            },
        );
    }

    // Маркер позиции игрока (по центру радара)
    let pulse = (state.radar_pulse.sin() * 0.5 + 0.5).max(0.1);
    draw_circle(radar_cx, radar_cy, 3.5, HUD_WHITE);
    draw_circle_lines(radar_cx, radar_cy, 8.0 + pulse * 6.0, 1.5, HUD_CYAN);

    // Стрелочка курса
    let tip = vec2(radar_cx - 16.0 * rad.sin(), radar_cy - 16.0 * rad.cos());
    draw_line(radar_cx, radar_cy, tip.x, tip.y, 2.5, HUD_WHITE);

    // Самолёты ADS-B (иконки внутри радара)
    for plane in &state.planes {
        let p_pos = vec2(radar_cx + plane.offset.x, radar_cy + plane.offset.y);
        let p_rad = (plane.heading - state.heading_deg).to_radians();
        let nose = p_pos + vec2(p_rad.sin(), -p_rad.cos()) * 6.0;
        let wing_l = p_pos + vec2((p_rad + 2.5).sin(), -(p_rad + 2.5).cos()) * 5.0;
        let wing_r = p_pos + vec2((p_rad - 2.5).sin(), -(p_rad - 2.5).cos()) * 5.0;
        draw_triangle(nose, wing_l, wing_r, HUD_WHITE);
    }

    // 2. ВОЗВРАТ К ОСНОВНОМУ ЭКРАНУ И ВЫВОД РАДАРА
    set_default_camera();

    // Заголовки над радаром (показывает количество живых бортов)
    let header_label = if state.real_adsb_count > 0 {
        format!("AIRSPACE // {} LIVE ADS-B", state.real_adsb_count)
    } else {
        "LOCATION // AIRSPACE".to_string()
    };
    txt(font, &header_label, base_x, base_y, 14, if state.real_adsb_count > 0 { HUD_GREEN } else { HUD_DIM });
    txt(font, &state.city, base_x, base_y + 18.0, 20, HUD_WHITE);
    txt(font, &state.country, base_x, base_y + 36.0, 16, HUD_CYAN);

    // Отрисовка полученной изолированной текстуры радара
    draw_texture_ex(
        &state.radar_target.texture,
        base_x,
        box_y,
        WHITE,
        DrawTextureParams {
            dest_size: Some(vec2(map_w, map_h)),
            flip_y: true,
            ..Default::default()
        },
    );

    // Метки позывных самолётов поверх (в векторных экранных координатах)
    let screen_center = vec2(base_x + map_w * 0.5, box_y + map_h * 0.5);
    for plane in &state.planes {
        let p_pos = screen_center + plane.offset;
        if p_pos.x > base_x + 5.0 && p_pos.x < base_x + map_w - 5.0 && p_pos.y > box_y + 5.0 && p_pos.y < box_y + map_h - 5.0 {
            txt(font, &plane.callsign, p_pos.x + 8.0, p_pos.y - 2.0, 11, HUD_CYAN);
            txt(font, &format!("{}m", plane.altitude_ft / 3), p_pos.x + 8.0, p_pos.y + 8.0, 10, HUD_DIM);
        }
    }

    // Кибер-рамка вокруг радара
    draw_bracket(base_x, box_y, map_w, map_h, 10.0, 1.5, HUD_CYAN);

    // Азимут компаса
    txt(
        font,
        &format!("HDG: {:03.0}°", state.heading_deg.rem_euclid(360.0)),
        base_x + 10.0,
        box_y + map_h - 10.0,
        15,
        HUD_CYAN,
    );

    if state.map_loading {
        txt(font, "SYNCING MAP...", base_x + 35.0, box_y + 20.0, 12, HUD_CYAN);
    }
}

// -------------------------------------------------------------
// 3. БЛОК ТЕЛЕМЕТРИИ КОСТЮМА СПРАВА СНИЗУ
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// 4. ДИНАМИЧЕСКИЙ АВИАЦИОННЫЙ ГОРИЗОНТ (ИНКЛИНОМЕТР ТАНГАЖА И КРЕНА)
// -------------------------------------------------------------
fn draw_minimal_center_horizon(pitch_deg: f32, roll_deg: f32) {
    let cx = screen_width() * 0.5;
    let cy = screen_height() * 0.5 - pitch_deg.clamp(-35.0, 35.0) * 3.5;

    let rad = (-roll_deg).to_radians();
    let cos_r = rad.cos();
    let sin_r = rad.sin();

    let rotate_pt = |ox: f32, oy: f32| -> Vec2 {
        vec2(cx + ox * cos_r - oy * sin_r, cy + ox * sin_r + oy * cos_r)
    };

    draw_circle(cx, cy, 2.5, HUD_CYAN);

    // Линии горизонта
    let l1 = rotate_pt(-75.0, 0.0);
    let l2 = rotate_pt(-30.0, 0.0);
    draw_line(l1.x, l1.y, l2.x, l2.y, 1.5, HUD_DIM);

    let r1 = rotate_pt(30.0, 0.0);
    let r2 = rotate_pt(75.0, 0.0);
    draw_line(r1.x, r1.y, r2.x, r2.y, 1.5, HUD_DIM);

    let l_notch = rotate_pt(-30.0, 6.0);
    draw_line(l2.x, l2.y, l_notch.x, l_notch.y, 1.5, HUD_DIM);

    let r_notch = rotate_pt(30.0, 6.0);
    draw_line(r1.x, r1.y, r_notch.x, r_notch.y, 1.5, HUD_DIM);

    // Засечки угла тангажа (+10° и -10°)
    let p_up1 = rotate_pt(-20.0, -35.0);
    let p_up2 = rotate_pt(20.0, -35.0);
    draw_line(p_up1.x, p_up1.y, p_up2.x, p_up2.y, 1.0, HUD_DARK);

    let p_dn1 = rotate_pt(-20.0, 35.0);
    let p_dn2 = rotate_pt(20.0, 35.0);
    draw_line(p_dn1.x, p_dn1.y, p_dn2.x, p_dn2.y, 1.0, HUD_DARK);
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

    // Запуск фонового загрузчика карты
    let (tx_map, rx_map): (Sender<MapDownloadResult>, Receiver<MapDownloadResult>) = channel();
    start_map_fetch(tx_map);

    // Канал живого радара реальных самолётов OpenSky
    let (tx_adsb, rx_adsb): (Sender<Vec<PlaneMarker>>, Receiver<Vec<PlaneMarker>>) = channel();
    let mut adsb_started = false;

    // Запуск фонового ресивера Bluetooth / IPC сокета (порт 9099)
    let (tx_bt, rx_bt): (Sender<BtEvent>, Receiver<BtEvent>) = channel();
    start_bluetooth_listener(tx_bt);

    loop {
        let dt = get_frame_time();
        state.update(dt);

        // Прием событий от Bluetooth и гироскопа
        while let Ok(event) = rx_bt.try_recv() {
            state.apply_bt_event(event);
        }

        // Прием обновления живых бортов ADS-B в небе
        while let Ok(live_planes) = rx_adsb.try_recv() {
            state.real_adsb_count = live_planes.len();
            state.planes = live_planes;
        }

        // Прием загруженной карты
        if let Ok(res) = rx_map.try_recv() {
            state.city = res.city;
            state.country = res.country;
            state.player_lat = res.lat;
            state.player_lon = res.lon;
            state.map_loading = false;

            // Запускаем живой радар OpenSky вокруг реальных координат игрока
            if !adsb_started {
                start_live_adsb_fetch(res.lat, res.lon, tx_adsb.clone());
                adsb_started = true;
            }

            if !res.png_bytes.is_empty() {
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
                }
            }
        }

        clear_background(HUD_BG);

        if state.boot_timer < 3.4 {
            draw_boot_sequence(font.as_ref(), state.boot_timer);
        } else {
            draw_telemetry_top_left(font.as_ref(), &state);
            draw_minimap_top_right(font.as_ref(), &state);
            draw_suit_telemetry_bottom_right(font.as_ref(), &state);
            draw_mediaplayer_and_biometrics(font.as_ref(), &state);
            draw_minimal_center_horizon(state.pitch_deg, state.roll_deg);
            draw_popups(font.as_ref(), &state);

            if state.spider_sense_active {
                draw_spider_sense_warning(font.as_ref(), state.spider_sense_timer, &state.spider_sense_text);
            }

            txt(
                font.as_ref(),
                "[P: SPIDER-SENSE] [N: NOTIF] [M: MUSIC] [K: KAREN] [W/S: MOVE] [UP/DN: TILT] [IMU: 6-DOF]",
                35.0,
                screen_height() - 25.0,
                13,
                HUD_DIM,
            );
        }

        next_frame().await;
    }
}
