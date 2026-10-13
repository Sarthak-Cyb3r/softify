import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cross-platform utility to open the directory where offline/saved tracks reside.
/// Supports Linux, macOS, Windows, and Android.
class FolderLauncherService {
  static const MethodChannel _platformChannel = MethodChannel('com.softify/installer');

  /// Resolves the canonical folder where downloaded tracks are saved.
  static Future<Directory> getDownloadsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tracksDir = Directory(p.join(docsDir.path, 'tracks'));
    if (!await tracksDir.exists()) {
      await tracksDir.create(recursive: true);
    }
    return tracksDir;
  }

  /// Opens the folder containing downloaded tracks.
  static Future<void> openDownloadsFolder(BuildContext context) async {
    try {
      final tracksDir = await getDownloadsDirectory();

      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [tracksDir.path]);
        if (result.exitCode != 0 && context.mounted) {
          _showFolderSnackbar(context, tracksDir.path);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', [tracksDir.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [tracksDir.path]);
      } else if (Platform.isAndroid) {
        bool opened = false;
        try {
          final res = await _platformChannel.invokeMethod<bool>('openFolder', {
            'path': tracksDir.path,
          });
          opened = res ?? false;
        } catch (_) {
          opened = false;
        }
        if (context.mounted) {
          _showFolderSnackbar(context, tracksDir.path, wasDirectlyOpened: opened);
        }
      } else {
        if (context.mounted) {
          _showFolderSnackbar(context, tracksDir.path);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open folder: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static void _showFolderSnackbar(
    BuildContext context,
    String path, {
    bool wasDirectlyOpened = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.folder_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                wasDirectlyOpened ? 'Opened: $path' : 'Saved songs: $path',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Copy Path',
          textColor: const Color(0xFF4EDEA3),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: path));
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
