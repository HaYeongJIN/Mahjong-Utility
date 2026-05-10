use agari::hand::decompose_hand_with_melds;
use agari::parse::{parse_hand_with_aka, to_counts};

#[derive(Clone)]
pub(crate) struct TileBox {
    pub(crate) name: String,
    pub(crate) is_sideways: bool,
    pub(crate) is_ankan: bool,
}

pub(crate) fn to_agari_str(tiles: &[TileBox]) -> String {
    let mut res = String::new();
    let mut curr_suit = String::new();
    let mut temp_nums = String::new();

    for t in tiles {
        let num = &t.name[0..1];
        let suit = &t.name[1..2];
        if curr_suit.is_empty() {
            curr_suit = suit.to_string();
            temp_nums.push_str(num);
        } else if curr_suit == suit {
            temp_nums.push_str(num);
        } else {
            res.push_str(&temp_nums);
            res.push_str(&curr_suit);
            curr_suit = suit.to_string();
            temp_nums = num.to_string();
        }
    }
    if !curr_suit.is_empty() {
        res.push_str(&temp_nums);
        res.push_str(&curr_suit);
    }
    res
}

pub(crate) fn get_next_tile(indicator: &str) -> String {
    let s = indicator.replace("0", "5");
    let mut chars = s.chars();
    let val = chars.next();
    let suit = chars.next();
    if let (Some(v), Some(suit)) = (val, suit) {
        if suit == 'z' {
            let num = v.to_digit(10).unwrap_or(1);
            let next = match num {
                1 => 2, 2 => 3, 3 => 4, 4 => 1, 
                5 => 6, 6 => 7, 7 => 5,         
                _ => num,
            };
            return format!("{}{}", next, suit);
        } else {
            let num = v.to_digit(10).unwrap_or(5);
            let next = if num == 9 { 1 } else { num + 1 };
            return format!("{}{}", next, suit);
        }
    }
    s
}

pub(crate) fn check_structure_validity(hand_str: &str) -> bool {
    if let Ok(parsed) = parse_hand_with_aka(hand_str) {
        let counts = to_counts(&parsed.tiles);
        let converted_melds: Vec<_> = parsed.called_melds.iter().map(|m| m.meld.clone()).collect();
        let structures = decompose_hand_with_melds(&counts, &converted_melds);
        !structures.is_empty()
    } else {
        false
    }
}

pub(crate) fn parse_doras(dora_indicators: Vec<i32>, override_dora: String, is_riichi: bool) -> (String, Vec<String>, Vec<String>) {
    let tile_names = [
        "1m", "1p", "1s", "1z", "2m", "2p", "2s", "2z", "3m", "3p", "3s", "3z", 
        "4m", "4p", "4s", "4z", "5m", "5p", "5s", "5z", "6m", "6p", "6s", "6z", 
        "7m", "7p", "7s", "7z", "8m", "8p", "8s", "9m", "9p", "9s", "5mr", "5pr", "5sr", "0b"
    ];

    let mut actual_doras = Vec::new();
    let mut actual_uradoras = Vec::new();
    let mut display_dora_str = String::new();

    if override_dora.is_empty() {
        for &d_enc in &dora_indicators {
            let is_uradora = d_enc >= 100;
            let d = d_enc % 100;
            if d >= 0 && d < 38 {
                let original_name = tile_names[d as usize];
                if original_name != "0b" {
                    let mut safe_original = original_name.to_string();
                    if safe_original == "5mr" || safe_original == "0m" { safe_original = "5m".to_string(); }
                    if safe_original == "5pr" || safe_original == "0p" { safe_original = "5p".to_string(); }
                    if safe_original == "5sr" || safe_original == "0s" { safe_original = "5s".to_string(); }

                    if !is_uradora { 
                        display_dora_str.push_str(&safe_original); 
                    }

                    let actual_dora_name = get_next_tile(original_name);
                    let mut safe_actual = actual_dora_name.clone();
                    if safe_actual == "5mr" || safe_actual == "0m" { safe_actual = "5m".to_string(); }
                    if safe_actual == "5pr" || safe_actual == "0p" { safe_actual = "5p".to_string(); }
                    if safe_actual == "5sr" || safe_actual == "0s" { safe_actual = "5s".to_string(); }

                    if is_uradora { 
                        if is_riichi { actual_uradoras.push(safe_actual); }
                    } else { 
                        actual_doras.push(safe_actual); 
                    }
                }
            }
        }
        if display_dora_str.is_empty() { display_dora_str = "-".to_string(); }
    } else {
        display_dora_str = override_dora.clone();
        let mut current_nums = Vec::new();
        for c in override_dora.chars() {
            if c.is_ascii_digit() {
                current_nums.push(c);
            } else if c == 'm' || c == 'p' || c == 's' || c == 'z' {
                for num in current_nums.drain(..) {
                    let tile_str = format!("{}{}", num, c);
                    let actual = get_next_tile(&tile_str);
                    actual_doras.push(actual.replace("0", "5"));
                }
            }
        }
    }

    (display_dora_str, actual_doras, actual_uradoras)
}

