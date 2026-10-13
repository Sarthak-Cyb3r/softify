import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/services/discord_rpc_service.dart';
import 'package:softify/domain/entities/track.dart';

void main() {
  test('DiscordRpcService initializes cleanly and handles desktop presence safely', () async {
    final service = DiscordRpcService(clientId: 'test_client_id');
    expect(service.isConnected, isFalse);

    // Should gracefully fail or no-op without crashing when Discord IPC socket is not present
    await service.updatePresence(
      track: const Track(
        id: 'test_track',
        sourceId: 'src_test',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        duration: Duration(minutes: 5, seconds: 55),
      ),
      isPlaying: true,
      position: const Duration(minutes: 1),
    );

    // Clearing presence also handles disconnected socket safely
    await service.updatePresence(
      track: null,
      isPlaying: false,
    );

    service.dispose();
    expect(service.isConnected, isFalse);
  });
}
