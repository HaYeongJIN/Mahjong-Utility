use crate::api::parser;
use crate::api::calculator;

#[flutter_rust_bridge::frb(sync)]
pub fn calculate_mahjong_from_camera(
    tiles: Vec<i32>,
    dora_indicators: Vec<i32>,    
    last_tile_angle: f32,       
    _last_tile_distance: f32,   
    is_riichi: bool,
    is_ippatsu: bool,
    is_haitei: bool,
    is_houtei: bool,
    is_chankan: bool,
    prevalent_wind: String,
    seat_wind: String,
    honba: i32,
    override_hand: String, 
    override_dora: String, 
) -> String {
    
    let is_tsumo_ui_checked = last_tile_angle > 0.5;
    let is_menzen_tsumo_ui_checked = _last_tile_distance > 0.5;
    let is_tsumo = is_tsumo_ui_checked || is_menzen_tsumo_ui_checked;
    
    let force_closed = is_riichi || is_menzen_tsumo_ui_checked;
    let total_tiles_count = tiles.len(); 

    let (display_dora_str, actual_doras, actual_uradoras) = 
        parser::parse_doras(dora_indicators, override_dora, is_riichi);

    let final_hand_str = if override_hand.is_empty() {
        parser::build_final_hand_string(tiles, force_closed, total_tiles_count)
    } else {
        override_hand
    };

    calculator::calculate_score_logic(
        &final_hand_str, &display_dora_str, is_tsumo, is_menzen_tsumo_ui_checked, force_closed, 
        is_riichi, is_ippatsu, is_haitei, is_houtei, is_chankan, prevalent_wind, seat_wind, honba,
        actual_doras, actual_uradoras
    )
}

#[flutter_rust_bridge::frb(sync)]
pub fn calculate_shanten_and_wait(
    tiles: Vec<i32>,
    override_hand: String, 
) -> String {
    let final_hand_str = if override_hand.is_empty() {
        parser::build_final_hand_string(tiles, false, 13) 
    } else {
        override_hand
    };

    calculator::calculate_shanten_wait(&final_hand_str)
}

#[flutter_rust_bridge::frb(sync)]
pub fn convert_yuv_to_rgb_tensor(
    y_bytes: Vec<u8>,
    u_bytes: Vec<u8>,
    v_bytes: Vec<u8>,
    y_row_stride: u32,
    uv_row_stride: u32,
    uv_pixel_stride: u32,
    width: u32,
    height: u32,
) -> Vec<f32> {
    let mut tensor = vec![0.0_f32; 1_228_800];
    let mut index = 0;

    let width = width as usize;
    let height = height as usize;
    let y_row_stride = y_row_stride as usize;
    let uv_row_stride = uv_row_stride as usize;
    let uv_pixel_stride = uv_pixel_stride as usize;

    for y in 0..640 {
        let sy = ((y * height) / 640).clamp(0, height - 1);
        let py = sy * y_row_stride;
        let puv = (sy >> 1) * uv_row_stride;

        for x in 0..640 {
            let sx = ((x * width) / 640).clamp(0, width - 1);
            let yp = y_bytes[py + sx] as f32;
            let uv_idx = (sx >> 1) * uv_pixel_stride;

            let u = u_bytes[puv + uv_idx] as f32 - 128.0;
            let v = v_bytes[puv + uv_idx] as f32 - 128.0;

            let r = (yp + 1.402 * v).clamp(0.0, 255.0) / 255.0;
            let g = (yp - 0.344 * u - 0.714 * v).clamp(0.0, 255.0) / 255.0;
            let b = (yp + 1.772 * u).clamp(0.0, 255.0) / 255.0;

            tensor[index] = r;
            tensor[index + 1] = g;
            tensor[index + 2] = b;
            index += 3;
        }
    }
    tensor
}