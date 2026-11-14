/// Normalizes text for search indexing and matching:
/// 1. Lowercases
/// 2. Maps Latin/accented diacritics to ASCII equivalents
/// 3. Replaces non-alphanumeric punctuation with spaces (preserving unicode letters/numbers)
/// 4. Trims and collapses multiple spaces
pub fn normalize_search_text(text: &str) -> String {
    if text.is_empty() {
        return String::new();
    }

    let mut buffer = String::with_capacity(text.len());
    for c in text.to_lowercase().chars() {
        match c {
            'à' | 'á' | 'â' | 'ã' | 'ä' | 'å' | 'ā' | 'ă' | 'ą' => buffer.push('a'),
            'æ' => buffer.push_str("ae"),
            'ç' | 'ć' | 'č' | 'ĉ' | 'ċ' => buffer.push('c'),
            'ď' | 'đ' => buffer.push('d'),
            'è' | 'é' | 'ê' | 'ë' | 'ē' | 'ĕ' | 'ė' | 'ę' | 'ě' => buffer.push('e'),
            'ì' | 'í' | 'î' | 'ï' | 'ī' | 'ĭ' | 'į' => buffer.push('i'),
            'ñ' | 'ń' | 'ň' | 'ņ' => buffer.push('n'),
            'ò' | 'ó' | 'ô' | 'õ' | 'ö' | 'ø' | 'ō' | 'ŏ' | 'ő' => buffer.push('o'),
            'œ' => buffer.push_str("oe"),
            'ř' | 'ŕ' | 'ŗ' => buffer.push('r'),
            'š' | 'ś' | 'ŝ' | 'ş' | 'ș' => buffer.push('s'),
            'ß' => buffer.push_str("ss"),
            'ť' | 'ţ' | 'ț' => buffer.push('t'),
            'ù' | 'ú' | 'û' | 'ü' | 'ū' | 'ŭ' | 'ů' | 'ű' | 'ų' => buffer.push('u'),
            'ý' | 'ÿ' | 'ŷ' => buffer.push('y'),
            'ž' | 'ź' | 'ż' => buffer.push('z'),
            other => buffer.push(other),
        }
    }

    // Replace punctuation/symbols with space while preserving letters, numbers, and marks
    let mut cleaned = String::with_capacity(buffer.len());
    for c in buffer.chars() {
        if c.is_alphanumeric() {
            cleaned.push(c);
        } else {
            cleaned.push(' ');
        }
    }

    // Collapse multiple whitespace
    cleaned.split_whitespace().collect::<Vec<&str>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalizer() {
        assert_eq!(normalize_search_text("Café del Mar"), "cafe del mar");
        assert_eq!(normalize_search_text("Beyoncé - Halo!"), "beyonce halo");
        assert_eq!(normalize_search_text("Kesariya (Brahmāstra)"), "kesariya brahmastra");
    }
}
