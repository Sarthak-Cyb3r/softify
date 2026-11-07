import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
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

class SoftifyNativeEngine {
  static SoftifyNativeEngine? _instance;
  static SoftifyNativeEngine get instance => _instance ??= SoftifyNativeEngine._();

  ffi.DynamicLibrary? _dylib;
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  _NativeScanDirectoryDart? _scanDirectory;
  _NativeFreeStringDart? _freeString;
  _NativeComputeSpectrumDart? _computeSpectrum;

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
}
