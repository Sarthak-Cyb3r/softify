import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _NativeScanDirectoryC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _NativeScanDirectoryDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _NativeFreeStringC = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _NativeFreeStringDart = void Function(ffi.Pointer<Utf8>);

typedef _NativeComputeSpectrumC = ffi.Void Function(
  ffi.Pointer<ffi.Float>,
  ffi.Size,
  ffi.Size,
  ffi.Pointer<ffi.Float>,
);
typedef _NativeComputeSpectrumDart = void Function(
  ffi.Pointer<ffi.Float>,
  int,
  int,
  ffi.Pointer<ffi.Float>,
);

typedef _NativeDecryptSaavnMediaUrlC = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8>,
  ffi.Uint32,
);
typedef _NativeDecryptSaavnMediaUrlDart = ffi.Pointer<Utf8> Function(
  ffi.Pointer<Utf8>,
  int,
);

typedef _NativeNormalizeTextC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _NativeNormalizeTextDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _NativePhoneticSimplifyC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _NativePhoneticSimplifyDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

class SoftifyNativeEngine {
  static SoftifyNativeEngine? _instance;
  static SoftifyNativeEngine get instance => _instance ??= SoftifyNativeEngine._();

  ffi.DynamicLibrary? _dylib;
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  _NativeScanDirectoryDart? _scanDirectory;
  _NativeFreeStringDart? _freeString;
  _NativeComputeSpectrumDart? _computeSpectrum;
  _NativeDecryptSaavnMediaUrlDart? _decryptSaavnMediaUrl;
  _NativeNormalizeTextDart? _normalizeText;
  _NativePhoneticSimplifyDart? _phoneticSimplify;

  SoftifyNativeEngine._() {
    _initDylib();
  }

  void _initDylib() {
    try {
      if (Platform.isLinux) {
        _dylib = ffi.DynamicLibrary.open('libsoftify_native.so');
      } else if (Platform.isMacOS) {
        _dylib = ffi.DynamicLibrary.open('libsoftify_native.dylib');
      } else if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('softify_native.dll');
      } else if (Platform.isAndroid) {
        _dylib = ffi.DynamicLibrary.open('libsoftify_native.so');
      }
    } catch (_) {
      // Fallback: look relative to current executable or library directory
      try {
        final libPath = '${File(Platform.resolvedExecutable).parent.path}/lib/libsoftify_native.so';
        if (File(libPath).existsSync()) {
          _dylib = ffi.DynamicLibrary.open(libPath);
        }
      } catch (_) {}
    }

    if (_dylib != null) {
      try {
        _scanDirectory = _dylib!
            .lookup<ffi.NativeFunction<_NativeScanDirectoryC>>('softify_scan_directory')
            .asFunction();
        _freeString = _dylib!
            .lookup<ffi.NativeFunction<_NativeFreeStringC>>('softify_free_string')
            .asFunction();
        _computeSpectrum = _dylib!
            .lookup<ffi.NativeFunction<_NativeComputeSpectrumC>>('softify_compute_spectrum')
            .asFunction();
        _decryptSaavnMediaUrl = _dylib!
            .lookup<ffi.NativeFunction<_NativeDecryptSaavnMediaUrlC>>('softify_decrypt_saavn_media_url')
            .asFunction();
        _normalizeText = _dylib!
            .lookup<ffi.NativeFunction<_NativeNormalizeTextC>>('softify_normalize_text')
            .asFunction();
        _phoneticSimplify = _dylib!
            .lookup<ffi.NativeFunction<_NativePhoneticSimplifyC>>('softify_phonetic_simplify')
            .asFunction();
        _isAvailable = true;
      } catch (_) {
        _isAvailable = false;
      }
    }
  }

  /// High-speed multi-threaded local directory scanner via native Rust engine.
  Future<List<Map<String, dynamic>>> scanDirectory(String path) async {
    if (!_isAvailable || _scanDirectory == null || _freeString == null) {
      return [];
    }

    final pathPtr = path.toNativeUtf8();
    try {
      final resultPtr = _scanDirectory!(pathPtr);
      if (resultPtr == ffi.nullptr) return [];

      final jsonStr = resultPtr.toDartString();
      _freeString!(resultPtr);

      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// High-performance DES-ECB media URL decryptor & 320 Kbps stream rewriter in Rust.
  String? decryptSaavnUrl(String encryptedB64, {int targetBitrate = 320000}) {
    if (!_isAvailable || _decryptSaavnMediaUrl == null || _freeString == null) {
      return null;
    }

    final b64Ptr = encryptedB64.toNativeUtf8();
    try {
      final resultPtr = _decryptSaavnMediaUrl!(b64Ptr, targetBitrate);
      if (resultPtr == ffi.nullptr) return null;

      final url = resultPtr.toDartString();
      _freeString!(resultPtr);
      return url;
    } catch (_) {
      return null;
    } finally {
      calloc.free(b64Ptr);
    }
  }

  /// SIMD-speed Unicode-aware text normalizer in Rust.
  String? normalizeText(String input) {
    if (!_isAvailable || _normalizeText == null || _freeString == null) {
      return null;
    }

    final inputPtr = input.toNativeUtf8();
    try {
      final resultPtr = _normalizeText!(inputPtr);
      if (resultPtr == ffi.nullptr) return null;

      final normalized = resultPtr.toDartString();
      _freeString!(resultPtr);
      return normalized;
    } catch (_) {
      return null;
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Phonetic string simplification in Rust for fuzzy catalog matching.
  String? phoneticSimplify(String input) {
    if (!_isAvailable || _phoneticSimplify == null || _freeString == null) {
      return null;
    }

    final inputPtr = input.toNativeUtf8();
    try {
      final resultPtr = _phoneticSimplify!(inputPtr);
      if (resultPtr == ffi.nullptr) return null;

      final simplified = resultPtr.toDartString();
      _freeString!(resultPtr);
      return simplified;
    } catch (_) {
      return null;
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Computes spectrum magnitudes for visualizer from raw PCM float samples.
  Float32List? computeSpectrum(Float32List samples, int binCount) {
    if (!_isAvailable || _computeSpectrum == null || samples.isEmpty || binCount == 0) {
      return null;
    }

    final samplesPtr = calloc<ffi.Float>(samples.length);
    final outputPtr = calloc<ffi.Float>(binCount);

    try {
      samplesPtr.asTypedList(samples.length).setAll(0, samples);
      _computeSpectrum!(samplesPtr, samples.length, binCount, outputPtr);

      final result = Float32List(binCount);
      result.setAll(0, outputPtr.asTypedList(binCount));
      return result;
    } catch (_) {
      return null;
    } finally {
      calloc.free(samplesPtr);
      calloc.free(outputPtr);
    }
  }
}
