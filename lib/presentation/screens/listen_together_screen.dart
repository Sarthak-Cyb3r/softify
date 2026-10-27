import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../services/sync/listen_together_protocol.dart';
import '../../services/sync/listen_together_service.dart';
import '../providers/player_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncing_scale_button.dart';
import '../widgets/shared/app_network_image.dart';

/// Metrolist-styled Listen Together screen providing real-time synchronized
/// group playback, room creation/joining, participant tracking, and drift health.
class ListenTogetherScreen extends ConsumerStatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  ConsumerState<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends ConsumerState<ListenTogetherScreen> {
  final TextEditingController _usernameController = TextEditingController(text: 'Listener');
  final TextEditingController _roomCodeController = TextEditingController();
  final ListenTogetherService _service = ListenTogetherService.instance;

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _createRoom() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await _service.createRoom(username: username);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create session: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _joinRoom() async {
    final username = _usernameController.text.trim();
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (username.isEmpty || roomCode.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await _service.joinRoom(roomCode: roomCode, username: username);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to join session: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _leaveRoom() async {
    HapticFeedback.selectionClick();
    await _service.leaveRoom();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentRoom = _service.currentRoom;
    final isInRoom = _service.isInRoom && currentRoom != null;
    final currentTrack = ref.watch(currentTrackProvider).value;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.groups_rounded, color: tokens.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listen Together',
                  style: TextStyle(
                    fontFamily: AppTheme.fontPageTitle,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  isInRoom ? 'Session Active • Code: ${currentRoom.roomCode}' : 'Real-time collaborative sync',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isInRoom ? tokens.accent : tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<ListenTogetherRoom?>(
          stream: _service.roomStream,
          initialData: currentRoom,
          builder: (context, snapshot) {
            final room = snapshot.data ?? currentRoom;
            if (room != null && _service.isInRoom) {
              return _buildActiveRoomView(context, room, currentTrack, tokens);
            }
            return _buildLobbyView(context, tokens);
          },
        ),
      ),
    );
  }

  Widget _buildLobbyView(BuildContext context, AppTokens tokens) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: tokens.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.error.withValues(alpha: 0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: tokens.error, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),

        // Display Name input card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.cardHover),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR LISTENER PROFILE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _usernameController,
                style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tokens.surfaceElevated,
                  prefixIcon: Icon(Icons.person_outline_rounded, color: tokens.textSecondary),
                  hintText: 'Enter your nickname...',
                  hintStyle: TextStyle(color: tokens.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Host a Session Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.cardHover),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.podcasts_rounded, color: tokens.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host a Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Invite friends to listen to your queue synchronously',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BouncingScaleButton(
                onTap: _isConnecting ? null : _createRoom,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                  ),
                  child: Center(
                    child: _isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Create Session Room',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Join Session Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.cardHover),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.accentCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.login_rounded, color: tokens.accentCyan, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join a Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enter the 6-character room code from your friend',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.0,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: tokens.surfaceElevated,
                  prefixIcon: Icon(Icons.tag_rounded, color: tokens.textSecondary),
                  hintText: 'ROOM CODE',
                  hintStyle: TextStyle(
                    color: tokens.textMuted,
                    letterSpacing: 2.0,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              BouncingScaleButton(
                onTap: _isConnecting ? null : _joinRoom,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusFull),
                    border: Border.all(color: tokens.cardHover),
                  ),
                  child: Center(
                    child: Text(
                      'Join Session Room',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Metrolist Feature Highlights
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFeatureChip(Icons.speed_rounded, '< 50ms Drift', tokens),
            _buildFeatureChip(Icons.high_quality_rounded, '320 KBPS Studio', tokens),
            _buildFeatureChip(Icons.sync_rounded, 'Barrier Clock', tokens),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String text, AppTokens tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: tokens.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textMuted),
        ),
      ],
    );
  }

  Widget _buildActiveRoomView(
    BuildContext context,
    ListenTogetherRoom room,
    Track? currentTrack,
    AppTokens tokens,
  ) {
    final users = room.users;
    final isHost = _service.isHost;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        // Room Code Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SESSION ROOM CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.roomCode,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.0,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: room.roomCode));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Room code copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: tokens.card,
                    ),
                  );
                },
                icon: Icon(Icons.copy_rounded, color: tokens.accent),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Synchronized Playback Card
        if (currentTrack != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.cardHover),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AppNetworkImage(imageUrl: currentTrack.coverUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrack.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentTrack.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHost ? 'BROADCASTING' : 'SYNCED',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Connected Listeners List
        Text(
          'CONNECTED LISTENERS (${users.length})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        ...users.map(
          (u) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.cardHover),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: u.isHost
                      ? tokens.accent.withValues(alpha: 0.2)
                      : tokens.surfaceElevated,
                  child: Text(
                    u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: u.isHost ? tokens.accent : tokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    u.username,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: u.isHost
                        ? tokens.accent.withValues(alpha: 0.15)
                        : tokens.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    u.isHost ? 'HOST' : 'GUEST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: u.isHost ? tokens.accent : tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Leave Session Button
        BouncingScaleButton(
          onTap: _leaveRoom,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(tokens.radiusFull),
              border: Border.all(color: tokens.error.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                isHost ? 'End Collaborative Session' : 'Leave Session',
                style: TextStyle(
                  color: tokens.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
