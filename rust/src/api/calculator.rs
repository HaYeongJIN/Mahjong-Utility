use agari::context::{GameContext, WinType};
use agari::hand::decompose_hand_with_melds;
use agari::parse::{parse_hand_with_aka, to_counts};
use agari::scoring::calculate_score as compute_agari_score;
use agari::tile::Honor;
use agari::yaku::detect_yaku_with_context;
use agari::shanten::calculate_shanten;

pub(crate) fn calculate_score_logic(
    final_hand_str: &str, display_dora_str: &str, is_tsumo: bool, is_menzen_tsumo_ui_checked: bool,
    force_closed: bool, is_riichi: bool, is_ippatsu: bool, is_haitei: bool, is_houtei: bool, is_chankan: bool,
    prevalent_wind: String, seat_wind: String, honba: i32, actual_doras: Vec<String>, actual_uradoras: Vec<String>
) -> String {
    let ui_aka_dora = final_hand_str.matches('0').count() as i32;
    let mut ui_regular_dora = 0;
    let mut ui_ura_dora = 0;

    let mut current_nums_h = Vec::new();
    for c in final_hand_str.chars() {
        if c.is_ascii_digit() {
            current_nums_h.push(c);
        } else if c == 'm' || c == 'p' || c == 's' || c == 'z' {
            for num in current_nums_h.drain(..) {
                let mut base_name = format!("{}{}", num, c);
                if base_name.starts_with('0') { base_name = base_name.replace("0", "5"); }
                
                if actual_doras.contains(&base_name) { ui_regular_dora += 1; }
                if is_riichi && actual_uradoras.contains(&base_name) { ui_ura_dora += 1; }
            }
        }
    }

    // 🔥 외부 라이브러리 객체(Tile)는 여기서 안전하게 내부적으로만 생성합니다.
    let mut engine_dora_tiles = Vec::new();
    for dora in &actual_doras {
        if let Ok(p) = parse_hand_with_aka(dora) {
            engine_dora_tiles.extend(p.tiles);
        }
    }
    
    let mut engine_ura_tiles = Vec::new();
    if is_riichi {
        for ura in &actual_uradoras {
            if let Ok(p) = parse_hand_with_aka(ura) {
                engine_ura_tiles.extend(p.tiles);
            }
        }
    }

    let parsed = match parse_hand_with_aka(final_hand_str) {
        Ok(p) => p,
        Err(_) => return format!("문자열 파싱 오류\n올바른 마작 표기법인지 확인해주세요.\n---\n도라표시패:{}\n손패:{}", display_dora_str, final_hand_str),
    };

    let counts = to_counts(&parsed.tiles);
    let converted_melds: Vec<_> = parsed.called_melds.iter().map(|m| m.meld.clone()).collect();
    let structures = decompose_hand_with_melds(&counts, &converted_melds);
    
    if structures.is_empty() { return format!("화료 형태가 아닙니다\n---\n도라표시패:{}\n손패:{}", display_dora_str, final_hand_str); }

    let win_type = if is_tsumo { WinType::Tsumo } else { WinType::Ron };
    let p_wind = match prevalent_wind.as_str() { "남" => Honor::South, "서" => Honor::West, "북" => Honor::North, _ => Honor::East };
    let s_wind = match seat_wind.as_str() { "남" => Honor::South, "서" => Honor::West, "북" => Honor::North, _ => Honor::East };

    let mut ctx = GameContext::new(win_type, p_wind, s_wind);
    let physical_has_open_meld = final_hand_str.contains('(');
    let mut is_hand_open = physical_has_open_meld;
    
    if force_closed { is_hand_open = false; } 
    else if is_tsumo && !is_menzen_tsumo_ui_checked && !is_riichi { is_hand_open = true; }

    if is_hand_open { ctx = ctx.open(); }
    
    if let Some(real_winning_tile) = parsed.tiles.last() {
        ctx = ctx.with_winning_tile(real_winning_tile.clone());
    }

    if is_riichi { ctx = ctx.riichi(); }
    if is_ippatsu { ctx = ctx.ippatsu(); }
    if is_haitei || is_houtei { ctx = ctx.last_tile(); }
    if is_chankan { ctx = ctx.chankan(); }
    
    if !engine_dora_tiles.is_empty() { ctx = ctx.with_dora(engine_dora_tiles); }
    if !engine_ura_tiles.is_empty() { ctx = ctx.with_ura_dora(engine_ura_tiles); }
    ctx = ctx.with_aka(ui_aka_dora as u8); 

    let best = structures.iter().map(|s| {
        let yaku = detect_yaku_with_context(s, &counts, &ctx);
        let score = compute_agari_score(s, &yaku, &ctx);
        (s, yaku, score)
    }).max_by(|a, b| a.2.payment.total.cmp(&b.2.payment.total).then_with(|| a.2.han.cmp(&b.2.han)));

    let (_, best_yaku, best_score) = match best {
        Some(b) => b, None => return format!("점수 계산 실패\n---\n도라표시패:{}\n손패:{}", display_dora_str, final_hand_str),
    };

    let yaku_debug_full = format!("{:#?}", best_yaku);

    let get_struct_val = |key: &str| -> i32 {
        if let Some(idx) = yaku_debug_full.find(key) {
            let start = idx + key.len();
            let num_str: String = yaku_debug_full[start..].chars().take_while(|c| c.is_ascii_digit()).collect();
            num_str.parse::<i32>().unwrap_or(0)
        } else { 0 }
    };

    let pure_yaku_han = get_struct_val("total_han: ");
    if pure_yaku_han == 0 {
        return format!("역 없음 (0판)\n화료 불가\n---\n도라표시패:{}\n손패:{}", display_dora_str, final_hand_str);
    }

    let fu_val = best_score.fu.total as i32;

    let mut han_val = pure_yaku_han + ui_regular_dora + ui_aka_dora;
    if is_riichi { han_val += ui_ura_dora; }

    let mut basic_points = fu_val * (1 << (han_val + 2));
    let mut score_level_str = format!("{}판 {}부", han_val, fu_val);

    if pure_yaku_han >= 13 { basic_points = 8000; score_level_str = "역만".to_string(); }
    else if han_val >= 13 { basic_points = 8000; score_level_str = "헤아림 역만".to_string(); }
    else if han_val >= 11 { basic_points = 6000; score_level_str = "삼배만".to_string(); }
    else if han_val >= 8 { basic_points = 4000; score_level_str = "배만".to_string(); }
    else if han_val >= 6 { basic_points = 3000; score_level_str = "하네만".to_string(); }
    else if han_val >= 5 || (han_val == 4 && fu_val >= 40) || (han_val == 3 && fu_val >= 70) { 
        basic_points = 2000; score_level_str = "만관".to_string(); 
    }

    let is_oya = seat_wind == "동";
    let mut result_text = String::new();
    
    result_text.push_str(&format!("{}\n", score_level_str));

    if is_tsumo {
        if is_oya {
            let p_all = ((basic_points * 2) as f64 / 100.0).ceil() as i32 * 100 + (honba * 100);
            result_text.push_str(&format!("{} ALL 점\n", p_all));
        } else {
            let p_oya = ((basic_points * 2) as f64 / 100.0).ceil() as i32 * 100 + (honba * 100);
            let p_ko = ((basic_points) as f64 / 100.0).ceil() as i32 * 100 + (honba * 100);
            result_text.push_str(&format!("{}/{} 점\n", p_ko, p_oya)); 
        }
    } else {
        let p_total = if is_oya {
            ((basic_points * 6) as f64 / 100.0).ceil() as i32 * 100 + (honba * 300)
        } else {
            ((basic_points * 4) as f64 / 100.0).ceil() as i32 * 100 + (honba * 300)
        };
        result_text.push_str(&format!("{} 점\n", p_total));
    }

    let mut translated_yaku_list: Vec<String> = Vec::new();
    let yaku_lower = yaku_debug_full.to_lowercase();

    if yaku_lower.contains("menzentsumo") { translated_yaku_list.push("멘젠 쯔모".to_string()); }
    if yaku_lower.contains("riichi") && !yaku_lower.contains("double") { translated_yaku_list.push("리치".to_string()); }
    if yaku_lower.contains("double riichi") || yaku_lower.contains("daburu") { translated_yaku_list.push("더블 리치".to_string()); }
    if yaku_lower.contains("ippatsu") { translated_yaku_list.push("일발".to_string()); }
    if yaku_lower.contains("chankan") { translated_yaku_list.push("창깡".to_string()); }
    if yaku_lower.contains("rinshan") { translated_yaku_list.push("영상개화".to_string()); }
    if yaku_lower.contains("haitei") { translated_yaku_list.push("해저로월".to_string()); }
    if yaku_lower.contains("houtei") { translated_yaku_list.push("하저로어".to_string()); }
    if yaku_lower.contains("haku") || yaku_lower.contains("white") { translated_yaku_list.push("역패 백".to_string()); }
    if yaku_lower.contains("hatsu") || yaku_lower.contains("green") { translated_yaku_list.push("역패 발".to_string()); }
    if yaku_lower.contains("chun") || yaku_lower.contains("red") { translated_yaku_list.push("역패 중".to_string()); }
    if yaku_lower.contains("east") { translated_yaku_list.push("역패 동".to_string()); }
    if yaku_lower.contains("south") { translated_yaku_list.push("역패 남".to_string()); }
    if yaku_lower.contains("west") { translated_yaku_list.push("역패 서".to_string()); }
    if yaku_lower.contains("north") { translated_yaku_list.push("역패 북".to_string()); }
    if yaku_lower.contains("kokushi") { translated_yaku_list.push("국사무쌍".to_string()); }
    if yaku_lower.contains("daisangen") { translated_yaku_list.push("대삼원".to_string()); }
    if yaku_lower.contains("suuankou") { translated_yaku_list.push("쓰안커".to_string()); }
    if yaku_lower.contains("tsuuiisou") { translated_yaku_list.push("자일색".to_string()); }
    if yaku_lower.contains("ryuuiisou") { translated_yaku_list.push("녹일색".to_string()); }
    if yaku_lower.contains("chuuren") { translated_yaku_list.push("구련보등".to_string()); }
    if yaku_lower.contains("chinroutou") { translated_yaku_list.push("청노두".to_string()); }
    if yaku_lower.contains("daisuushi") { translated_yaku_list.push("대사희".to_string()); }
    if yaku_lower.contains("shousuushi") { translated_yaku_list.push("소사희".to_string()); }
    if yaku_lower.contains("sankantsu") { translated_yaku_list.push("산깡쯔".to_string()); }
    if yaku_lower.contains("suukantsu") { translated_yaku_list.push("쓰깡쯔".to_string()); }
    if yaku_lower.contains("tanyao") { translated_yaku_list.push("탕야오".to_string()); }
    if yaku_lower.contains("pinfu") { translated_yaku_list.push("핑후".to_string()); }
    if yaku_lower.contains("iipeikou") { translated_yaku_list.push("이페코".to_string()); }
    if yaku_lower.contains("chanta") { translated_yaku_list.push("찬타".to_string()); }
    if yaku_lower.contains("ittsu") { translated_yaku_list.push("일기통관".to_string()); }
    if yaku_lower.contains("sanshoku") { translated_yaku_list.push("삼색동순".to_string()); }
    if yaku_lower.contains("sanankou") { translated_yaku_list.push("산안커".to_string()); }
    if yaku_lower.contains("toitoi") { translated_yaku_list.push("또이또이".to_string()); }
    if yaku_lower.contains("chiitoitsu") { translated_yaku_list.push("치또이쯔".to_string()); }
    if yaku_lower.contains("shousangen") { translated_yaku_list.push("소삼원".to_string()); }
    if yaku_lower.contains("honroutou") { translated_yaku_list.push("혼노두".to_string()); }
    if yaku_lower.contains("junchan") { translated_yaku_list.push("준찬타".to_string()); }
    if yaku_lower.contains("ryanpeikou") { translated_yaku_list.push("량페코".to_string()); }
    if yaku_lower.contains("honitsu") { translated_yaku_list.push("혼일색".to_string()); }
    if yaku_lower.contains("chinitsu") { translated_yaku_list.push("청일색".to_string()); }

    let mut dora_texts = Vec::new();
    if ui_regular_dora > 0 { dora_texts.push(format!("도라 {}", ui_regular_dora)); }
    if ui_aka_dora > 0 { dora_texts.push(format!("적도라 {}", ui_aka_dora)); }
    if ui_ura_dora > 0 { dora_texts.push(format!("뒷도라 {}", ui_ura_dora)); }

    if !dora_texts.is_empty() {
        translated_yaku_list.push(dora_texts.join(", "));
    }
    result_text.push_str(&format!("[{}]", translated_yaku_list.join(", ")));

    result_text.push_str("\n---\n");
    result_text.push_str(&format!("도라표시패:{}\n", display_dora_str));
    result_text.push_str(&format!("손패:{}", final_hand_str));

    result_text
}

