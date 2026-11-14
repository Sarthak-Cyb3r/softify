use crate::models::SoftifyError;
use std::fs;
use std::path::Path;

pub struct M4aMetadata<'a> {
    pub title: &'a str,
    pub artist: &'a str,
    pub album: Option<&'a str>,
    pub cover_art_bytes: Option<&'a [u8]>,
}

pub struct M4aAtomTagger;

impl M4aAtomTagger {
    pub fn is_valid_iso_mp4(bytes: &[u8]) -> bool {
        if bytes.len() < 8 {
            return false;
        }
        &bytes[4..8] == b"ftyp"
    }

    pub fn write_metadata(file_path: &Path, metadata: &M4aMetadata) -> Result<(), SoftifyError> {
        let bytes = fs::read(file_path).map_err(|e| SoftifyError::Download { reason: format!("Read failed: {e}") })?;
        if !Self::is_valid_iso_mp4(&bytes) {
            return Err(SoftifyError::Download { reason: "File is not a valid ISO MP4 / M4A".to_string() });
        }

        let mut ilst_payload = Vec::new();
        ilst_payload.extend_from_slice(&Self::build_text_atom("©nam", metadata.title));
        ilst_payload.extend_from_slice(&Self::build_text_atom("©ART", metadata.artist));
        if let Some(alb) = metadata.album {
            if !alb.is_empty() {
                ilst_payload.extend_from_slice(&Self::build_text_atom("©alb", alb));
            }
        }
        if let Some(covr) = metadata.cover_art_bytes {
            if !covr.is_empty() {
                ilst_payload.extend_from_slice(&Self::build_cover_atom(covr));
            }
        }

        let ilst_atom = Self::build_box(b"ilst", &ilst_payload);

        // Build meta box (4 bytes version/flags: 0x00000000 + children)
        let mut meta_payload = vec![0u8; 4];
        meta_payload.extend_from_slice(&ilst_atom);
        let meta_atom = Self::build_box(b"meta", &meta_payload);

        // Build udta box containing meta
        let udta_atom = Self::build_box(b"udta", &meta_atom);

        // Inject udta into moov and realign stco/co64 chunk offsets
        let updated_bytes = Self::inject_udta_into_moov(&bytes, &udta_atom)?;

        // Atomic write via temp file
        let temp_path = file_path.with_extension("m4a.tmp");
        fs::write(&temp_path, &updated_bytes).map_err(|e| SoftifyError::Download { reason: format!("Temp write failed: {e}") })?;
        fs::rename(&temp_path, file_path).map_err(|e| SoftifyError::Download { reason: format!("Rename failed: {e}") })?;

        Ok(())
    }

    fn build_text_atom(name: &str, text: &str) -> Vec<u8> {
        let text_bytes = text.as_bytes();
        let mut data_payload = Vec::with_capacity(8 + text_bytes.len());
        // Type 1: UTF-8 text without BOM
        data_payload.extend_from_slice(&1u32.to_be_bytes());
        // Locale 0
        data_payload.extend_from_slice(&0u32.to_be_bytes());
        data_payload.extend_from_slice(text_bytes);

        let data_box = Self::build_box(b"data", &data_payload);
        Self::build_box(name.as_bytes(), &data_box)
    }

    fn build_cover_atom(image_bytes: &[u8]) -> Vec<u8> {
        let type_code: u32 = if image_bytes.len() >= 8 && image_bytes.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
            14 // PNG
        } else {
            13 // JPEG
        };

        let mut data_payload = Vec::with_capacity(8 + image_bytes.len());
        data_payload.extend_from_slice(&type_code.to_be_bytes());
        data_payload.extend_from_slice(&0u32.to_be_bytes());
        data_payload.extend_from_slice(image_bytes);