pub(crate) fn build_final_hand_string(tiles: Vec<i32>, force_closed: bool, _total_tiles_count: usize) -> String {
    let tile_names = [
        "1m", "1p", "1s", "1z", "2m", "2p", "2s", "2z", "3m", "3p", "3s", "3z", 
        "4m", "4p", "4s", "4z", "5m", "5p", "5s", "5z", "6m", "6p", "6s", "6z", 
        "7m", "7p", "7s", "7z", "8m", "8p", "8s", "9m", "9p", "9s", "5mr", "5pr", "5sr", "0b"
    ];

    let mut forced_t_boxes: Vec<TileBox> = Vec::new();
    let mut tile_counts = std::collections::HashMap::new();

    for &t_enc in &tiles {
        let is_ankan = t_enc >= 200; 
        let is_sideways = t_enc >= 100 && t_enc < 200; 
        let t = t_enc % 100;
        
        if t >= 0 && t < 38 {
            let mut name = tile_names[t as usize].to_string();
            if name == "5mr" { name = "0m".to_string(); }
            else if name == "5pr" { name = "0p".to_string(); }
            else if name == "5sr" { name = "0s".to_string(); }

            if name != "0b" {
                let base_name = name.replace("0", "5");
                let c = tile_counts.entry(base_name).or_insert(0);
                *c += 1;
                if *c > 4 { continue; } 
            }

            let corrected_sideways = if force_closed { false } else { is_sideways };
            forced_t_boxes.push(TileBox { name, is_sideways: corrected_sideways, is_ankan });
        }
    }

    let mut t_boxes = forced_t_boxes;

    if !t_boxes.is_empty() {
        let last_base_name = t_boxes.last().unwrap().name.replace("0", "5");
        let mut block_start = t_boxes.len() - 1;
        while block_start > 0 && t_boxes[block_start - 1].name.replace("0", "5") == last_base_name {
            block_start -= 1;
        }
        
        let block_len = t_boxes.len() - block_start;
        if block_len < 3 {
            let mut has_other_sideways = false;
            for j in 0..block_start {
                if t_boxes[j].is_sideways {
                    has_other_sideways = true;
                    break;
                }
            }
            if !has_other_sideways {
                for j in block_start..t_boxes.len() {
                    t_boxes[j].is_sideways = false;
                }
            }
        }
    }

    let mut i = 0;
    while i < t_boxes.len() {
        let is_wild = |s: &str| s == "5b" || s == "5z" || s == "0b";
        let is_explicit_back = |tb: &TileBox| tb.name == "0b" || tb.name == "5b";

        if i + 3 < t_boxes.len() {
            let b0 = &t_boxes[i];
            let b1 = &t_boxes[i+1];
            let b2 = &t_boxes[i+2];
            let b3 = &t_boxes[i+3];
            
            let is_0xx0 = is_wild(&b0.name.replace("0", "5")) && is_wild(&b3.name.replace("0", "5")) && b1.name == b2.name;
            let is_x00x = is_wild(&b1.name.replace("0", "5")) && is_wild(&b2.name.replace("0", "5")) && b0.name == b3.name;
            
            if (is_0xx0 && (is_explicit_back(b0) || is_explicit_back(b3))) || 
                (is_x00x && (is_explicit_back(b1) || is_explicit_back(b2))) {
                let target_name = if is_wild(&b1.name.replace("0", "5")) { "5z".to_string() } else { t_boxes[i+1].name.clone() };
                for j in 0..4 {
                    t_boxes[i+j].name = target_name.clone();
                    t_boxes[i+j].is_ankan = true;
                    t_boxes[i+j].is_sideways = false;
                }
                i += 4;
                continue;
            }
        }

        if i + 2 < t_boxes.len() {
            let b0 = &t_boxes[i];
            let b1 = &t_boxes[i+1];
            let b2 = &t_boxes[i+2];
            
            if is_wild(&b0.name.replace("0", "5")) && b1.name == b2.name && is_explicit_back(b0) {
                let target_name = if is_wild(&b1.name.replace("0", "5")) { "5z".to_string() } else { t_boxes[i+1].name.clone() };
                t_boxes[i].name = target_name.clone();
                t_boxes[i].is_ankan = true; t_boxes[i].is_sideways = false;
                t_boxes[i+1].is_ankan = true; t_boxes[i+1].is_sideways = false;
                t_boxes[i+2].is_ankan = true; t_boxes[i+2].is_sideways = false;
                t_boxes.insert(i+3, TileBox { name: target_name, is_sideways: false, is_ankan: true });
                i += 4;
                continue;
            }
            if is_wild(&b2.name.replace("0", "5")) && b0.name == b1.name && is_explicit_back(b2) {
                let target_name = if is_wild(&b0.name.replace("0", "5")) { "5z".to_string() } else { t_boxes[i].name.clone() };
                t_boxes[i].is_ankan = true; t_boxes[i].is_sideways = false;
                t_boxes[i+1].is_ankan = true; t_boxes[i+1].is_sideways = false;
                t_boxes[i+2].name = target_name.clone();
                t_boxes[i+2].is_ankan = true; t_boxes[i+2].is_sideways = false;
                t_boxes.insert(i+3, TileBox { name: target_name, is_sideways: false, is_ankan: true });
                i += 4;
                continue;
            }
        }
        i += 1;
    }

    t_boxes.retain(|t| t.name != "0b" && t.name.replace("0", "5") != "5b");

    let mut result = String::new();
    let mut chunk: Vec<TileBox> = Vec::new();
    let mut idx = 0;

    let num_val = |name: &str| -> i32 {
        if name.starts_with('0') { 5 } else { name[0..1].parse().unwrap_or(0) }
    };

    while idx < t_boxes.len() {
        if idx + 3 < t_boxes.len() {
            let b1 = t_boxes[idx].name.replace("0", "5");
            let b2 = t_boxes[idx+1].name.replace("0", "5");
            let b3 = t_boxes[idx+2].name.replace("0", "5");
            let b4 = t_boxes[idx+3].name.replace("0", "5");

            if b1 == b2 && b2 == b3 && b3 == b4 && b1 != "5b" {
                let has_ankan_flag = t_boxes[idx..idx+4].iter().any(|t| t.is_ankan);
                let has_sideways = t_boxes[idx..idx+4].iter().any(|t| t.is_sideways);
                
                if has_ankan_flag {
                    if !chunk.is_empty() { result.push_str(&to_agari_str(&chunk)); chunk.clear(); }
                    let num = &b1[0..1]; let suit = &b1[1..2];
                    let formatted = format!("[{}{}{}{}z]", num, num, num, num);
                    result.push_str(&formatted.replace("z", suit));
                    idx += 4; continue;
                } else if has_sideways { 
                    if !chunk.is_empty() { result.push_str(&to_agari_str(&chunk)); chunk.clear(); }
                    let num = &b1[0..1]; let suit = &b1[1..2];
                    let formatted = format!("({}{}{}{}z)", num, num, num, num);
                    result.push_str(&formatted.replace("z", suit));
                    idx += 4; continue;
                }
            }
        }

        if idx + 2 < t_boxes.len() {
            let has_sideways = t_boxes[idx..idx+3].iter().any(|t| t.is_sideways);
            if has_sideways {
                let suit = &t_boxes[idx].name[1..2];
                if t_boxes[idx+1].name[1..2] == *suit && t_boxes[idx+2].name[1..2] == *suit {
                    let n1 = num_val(&t_boxes[idx].name);
                    let n2 = num_val(&t_boxes[idx+1].name);
                    let n3 = num_val(&t_boxes[idx+2].name);
                    let is_pon = n1 == n2 && n2 == n3;
                    let mut sorted = [n1, n2, n3];
                    sorted.sort();
                    let is_chii = sorted[0] > 0 && sorted[0] + 1 == sorted[1] && sorted[1] + 1 == sorted[2];
                    if is_pon || is_chii {
                        if !chunk.is_empty() {
                            result.push_str(&to_agari_str(&chunk));
                            chunk.clear();
                        }
                        let furo_str = to_agari_str(&t_boxes[idx..idx+3]);
                        result.push_str(&format!("({})", furo_str));
                        idx += 3;
                        continue;
                    }
                }
            }
        }

        chunk.push(t_boxes[idx].clone());
        idx += 1;
    }

    if !chunk.is_empty() {
        result.push_str(&to_agari_str(&chunk));
    }

    let mut raw_str = result;
    let suits = ["m", "p", "s", "z"];
    let nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
    for s in suits.iter() {
        for n in nums.iter() {
            let target = format!("{}{}{}", s, n, s);
            let replacement = format!("{}{}", n, s);
            raw_str = raw_str.replace(&target, &replacement);
        }
    }

    let mut final_hand_str = raw_str;

    if !check_structure_validity(&final_hand_str) {
        let mut upgraded = false;
        
        for suit in suits.iter() {
            let max_num = if *suit == "z" { 7 } else { 9 };
            for num in 1..=max_num {
                let double_str = format!("{0}{0}{1}", num, suit); 
                let triple_str = format!("{0}{0}{0}{1}", num, suit); 
                let quad_str = format!("{0}{0}{0}{0}{1}", num, suit); 
                let ankan_str = format!("[{0}{0}{0}{0}{1}]", num, suit); 
                
                if final_hand_str.contains(&quad_str) && !final_hand_str.contains(&format!("({})", quad_str)) {
                    let test_str = final_hand_str.replace(&quad_str, &ankan_str);
                    if check_structure_validity(&test_str) {
                        final_hand_str = test_str;
                        upgraded = true;
                        break;
                    }
                } else if final_hand_str.contains(&triple_str) && !final_hand_str.contains(&format!("({})", triple_str)) {
                    let test_str = final_hand_str.replace(&triple_str, &ankan_str);
                    if check_structure_validity(&test_str) {
                        final_hand_str = test_str;
                        upgraded = true;
                        break;
                    }
                } else if final_hand_str.contains(&double_str) && !final_hand_str.contains(&format!("({})", double_str)) {
                    let test_str = final_hand_str.replace(&double_str, &ankan_str);
                    if check_structure_validity(&test_str) {
                        final_hand_str = test_str;
                        upgraded = true;
                        break;
                    }
                }
            }
            if upgraded { break; }
        }

        if !upgraded {
            let count_5z = final_hand_str.matches("5z").count();
            let count_55z = final_hand_str.matches("55z").count();
            let count_ankan = final_hand_str.matches("5555z").count();
            
            if count_5z == 1 && count_55z == 0 && count_ankan == 0 {
                let mut test_str = final_hand_str.replace("5z", "");
                test_str = test_str.replace(" ", ""); 
                if check_structure_validity(&test_str) {
                    final_hand_str = test_str;
                }
            }
        }
    }

    final_hand_str
}