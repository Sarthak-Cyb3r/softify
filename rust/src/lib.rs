pub mod cipher;
pub mod dsp;
pub mod scanner;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::slice;

/// Recursively scans a directory for audio tracks multi-threaded across CPU cores.
/// Returns a JSON string of tracks. Caller must free using `softify_free_string`.
#[no_mangle]
pub extern "C" fn softify_scan_directory(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let tracks = scanner::scan_local_directory(path_str);
    let json_str = match serde_json::to_string(&tracks) {
        Ok(j) => j,
        Err(_) => return std::ptr::null_mut(),
    };

    match CString::new(json_str) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Decrypts JioSaavn encrypted_media_url to 320 Kbps CD-quality studio stream URL.
/// Returns null pointer on error. Caller must free using `softify_free_string`.
#[no_mangle]
pub extern "C" fn softify_decrypt_saavn_media_url(
    encrypted_b64: *const c_char,
    target_bitrate: u32,
) -> *mut c_char {
    if encrypted_b64.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(encrypted_b64) };
    let b64_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    match cipher::decrypt_saavn_media_url(b64_str, target_bitrate) {
        Ok(url) => match CString::new(url) {
            Ok(c) => c.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        Err(_) => std::ptr::null_mut(),
    }
}

/// Normalizes Unicode text: strips non-breaking spaces, brackets, non-alphanumeric chars.
/// Returns allocated C-string. Caller must free using `softify_free_string`.
#[no_mangle]
pub extern "C" fn softify_normalize_text(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(input) };
    let text = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let normalized = cipher::normalize_text(text);
    match CString::new(normalized) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Phonetically simplifies normalized text by collapsing vowel clusters.
/// Returns allocated C-string. Caller must free using `softify_free_string`.
#[no_mangle]
pub extern "C" fn softify_phonetic_simplify(input: *const c_char) -> *mut c_char {
    if input.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(input) };
    let text = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let simplified = cipher::phonetic_simplify(text);
    match CString::new(simplified) {
        Ok(c) => c.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Computes spectrum magnitudes for visualizer from raw PCM float samples.
#[no_mangle]
pub extern "C" fn softify_compute_spectrum(
    samples_ptr: *const f32,
    samples_len: usize,
    bin_count: usize,
    output_ptr: *mut f32,
) {
    if samples_ptr.is_null() || output_ptr.is_null() || samples_len == 0 || bin_count == 0 {
        return;
    }

    let samples = unsafe { slice::from_raw_parts(samples_ptr, samples_len) };
    let magnitudes = dsp::compute_spectrum_magnitudes(samples, bin_count);

    let output = unsafe { slice::from_raw_parts_mut(output_ptr, bin_count) };
    output.copy_from_slice(&magnitudes);
}

/// Frees a string allocated by the Rust native engine.
#[no_mangle]
pub extern "C" fn softify_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
