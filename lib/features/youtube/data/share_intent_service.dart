import 'dart:io';

import 'package:flutter/services.dart';

class ShareIntentService {
  static const MethodChannel _channel = MethodChannel('com.softify/share_intent');

  /// Listens for shared text intents across cold start and warm start.
  static void initialize({required void Function(String text) onReceived}) {
    if (!Platform.isAndroid) return;

    // 1. Cold start intent check
    _channel.invokeMethod<String>('getInitialSharedText').then((text) {
      if (text != null && text.trim().isNotEmpty) {
        onReceived(text.trim());
      }
    }).catchError((_) {});

    // 2. Warm start intent handler
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        final text = call.arguments as String?;
        if (text != null && text.trim().isNotEmpty) {
          onReceived(text.trim());
        }
      }
    });
  }
}
