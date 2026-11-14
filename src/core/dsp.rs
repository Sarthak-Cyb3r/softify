use std::f32::consts::PI;

/// Computes magnitude spectrum across N frequency bins using a Hann windowed Discrete Fourier Transform.
pub fn compute_spectrum_magnitudes(samples: &[f32], bin_count: usize) -> Vec<f32> {
    if samples.is_empty() || bin_count == 0 {
        return vec![0.0; bin_count];
    }

    let n = samples.len();
    let mut magnitudes = Vec::with_capacity(bin_count);

    // Apply Hann window and calculate frequency bucket magnitudes
    for k in 0..bin_count {
        let mut real = 0.0f32;
        let mut imag = 0.0f32;

        for (i, &sample) in samples.iter().enumerate() {
            // Hann window: 0.5 * (1 - cos(2*pi*i / (N-1)))
            let window = 0.5 * (1.0 - (2.0 * PI * (i as f32) / (n as f32 - 1.0)).cos());
            let windowed = sample * window;

            let angle = -2.0 * PI * (k as f32) * (i as f32) / (n as f32);
            real += windowed * angle.cos();
            imag += windowed * angle.sin();
        }

        let mag = (real * real + imag * imag).sqrt() / (n as f32);
        magnitudes.push(mag);
    }

    magnitudes
}
