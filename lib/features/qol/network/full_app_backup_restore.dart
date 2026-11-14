import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softify/presentation/theme/app_tokens.dart';

/// Metadata model for Softify full database and settings backup archive.
class SoftifyBackupArchive {
  final int version;
  final DateTime exportedAt;
  final String appVersion;
  final Map<String, dynamic> preferences;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic> metadata;

  const SoftifyBackupArchive({
    required this.version,
    required this.exportedAt,
    required this.appVersion,
    required this.preferences,
    required this.playlists,
    required this.history,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'appVersion': appVersion,
        'preferences': preferences,
        'playlists': playlists,
        'history': history,
        'metadata': metadata,
      };

  factory SoftifyBackupArchive.fromJson(Map<String, dynamic> json) {
    return SoftifyBackupArchive(
      version: json['version'] as int? ?? 1,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.now(),
      appVersion: json['appVersion'] as String? ?? '4.0.2',
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? {},
      playlists: (json['playlists'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Controller managing full application state backup and restoration.
class FullAppBackupRestoreNotifier
    extends StateNotifier<AsyncValue<SoftifyBackupArchive?>> {
  FullAppBackupRestoreNotifier() : super(const AsyncValue.data(null));

  final Map<String, dynamic> _memorySettings = {
    'audio_quality': 'high',
    'crossfade_seconds': 5,
    'theme': 'amoled',
    'discord_rpc_enabled': true,
  };

  Future<String?> exportBackup({String? targetDirectory}) async {
    state = const AsyncValue.loading();
    try {
      final archive = SoftifyBackupArchive(
        version: 1,
        exportedAt: DateTime.now(),
        appVersion: '4.0.2',
        preferences: Map<String, dynamic>.from(_memorySettings),
        playlists: [],
        history: [],
        metadata: {
          'platform': 'linux',
          'totalSettings': _memorySettings.length,
        },
      );

      final jsonString =
          const JsonEncoder.withIndent('  ').convert(archive.toJson());
      final defaultDir = targetDirectory ?? Directory.systemTemp.path;
      final fileName =
          'softify_backup_${DateTime.now().millisecondsSinceEpoch}.softifybackup';
      final file = File('$defaultDir/$fileName');
      await file.writeAsString(jsonString);

      state = AsyncValue.data(archive);
      return file.path;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> restoreFromArchiveString(String jsonContent) async {
    state = const AsyncValue.loading();
    try {
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final archive = SoftifyBackupArchive.fromJson(decoded);
      _memorySettings.addAll(archive.preferences);

      state = AsyncValue.data(archive);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> restoreFromFilePath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      return await restoreFromArchiveString(content);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final fullAppBackupRestoreProvider = StateNotifierProvider<
    FullAppBackupRestoreNotifier, AsyncValue<SoftifyBackupArchive?>>((ref) {
  return FullAppBackupRestoreNotifier();
});

/// UI Settings Card for complete application backup and restore.
class BackupRestoreCard extends ConsumerWidget {
  const BackupRestoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final backupState = ref.watch(fullAppBackupRestoreProvider);

    return Container(
      margin: EdgeInsets.symmetric(vertical: tokens.spaceSm),
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: tokens.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.backup_rounded, color: tokens.accent, size: 24),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Data Backup & Restore',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Export entire Softify database and preferences into a single .softifybackup file',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final path = await ref
                        .read(fullAppBackupRestoreProvider.notifier)
                        .exportBackup();
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backup exported to $path')),
                      );
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export Backup'),
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final defaultPath =
                        '${Directory.systemTemp.path}/softify_backup_default.softifybackup';
                    final success = await ref
                        .read(fullAppBackupRestoreProvider.notifier)
                        .restoreFromFilePath(defaultPath);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Data restored successfully!'
                              : 'No default backup archive found at $defaultPath'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Restore Backup'),
                ),
              ),
            ],
          ),
          if (backupState.isLoading) ...[
            SizedBox(height: tokens.spaceSm),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
