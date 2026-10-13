import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/services/folder_launcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => Directory.systemTemp.path,
    );
  });

  test('FolderLauncherService resolves and creates download tracks directory', () async {
    final dir = await FolderLauncherService.getDownloadsDirectory();
    expect(dir, isA<Directory>());
    expect(dir.path, contains('tracks'));
    expect(await dir.exists(), isTrue);
  });
}
