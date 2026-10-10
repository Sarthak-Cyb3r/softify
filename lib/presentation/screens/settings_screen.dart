// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/audio_quality_preset.dart';
import '../../domain/ports/i_update_checker.dart';
import '../providers/diversity_providers.dart';
import '../providers/player_providers.dart';
import '../providers/equalizer_providers.dart';
import '../providers/settings_providers.dart';
import '../theme/app_theme.dart';
import 'debug_metrics_screen.dart';
import 'equalizer_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingUpdate = false;
  bool _isDownloadingUpdate = false;
  double _downloadProgress = 0.0;
  String? _updateStatusMessage;
  AppReleaseInfo? _availableRelease;
  int _versionTapCount = 0;
  DateTime? _lastVersionTap;

  bool _isPingingInstances = false;

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMessage = 'Checking GitHub Releases for updates...';
      _availableRelease = null;
    });

    try {
      final checker = ref.read(updateCheckerProvider);
      final currentVersion = ref.read(currentAppVersionProvider);
      final release = await checker.checkForUpdate(currentVersion);

      if (!mounted) return;
      if (release != null) {
        setState(() {
          _availableRelease = release;
          _updateStatusMessage = 'New version ${release.tagName} is available!';
        });
      } else {
        setState(() {
          _updateStatusMessage = 'Softify is up to date (v$currentVersion).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateStatusMessage = 'Failed to check updates: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _startDownloadAndInstall(AppReleaseInfo release) async {
    setState(() {
      _isDownloadingUpdate = true;
      _downloadProgress = 0.0;
      _updateStatusMessage = 'Downloading ${release.tagName}...';
    });

    try {
      final checker = ref.read(updateCheckerProvider);
      await checker.downloadAndInstallUpdate(
        release,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _updateStatusMessage = 'Installer launched!';
        });
      }
    } on UpdateInstallException catch (e) {
      if (!mounted) return;
      setState(() {
        _updateStatusMessage = e.message;
      });
      if (e.error == UpdateInstallError.signatureMismatch) {
        await _handleSignatureMismatch(release);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateStatusMessage = 'Update failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingUpdate = false;
        });
      }
    }
  }

  /// The update is signed with a different key than the installed app, so
  /// Android refuses it. The APK is saved to Downloads first (it survives the
  /// uninstall), then the user reinstalls from there.
  Future<void> _handleSignatureMismatch(AppReleaseInfo release) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reinstall required'),
        content: Text(
          'This update (${release.tagName}) is signed with a new key, so Android '
          'cannot install it over the current app.\n\n'
          'Softify must be uninstalled and reinstalled first — your library, '
          'playlists, downloads and settings will be erased.\n\n'
          'The update APK will be saved to your Downloads folder. After the app '
          'closes, open Files → Downloads and tap the APK to install it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save update & uninstall'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    final checker = ref.read(updateCheckerProvider);
    setState(() {
      _updateStatusMessage = 'Saving update APK to Downloads...';
    });
    try {
      await checker.stageDownloadedUpdate();
      if (!mounted) return;
      setState(() {
        _updateStatusMessage = 'Update saved to Downloads. Uninstalling Softify...';
      });
      await checker.uninstallInstalledApp();
      // Normally the process dies here; if the uninstall did not happen,
      // fall through with an explanatory status.
      if (mounted) {
        setState(() {
          _updateStatusMessage =
              'Uninstall did not complete. Install the saved APK from Downloads manually.';
        });
      }
    } on UpdateInstallException catch (e) {
      if (mounted) {
        setState(() {
          _updateStatusMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateStatusMessage = 'Reinstall flow failed: $e';
        });
      }
    }
  }

  Future<void> _pingAllInstances() async {
    setState(() {
      _isPingingInstances = true;
    });

    final repo = ref.read(remoteConfigRepositoryProvider);
    final instances = repo.getFallbackPipedInstances();

    for (final inst in instances) {
      await repo.checkInstanceLatency(inst);
    }

    if (mounted) {
      setState(() {
        _isPingingInstances = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instance latency checks completed'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTap == null ||
        now.difference(_lastVersionTap!).inSeconds > 2) {
      _versionTapCount = 0;
    }
    _lastVersionTap = now;
    _versionTapCount++;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DebugMetricsScreen()),
      );
    } else if (_versionTapCount >= 4) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tap ${7 - _versionTapCount} more times to open Developer Metrics',
          ),
          duration: const Duration(milliseconds: 600),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final currentQuality = ref.watch(audioQualityPresetProvider);
    final currentVersion = ref.watch(currentAppVersionProvider);
    final instancesAsync = ref.watch(pipedInstancesStreamProvider);
    final autoPlayAsync = ref.watch(autoPlayStreamProvider);
    final autoPlayEnabled = autoPlayAsync.value ?? true;
    final learningPausedAsync = ref.watch(learningPausedProvider);
    final snoozedArtistsAsync = ref.watch(snoozedArtistsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Section 0: Profile
          _buildSectionHeader('Profile'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.person, color: Colors.black),
              ),
              title: Text(
                userName != null && userName.trim().isNotEmpty
                    ? userName.trim()
                    : 'Set your name',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: const Text(
                'Personalized greeting on Home screen',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              trailing: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
              onTap: () => _showEditNameDialog(context),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Audio Quality & Playback
          _buildSectionHeader('Playback & Streaming'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                RadioListTile<AudioQualityPreset>(
                  activeColor: AppTheme.primary,
                  title: const Text('Standard (Recommended)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('~128 kbps AAC. High fidelity streaming.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  value: AudioQualityPreset.standard,
                  groupValue: currentQuality,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(audioQualityPresetProvider.notifier).setQuality(val);
                    }
                  },
                ),
                const Divider(color: Colors.black26, height: 1),
                RadioListTile<AudioQualityPreset>(
                  activeColor: AppTheme.primary,
                  title: const Text('Data Saver',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('~64 kbps. Lower data consumption on mobile networks.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  value: AudioQualityPreset.low,
                  groupValue: currentQuality,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(audioQualityPresetProvider.notifier).setQuality(val);
                    }
                  },
                ),
                const Divider(color: Colors.black26, height: 1),
                SwitchListTile(
                  activeColor: AppTheme.primary,
                  title: const Text('Autoplay Similar Songs',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Keep listening to similar songs when your music finishes.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  value: autoPlayEnabled,
                  onChanged: (val) {
                    final audioHandler = ref.read(audioHandlerProvider);
                    audioHandler.setAutoPlayEnabled(val);
                  },
                ),
                const Divider(color: Colors.black26, height: 1),
                Consumer(
                  builder: (context, ref, _) {
                    final eqState = ref.watch(equalizerProvider);
                    return ListTile(
                      leading: const Icon(Icons.equalizer, color: AppTheme.primary),
                      title: const Text('Equalizer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        eqState.enabled
                            ? 'Active • ${eqState.currentPreset}${eqState.bassBoost > 0 ? " • Bass +${(eqState.bassBoost * 5).toStringAsFixed(1)}dB" : ""}'
                            : 'Off',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Lyrics & Synchronization
          _buildSectionHeader('Lyrics & Synchronization'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Consumer(
              builder: (context, ref, _) {
                final lyricsConfig = ref.watch(spotifyLyricsConfigProvider);
                final hasToken = lyricsConfig.token != null && lyricsConfig.token!.isNotEmpty;
                final hasEndpoint = lyricsConfig.endpoint != null && lyricsConfig.endpoint!.isNotEmpty;

                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.sync,
                        color: (hasToken || hasEndpoint) ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                      title: const Text('Primary Lyrics Engine',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        hasToken || hasEndpoint
                            ? 'Spotify Color-Lyrics API (Active)'
                            : 'LRCLIB & Kugou Synced Catalogs (Active - Millisecond Calibrated)',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    const Divider(color: Colors.black26, height: 1),
                    ListTile(
                      leading: const Icon(Icons.key, color: Colors.white70),
                      title: const Text('Spotify Web Token / sp_dc',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        hasToken
                            ? 'Configured • ${lyricsConfig.token!.substring(0, lyricsConfig.token!.length.clamp(0, 10))}...'
                            : 'Optional: Spotify Web Player Bearer token for native Color-Lyrics',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      trailing: hasToken
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.redAccent),
                              tooltip: 'Remove Token',
                              onPressed: () => ref.read(spotifyLyricsConfigProvider.notifier).setToken(null),
                            )
                          : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => _showTokenInputDialog(context, ref, lyricsConfig.token),
                    ),
                    const Divider(color: Colors.black26, height: 1),
                    ListTile(
                      leading: const Icon(Icons.dns, color: Colors.white70),
                      title: const Text('Custom Lyrics Proxy Endpoint',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        hasEndpoint
                            ? lyricsConfig.endpoint!
                            : 'Optional: Self-hosted reverse-engineered Spotify lyrics proxy URL',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      trailing: hasEndpoint
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.redAccent),
                              tooltip: 'Remove Endpoint',
                              onPressed: () => ref.read(spotifyLyricsConfigProvider.notifier).setEndpoint(null),
                            )
                          : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                      onTap: () => _showEndpointInputDialog(context, ref, lyricsConfig.endpoint),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: App Updates
          _buildSectionHeader('App Updates'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onVersionTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Version $currentVersion',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            const Text('Direct GitHub Releases Updater',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: (_isCheckingUpdate || _isDownloadingUpdate)
                          ? null
                          : _checkForUpdate,
                      child: _isCheckingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Check', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (_updateStatusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _updateStatusMessage!,
                    style: TextStyle(
                      color: _availableRelease != null ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (_isDownloadingUpdate) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                if (_availableRelease != null && !_isDownloadingUpdate) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.textSecondary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () {
                          _showChangelogDialog(context, _availableRelease!);
                        },
                        child: const Text('Changelog'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _startDownloadAndInstall(_availableRelease!),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Install Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: Fallback Instances & Health
          _buildSectionHeader('Fallback Instances (Piped)'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Decentralized Failover',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _isPingingInstances ? null : _pingAllInstances,
                        icon: _isPingingInstances
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              )
                            : const Icon(Icons.refresh, size: 16, color: AppTheme.primary),
                        label: const Text('Test Health', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.black26, height: 1),
                instancesAsync.when(
                  data: (instances) {
                    if (instances.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No instances cached yet. Tap Test Health to probe defaults.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: instances.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.black12, height: 1),
                      itemBuilder: (context, index) {
                        final inst = instances[index];
                        final latency = inst.latencyMs;
                        final color = latency == null
                            ? Colors.redAccent
                            : latency < 500
                                ? AppTheme.primary
                                : Colors.orangeAccent;
                        return ListTile(
                          dense: true,
                          title: Text(inst.url,
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text(
                            latency != null ? '$latency ms latency' : 'Offline / Unreachable',
                            style: TextStyle(color: color, fontSize: 11),
                          ),
                          trailing: Icon(
                            inst.isHealthy ? Icons.check_circle : Icons.error,
                            color: color,
                            size: 16,
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 4: Storage & Cache
          _buildSectionHeader('Storage & Cache'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lyrics, color: Colors.white70),
                  title: const Text('Clear Lyrics Cache', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Deletes locally cached synchronized LRC lyrics',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () async {
                      final count = await ref.read(cacheManagerProvider).clearLyricsCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleared $count cached lyrics entries'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      }
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                const Divider(color: Colors.black26, height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.white70),
                  title: const Text('Clear Temporary Cache', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Deletes streaming buffers and temporary downloads',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(cacheManagerProvider).clearTemporaryCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Temporary cache cleared'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      }
                    },
                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 5: Discovery & Learning Controls
          _buildSectionHeader('Discovery & Taste Controls'),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: AppTheme.primary,
                  title: const Text('Incognito Taste (Pause Learning)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text(
                    'Pause training on-device recommendation models from current listening',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  value: learningPausedAsync.value ?? false,
                  onChanged: (val) async {
                    await ref.read(diversityControllerProvider).setLearningPaused(val);
                    ref.invalidate(learningPausedProvider);
                  },
                ),
                const Divider(color: Colors.black26, height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1, color: AppTheme.primary, size: 20),
                  title: const Text('Pick Favorite Artists', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Seed recommendation engines with artists you love', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    );
                  },
                ),
                const Divider(color: Colors.black26, height: 1),
                ListTile(
                  leading: const Icon(Icons.snooze, color: AppTheme.primary, size: 20),
                  title: const Text('Snooze an Artist (30 Days)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: snoozedArtistsAsync.when(
                    data: (artists) => Text(
                      artists.isEmpty ? 'No artists snoozed' : '${artists.length} snoozed: ${artists.join(", ")}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    loading: () => const Text('Loading snoozed...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    error: (_, __) => const Text('Error loading snoozes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  trailing: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                  onTap: () => _showSnoozeArtistDialog(context),
                ),
                const Divider(color: Colors.black26, height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.redAccent, size: 20),
                  title: const Text('Reset Recommendation Learning', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                  subtitle: const Text('Wipes taste profile and starts recommendation models fresh', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  onTap: () => _showResetLearningDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 6: About Softify
          _buildSectionHeader('About Softify'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Softify',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ad-Free, Paywall-Free Mobile Music Streaming Application',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  '100% Client-Side Architecture. Zero Central Servers. Zero Telemetry. Direct keyless YouTube streaming, container-native M4A tagging, and synced LRCLIB lyrics.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel_rounded, size: 18, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This project is built for educational purposes and personal use. It is not affiliated with, endorsed by, or connected to Spotify, YouTube, or JioSaavn. No copyrighted content is hosted on this app.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _showTokenInputDialog(BuildContext context, WidgetRef ref, String? currentToken) {
    final controller = TextEditingController(text: currentToken ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Spotify Web Token', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Spotify Web Player access token or sp_dc token to pull synchronized color-lyrics directly from spclient.wg.spotify.com.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Paste Bearer token here...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF1B1B1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF292A2D)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              ref.read(spotifyLyricsConfigProvider.notifier).setToken(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEndpointInputDialog(BuildContext context, WidgetRef ref, String? currentEndpoint) {
    final controller = TextEditingController(text: currentEndpoint ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Custom Lyrics Endpoint', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a custom reverse-engineered Spotify lyrics proxy URL (e.g. https://lyrics.myserver.com).',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF1B1B1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF292A2D)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              ref.read(spotifyLyricsConfigProvider.notifier).setEndpoint(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangelogDialog(BuildContext context, AppReleaseInfo release) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: Text(
          'Release Notes (${release.tagName})',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            release.releaseNotes.isNotEmpty
                ? release.releaseNotes
                : 'No release notes provided for this version.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final current = ref.read(userNameProvider) ?? '';
    final controller = TextEditingController(text: current);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              ref.read(userNameProvider.notifier).setUserName(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnoozeArtistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Snooze Artist for 30 Days', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tracks and suggestions from this artist will be excluded from discovery mixes for 30 days.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Artist name (e.g. Drake)',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await ref.read(diversityControllerProvider).snoozeArtist(name, const Duration(days: 30));
                ref.invalidate(snoozedArtistsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Snoozed "$name" for 30 days'), backgroundColor: AppTheme.primary),
                  );
                }
              }
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }

  void _showResetLearningDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset All Learning?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently reset your on-device taste profiles, bandit exploration states, and autocomplete completions. Liked songs and playlists remain safe.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(diversityControllerProvider).resetAllLearning();
              ref.invalidate(snoozedArtistsProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('On-device learning reset successfully'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Reset Now'),
          ),
        ],
      ),
    );
  }
}