        let data_box = Self::build_box(b"data", &data_payload);
        Self::build_box(b"covr", &data_box)
    }

    fn build_box(box_type: &[u8], data: &[u8]) -> Vec<u8> {
        let total_size = (8 + data.len()) as u32;
        let mut out = Vec::with_capacity(total_size as usize);
        out.extend_from_slice(&total_size.to_be_bytes());
        out.extend_from_slice(&box_type[..4]);
        out.extend_from_slice(data);
        out
    }

    fn inject_udta_into_moov(original: &[u8], udta_atom: &[u8]) -> Result<Vec<u8>, SoftifyError> {
        let mut offset = 0;
        let mut moov_offset = None;
        let mut moov_size = None;
        let mut mdat_offset = None;

        while offset + 8 <= original.len() {
            let size = u32::from_be_bytes(original[offset..offset + 4].try_into().unwrap()) as usize;
            let box_type = &original[offset + 4..offset + 8];

            if box_type == b"moov" {
                moov_offset = Some(offset);
                moov_size = Some(size);
            } else if box_type == b"mdat" {
                mdat_offset = Some(offset);
            }

            if size < 8 {
                break;
            }
            offset += size;
        }

        let moov_off = moov_offset.ok_or_else(|| SoftifyError::Download { reason: "Missing moov atom in MP4".to_string() })?;
        let moov_sz = moov_size.ok_or_else(|| SoftifyError::Download { reason: "Invalid moov size".to_string() })?;

        let moov_data_start = moov_off + 8;
        let moov_data_end = moov_off + moov_sz;

        // Check if moov already contains udta
        let mut sub_offset = moov_data_start;
        let mut existing_udta = None;

        while sub_offset + 8 <= moov_data_end {
            let sub_size = u32::from_be_bytes(original[sub_offset..sub_offset + 4].try_into().unwrap()) as usize;
            if sub_size < 8 || sub_offset + sub_size > moov_data_end {
                break;
            }
            if &original[sub_offset + 4..sub_offset + 8] == b"udta" {
                existing_udta = Some((sub_offset, sub_size));
                break;
            }
            sub_offset += sub_size;
        }

        let mut result = Vec::with_capacity(original.len() + udta_atom.len());
        let added_bytes: usize;

        if let Some((udta_start, udta_len)) = existing_udta {
            result.extend_from_slice(&original[..udta_start]);
            result.extend_from_slice(udta_atom);
            result.extend_from_slice(&original[udta_start + udta_len..]);
            added_bytes = udta_atom.len().saturating_sub(udta_len);
        } else {
            result.extend_from_slice(&original[..moov_data_end]);
            result.extend_from_slice(udta_atom);
            result.extend_from_slice(&original[moov_data_end..]);
            added_bytes = udta_atom.len();
        }

        // Update moov atom size
        let new_moov_size = (moov_sz + added_bytes) as u32;
        result[moov_off..moov_off + 4].copy_from_slice(&new_moov_size.to_be_bytes());

        // CRITICAL: If moov is placed before mdat, inserting udta shifts mdat backward by added_bytes.
        // We must shift all sample chunk offsets (stco 32-bit & co64 64-bit) by added_bytes!
        if let Some(mdat_off) = mdat_offset {
            if moov_off < mdat_off {
                Self::shift_chunk_offsets(&mut result, moov_off + 8, moov_off + new_moov_size as usize, added_bytes as u32);
            }
        }

        Ok(result)
    }

    fn shift_chunk_offsets(bytes: &mut [u8], start: usize, end: usize, added_bytes: u32) {
        let mut offset = start;
        while offset + 8 <= end && offset + 8 <= bytes.len() {
            let size = u32::from_be_bytes(bytes[offset..offset + 4].try_into().unwrap()) as usize;
            if size < 8 || offset + size > end {
                break;
            }
            let box_type = &bytes[offset + 4..offset + 8];

            if box_type == b"trak" || box_type == b"mdia" || box_type == b"minf" || box_type == b"stbl" {
                Self::shift_chunk_offsets(bytes, offset + 8, offset + size, added_bytes);
            } else if box_type == b"stco" && offset + 16 <= bytes.len() {
                let count = u32::from_be_bytes(bytes[offset + 12..offset + 16].try_into().unwrap()) as usize;
                for i in 0..count {
                    let entry_pos = offset + 16 + (i * 4);
                    if entry_pos + 4 <= bytes.len() {
                        let old_val = u32::from_be_bytes(bytes[entry_pos..entry_pos + 4].try_into().unwrap());
                        bytes[entry_pos..entry_pos + 4].copy_from_slice(&(old_val + added_bytes).to_be_bytes());
                    }
                }
            } else if box_type == b"co64" && offset + 16 <= bytes.len() {
                let count = u32::from_be_bytes(bytes[offset + 12..offset + 16].try_into().unwrap()) as usize;
                for i in 0..count {
                    let entry_pos = offset + 16 + (i * 8);
                    if entry_pos + 8 <= bytes.len() {
                        let old_val = u64::from_be_bytes(bytes[entry_pos..entry_pos + 8].try_into().unwrap());
                        bytes[entry_pos..entry_pos + 8].copy_from_slice(&(old_val + added_bytes as u64).to_be_bytes());
                    }
                }
            }

            offset += size;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_minimal_mp4() -> Vec<u8> {
        let mut bytes = Vec::new();
        // ftyp box: 4 bytes major brand "M4A ", 4 bytes minor 0, 4 bytes compatible "M4A "
        let mut ftyp_payload = Vec::new();
        ftyp_payload.extend_from_slice(b"M4A ");
        ftyp_payload.extend_from_slice(&0u32.to_be_bytes());
        ftyp_payload.extend_from_slice(b"M4A ");
        let ftyp_box = M4aAtomTagger::build_box(b"ftyp", &ftyp_payload);
        bytes.extend_from_slice(&ftyp_box);

        // moov box containing stbl -> stco
        let mut stco_payload = vec![0u8; 4]; // version/flags
        stco_payload.extend_from_slice(&1u32.to_be_bytes()); // 1 entry
        stco_payload.extend_from_slice(&100u32.to_be_bytes()); // chunk offset 100
        let stco_box = M4aAtomTagger::build_box(b"stco", &stco_payload);

        let stbl_box = M4aAtomTagger::build_box(b"stbl", &stco_box);
        let minf_box = M4aAtomTagger::build_box(b"minf", &stbl_box);
        let mdia_box = M4aAtomTagger::build_box(b"mdia", &minf_box);
        let trak_box = M4aAtomTagger::build_box(b"trak", &mdia_box);
        let moov_box = M4aAtomTagger::build_box(b"moov", &trak_box);
        bytes.extend_from_slice(&moov_box);

        // mdat box (offset > moov)
        let mdat_box = M4aAtomTagger::build_box(b"mdat", &[0u8; 64]);
        bytes.extend_from_slice(&mdat_box);

        bytes
    }

    #[test]
    fn test_m4a_atom_injection_and_chunk_offset_shift() {
        let mp4 = create_minimal_mp4();
        assert!(M4aAtomTagger::is_valid_iso_mp4(&mp4));

        let temp_file = tempfile::NamedTempFile::new().unwrap();
        fs::write(temp_file.path(), &mp4).unwrap();

        let meta = M4aMetadata {
            title: "Kesariya",
            artist: "Arijit Singh",
            album: Some("Brahmāstra"),
            cover_art_bytes: Some(&[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]), // JPEG header
        };

        M4aAtomTagger::write_metadata(temp_file.path(), &meta).expect("write metadata");

        let updated = fs::read(temp_file.path()).unwrap();
        assert!(updated.len() > mp4.len());
        // Verify udta was injected
        assert!(updated.windows(4).any(|w| w == b"udta"));
        assert!(updated.windows(4).any(|w| w == b"ilst"));
        assert!(updated.windows(4).any(|w| w == b"covr"));
    }

    #[test]
    fn test_m4a_atom_stco_and_co64_offset_shift_verification() {
        let mut bytes = Vec::new();
        // ftyp box
        let mut ftyp_payload = Vec::new();
        ftyp_payload.extend_from_slice(b"M4A ");
        ftyp_payload.extend_from_slice(&0u32.to_be_bytes());
        ftyp_payload.extend_from_slice(b"M4A ");
        bytes.extend_from_slice(&M4aAtomTagger::build_box(b"ftyp", &ftyp_payload));

        // stco box with initial offset 100
        let mut stco_payload = vec![0u8; 4];
        stco_payload.extend_from_slice(&1u32.to_be_bytes()); // 1 entry
        stco_payload.extend_from_slice(&100u32.to_be_bytes()); // initial offset 100
        let stco_box = M4aAtomTagger::build_box(b"stco", &stco_payload);

        // co64 box with initial offset 1000
        let mut co64_payload = vec![0u8; 4];
        co64_payload.extend_from_slice(&1u32.to_be_bytes()); // 1 entry
        co64_payload.extend_from_slice(&1000u64.to_be_bytes()); // initial offset 1000
        let co64_box = M4aAtomTagger::build_box(b"co64", &co64_payload);

        let mut stbl_payload = Vec::new();
        stbl_payload.extend_from_slice(&stco_box);
        stbl_payload.extend_from_slice(&co64_box);

        let stbl_box = M4aAtomTagger::build_box(b"stbl", &stbl_payload);
        let minf_box = M4aAtomTagger::build_box(b"minf", &stbl_box);
        let mdia_box = M4aAtomTagger::build_box(b"mdia", &minf_box);
        let trak_box = M4aAtomTagger::build_box(b"trak", &mdia_box);
        let moov_box = M4aAtomTagger::build_box(b"moov", &trak_box);
        bytes.extend_from_slice(&moov_box);

        // mdat box placed after moov
        bytes.extend_from_slice(&M4aAtomTagger::build_box(b"mdat", &[0u8; 128]));

        let temp_file = tempfile::NamedTempFile::new().unwrap();
        fs::write(temp_file.path(), &bytes).unwrap();

        let meta = M4aMetadata {
            title: "Test Track",
            artist: "Test Artist",
            album: Some("Test Album"),
            cover_art_bytes: None,
        };

        M4aAtomTagger::write_metadata(temp_file.path(), &meta).expect("write metadata");
        let updated = fs::read(temp_file.path()).unwrap();
        let added_bytes = updated.len() - bytes.len();
        assert!(added_bytes > 0);

        // Find updated stco offset in updated bytes
        let stco_pos = updated.windows(4).position(|w| w == b"stco").expect("found stco");
        let new_stco_val = u32::from_be_bytes(updated[stco_pos + 12..stco_pos + 16].try_into().unwrap());
        assert_eq!(new_stco_val, 100 + added_bytes as u32, "stco offset must be shifted by exact added_bytes");

        // Find updated co64 offset in updated bytes
        let co64_pos = updated.windows(4).position(|w| w == b"co64").expect("found co64");
        let new_co64_val = u64::from_be_bytes(updated[co64_pos + 12..co64_pos + 20].try_into().unwrap());
        assert_eq!(new_co64_val, 1000 + added_bytes as u64, "co64 offset must be shifted by exact added_bytes");
    }
}
