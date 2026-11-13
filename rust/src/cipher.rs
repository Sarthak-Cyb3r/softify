// High-performance cryptographic and string normalization engine for Softify
// Implements zero-dependency DES-ECB decryption for JioSaavn studio audio streams
// and SIMD-speed Unicode/phonetic text normalizers.

use std::char;

const DES_KEY: &[u8; 8] = b"38346591";

// DES Initial Permutation (IP) table (1-indexed in spec, converted to 0-indexed)
const IP: [u8; 64] = [
    57, 49, 41, 33, 25, 17,  9,  1,
    59, 51, 43, 35, 27, 19, 11,  3,
    61, 53, 45, 37, 29, 21, 13,  5,
    63, 55, 47, 39, 31, 23, 15,  7,
    56, 48, 40, 32, 24, 16,  8,  0,
    58, 50, 42, 34, 26, 18, 10,  2,
    60, 52, 44, 36, 28, 20, 12,  4,
    62, 54, 46, 38, 30, 22, 14,  6,
];

// DES Final Permutation (FP / IP^-1) table
const FP: [u8; 64] = [
    39,  7, 47, 15, 55, 23, 63, 31,
    38,  6, 46, 14, 54, 22, 62, 30,
    37,  5, 45, 13, 53, 21, 61, 29,
    36,  4, 44, 12, 52, 20, 60, 28,
    35,  3, 43, 11, 51, 19, 59, 27,
    34,  2, 42, 10, 50, 18, 58, 26,
    33,  1, 41,  9, 49, 17, 57, 25,
    32,  0, 40,  8, 48, 16, 56, 24,
];

// Permuted Choice 1 (PC-1)
const PC1_C: [u8; 28] = [
    56, 48, 40, 32, 24, 16,  8,
     0, 57, 49, 41, 33, 25, 17,
     9,  1, 58, 50, 42, 34, 26,
    18, 10,  2, 59, 51, 43, 35,
];

const PC1_D: [u8; 28] = [
    62, 54, 46, 38, 30, 22, 14,
     6, 61, 53, 45, 37, 29, 21,
    13,  5, 60, 52, 44, 36, 28,
    20, 12,  4, 27, 19, 11,  3,
];

// Shift schedule for key schedule
const SHIFTS: [u32; 16] = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

// Permuted Choice 2 (PC-2)
const PC2: [u8; 48] = [
    13, 16, 10, 23,  0,  4,
     2, 27, 14,  5, 20,  9,
    22, 18, 11,  3, 25,  7,
    15,  6, 26, 19, 12,  1,
    40, 51, 30, 36, 46, 54,
    29, 39, 50, 44, 32, 47,
    43, 48, 38, 55, 33, 52,
    45, 41, 49, 35, 28, 31,
];

// Expansion table (E)
const E: [u8; 48] = [
    31,  0,  1,  2,  3,  4,
     3,  4,  5,  6,  7,  8,
     7,  8,  9, 10, 11, 12,
    11, 12, 13, 14, 15, 16,
    15, 16, 17, 18, 19, 20,
    19, 20, 21, 22, 23, 24,
    23, 24, 25, 26, 27, 28,
    27, 28, 29, 30, 31,  0,
];