pub(crate) fn calculate_shanten_wait(final_hand_str: &str) -> String {
    let parsed = match parse_hand_with_aka(final_hand_str) {
        Ok(p) => p,
        Err(_) => return format!("문자열 파싱 오류\n올바른 마작 표기법인지 확인해주세요.\n---\n손패:{}", final_hand_str),
    };

    let counts = to_counts(&parsed.tiles);
    
    let shanten_result = calculate_shanten(&counts);
    let shanten_num = shanten_result.shanten as i32;
    
    let mut result_text = String::new();
    
    if shanten_num == 0 {
        let mut wait_tiles = Vec::new();
        let all_tiles = [
            "1m", "2m", "3m", "4m", "5m", "6m", "7m", "8m", "9m",
            "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p",
            "1s", "2s", "3s", "4s", "5s", "6s", "7s", "8s", "9s",
            "1z", "2z", "3z", "4z", "5z", "6z", "7z"
        ];
        
        for &t_name in all_tiles.iter() {
            let test_hand_str = format!("{}{}", final_hand_str, t_name);
            
            if let Ok(test_parsed) = parse_hand_with_aka(&test_hand_str) {
                let mut is_valid_count = true;
                for tile in &test_parsed.tiles {
                    let count = test_parsed.tiles.iter().filter(|&t| t == tile).count();
                    if count > 4 {
                        is_valid_count = false;
                        break;
                    }
                }
                
                if is_valid_count {
                    let test_counts = to_counts(&test_parsed.tiles);
                    let test_melds: Vec<_> = test_parsed.called_melds.iter().map(|m| m.meld.clone()).collect();
                    let structures = decompose_hand_with_melds(&test_counts, &test_melds);
                    
                    if !structures.is_empty() {
                        wait_tiles.push(t_name.to_string());
                    }
                }
            }
        }

        result_text.push_str("✨ 텐파이!\n");
        if wait_tiles.is_empty() {
            result_text.push_str("대기패: 없음 (형식텐파이)\n");
        } else {
            result_text.push_str(&format!("대기패: {}\n", wait_tiles.join(", ")));
        }
    } else {
        result_text.push_str("텐파이가 아닙니다.\n");
    }

    result_text.push_str("\n---\n");
    result_text.push_str(&format!("손패: {}", final_hand_str));

    result_text
}