// S-boxes (S1 to S8)
const S_BOXES: [[[u8; 16]; 4]; 8] = [
    // S1
    [
        [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7],
        [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
        [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0],
        [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13],
    ],
    // S2
    [
        [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10],
        [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
        [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15],
        [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9],
    ],
    // S3
    [
        [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8],
        [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
        [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7],
        [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12],
    ],
    // S4
    [
        [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
        [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
        [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
        [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
    ],
    // S5
    [
        [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9],
        [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
        [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14],
        [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3],
    ],
    // S6
    [
        [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11],
        [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
        [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6],
        [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13],
    ],
    // S7
    [
        [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1],
        [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
        [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2],
        [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12],
    ],
    // S8
    [
        [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7],
        [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
        [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8],
        [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11],
    ],
];

// Permutation table (P)
const P: [u8; 32] = [
    15,  6, 19, 20, 28, 11, 27, 16,
     0, 14, 22, 25,  4, 17, 30,  9,
     1,  7, 23, 13, 31, 26,  2,  8,
    18, 12, 29,  5, 21, 10,  3, 24,
];

// Generate 16 subkeys for DES from an 8-byte key
fn des_key_schedule(key: &[u8; 8]) -> [u64; 16] {
    let mut key_bits = 0u64;
    for &b in key.iter() {
        key_bits = (key_bits << 8) | (b as u64);
    }

    let mut c = 0u32;
    for (i, &bit_pos) in PC1_C.iter().enumerate() {
        let bit = (key_bits >> (63 - bit_pos)) & 1;
        c |= (bit as u32) << (27 - i);
    }

    let mut d = 0u32;
    for (i, &bit_pos) in PC1_D.iter().enumerate() {
        let bit = (key_bits >> (63 - bit_pos)) & 1;
        d |= (bit as u32) << (27 - i);
    }

    let mut subkeys = [0u64; 16];
    for round in 0..16 {
        let shift = SHIFTS[round];
        c = ((c << shift) | (c >> (28 - shift))) & 0x0FFF_FFFF;
        d = ((d << shift) | (d >> (28 - shift))) & 0x0FFF_FFFF;

        let cd = ((c as u64) << 28) | (d as u64);
        let mut subkey = 0u64;
        for (i, &bit_pos) in PC2.iter().enumerate() {
            let bit = (cd >> (55 - bit_pos)) & 1;
            subkey |= bit << (47 - i);
        }
        subkeys[round] = subkey;
    }
    subkeys
}

// Feistel function f(R, K)
fn feistel(r: u32, subkey: u64) -> u32 {
    let mut er = 0u64;
    for (i, &bit_pos) in E.iter().enumerate() {
        let bit = ((r >> (31 - bit_pos)) & 1) as u64;
        er |= bit << (47 - i);
    }

    let x = er ^ subkey;
    let mut s_out = 0u32;

    for s in 0..8 {
        let chunk = ((x >> (42 - s * 6)) & 0x3F) as u8;
        let row = (((chunk >> 5) & 1) << 1) | (chunk & 1);
        let col = (chunk >> 1) & 0x0F;
        let val = S_BOXES[s][row as usize][col as usize];
        s_out = (s_out << 4) | (val as u32);
    }

    let mut p_out = 0u32;
    for (i, &bit_pos) in P.iter().enumerate() {
        let bit = (s_out >> (31 - bit_pos)) & 1;
        p_out |= bit << (31 - i);
    }
    p_out
}

// Decrypt a single 64-bit block using DES
fn des_decrypt_block(block: u64, subkeys: &[u64; 16]) -> u64 {
    let mut ip_block = 0u64;
    for (i, &bit_pos) in IP.iter().enumerate() {
        let bit = (block >> (63 - bit_pos)) & 1;
        ip_block |= bit << (63 - i);
    }

    let mut l = (ip_block >> 32) as u32;
    let mut r = ip_block as u32;

    // Decryption applies subkeys in reverse order: 15 down to 0
    for round in (0..16).rev() {
        let temp = r;
        r = l ^ feistel(r, subkeys[round]);
        l = temp;
    }

    let pre_output = ((r as u64) << 32) | (l as u64);
    let mut fp_block = 0u64;
    for (i, &bit_pos) in FP.iter().enumerate() {
        let bit = (pre_output >> (63 - bit_pos)) & 1;
        fp_block |= bit << (63 - i);
    }
    fp_block
}

// Decode standard base64 string
fn base64_decode(input: &str) -> Result<Vec<u8>, String> {
    let mut output = Vec::new();
    let mut buf = 0u32;
    let mut bits = 0;

    for &b in input.as_bytes() {
        let val = match b {
            b'A'..=b'Z' => (b - b'A') as u32,
            b'a'..=b'z' => (b - b'a' + 26) as u32,
            b'0'..=b'9' => (b - b'0' + 52) as u32,
            b'+' => 62,
            b'/' => 63,
            b'=' | b' ' | b'\r' | b'\n' | b'\t' => continue,
            _ => return Err(format!("Invalid base64 byte: {}", b as char)),
        };
        buf = (buf << 6) | val;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            output.push(((buf >> bits) & 0xFF) as u8);
        }
    }
    Ok(output)
}

/// Decrypts JioSaavn encrypted_media_url to full 320 Kbps stream URL.
pub fn decrypt_saavn_media_url(encrypted_b64: &str, target_bitrate: u32) -> Result<String, String> {
    let raw_ciphertext = base64_decode(encrypted_b64)?;
    if raw_ciphertext.is_empty() || raw_ciphertext.len() % 8 != 0 {
        return Err("Ciphertext must be a non-empty multiple of 8 bytes".into());
    }

    let subkeys = des_key_schedule(DES_KEY);
    let mut decrypted_bytes = Vec::with_capacity(raw_ciphertext.len());

    for chunk in raw_ciphertext.chunks_exact(8) {
        let mut block = 0u64;
        for &b in chunk {
            block = (block << 8) | (b as u64);
        }
        let decrypted_block = des_decrypt_block(block, &subkeys);
        for i in (0..8).rev() {
            decrypted_bytes.push(((decrypted_block >> (i * 8)) & 0xFF) as u8);
        }
    }

    // Convert to UTF-8
    let raw_text = String::from_utf8_lossy(&decrypted_bytes);

    // Find .mp4 terminus
    let mp4_idx = raw_text.find(".mp4");
    let mut clean_url = if let Some(idx) = mp4_idx {
        raw_text[..idx + 4].to_string()
    } else {
        raw_text.chars().filter(|c| c.is_ascii_graphic() || *c == ' ').collect::<String>().trim().to_string()
    };

    // Ensure HTTPS
    if clean_url.starts_with("http://") {
        clean_url = clean_url.replacen("http://", "https://", 1);
    }

    // Rewrite bitrate to target preset (default 320kbps studio master)
    let replacement = match target_bitrate {
        96 | 96000 => "_96.mp4",
        160 | 160000 => "_160.mp4",
        _ => "_320.mp4",
    };

    let final_url = clean_url
        .replace("_48.mp4", replacement)
        .replace("_96.mp4", replacement)
        .replace("_160.mp4", replacement);

    Ok(final_url)
}

/// High-speed Unicode-aware text normalizer for search matching and catalog deduplication.
pub fn normalize_text(input: &str) -> String {
    let mut normalized = String::with_capacity(input.len());
    let mut in_parenthesis = false;
    let mut in_bracket = false;

    // First pass: character translation and parenthetical stripping
    for c in input.chars() {
        match c {
            '(' => in_parenthesis = true,
            ')' => in_parenthesis = false,
            '[' => in_bracket = true,
            ']' => in_bracket = false,
            // Non-breaking space & unicode spaces
            '\u{00A0}' | '\u{2000}'..='\u{200B}' | '\u{202F}' | '\u{205F}' | '\u{3000}' => {
                if !in_parenthesis && !in_bracket {
                    normalized.push(' ');
                }
            }
            _ => {
                if !in_parenthesis && !in_bracket {
                    for lower_c in c.to_lowercase() {
                        if lower_c.is_alphanumeric() {
                            normalized.push(lower_c);
                        } else {
                            normalized.push(' ');
                        }
                    }
                }
            }
        }
    }

    // Second pass: collapse multiple consecutive spaces and trim
    let mut result = String::with_capacity(normalized.len());
    let mut last_was_space = true; // Prevents leading spaces

    for c in normalized.chars() {
        if c == ' ' {
            if !last_was_space {
                result.push(' ');
                last_was_space = true;
            }
        } else {
            result.push(c);
            last_was_space = false;
        }
    }

    if result.ends_with(' ') {
        result.pop();
    }
    result
}

/// Phonetic text simplification: removes duplicate consecutive vowels and normalizes.
pub fn phonetic_simplify(input: &str) -> String {
    let norm = normalize_text(input);
    let mut result = String::with_capacity(norm.len());
    let mut prev_vowel = '\0';

    for c in norm.chars() {
        let is_vowel = matches!(c, 'a' | 'e' | 'i' | 'o' | 'u');
        if is_vowel {
            if c != prev_vowel {
                result.push(c);
                prev_vowel = c;
            }
        } else {
            result.push(c);
            prev_vowel = '\0';
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_des_decryption_pink_lips() {
        let enc = "ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyXzJwTjal8de8C2iB5NXSj2yh7oExNJl1tnioSjfQVP9/D0t9P9XV6xw7tS9a8Gtq";
        let url = decrypt_saavn_media_url(enc, 320000).expect("Decryption should succeed");
        assert!(url.starts_with("https://aac.saavncdn.com/"));
        assert!(url.ends_with("_320.mp4"));
        assert!(url.contains("c861b800306583f2658134d8c97c729e"));
    }

    #[test]
    fn test_normalize_unicode_spaces_and_parentheticals() {
        let raw = "The\u{00A0}Weeknd (feat. Daft Punk) - Starboy [Official]";
        let norm = normalize_text(raw);
        assert_eq!(norm, "the weeknd starboy");
    }

    #[test]
    fn test_phonetic_simplify_vowels() {
        let raw = "Kaaabiraaa Maan Jaaa";
        let simplified = phonetic_simplify(raw);
        assert_eq!(simplified, "kabira man ja");
    }
}
