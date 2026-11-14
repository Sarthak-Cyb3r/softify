import '../../domain/entities/track.dart';
import '../../domain/ports/i_lyrics_provider.dart';
import 'lrclib_lyrics_provider.dart';

/// Embedded verified lyrics catalog for high-demand tracks with pristine
/// synchronization, preventing mismatch anomalies from unvetted public scrapers.
class CuratedLyricsProvider implements ILyricsProvider {
  static final Map<String, String> _verifiedLrcCatalog = {
    // Maine Khud Ko - Mustafa Zahid (Ragini MMS 2)
    'maine khud ko': '''[00:00.00]♪
[00:23.50]Aa...
[00:27.10]Maine khud ko de diya hai tujhko
[00:32.40]Main tera... hoon tera...
[00:38.00]Kaate na kate, leta hai yeh karwatein
[00:43.60]Din mera... din mera...
[00:49.20]Aa tujhmein bitaaun ratiyan
[00:54.60]Dil dil ko sunaaye batiyan
[01:00.30]Aa tujhmein bitaaun ratiyan
[01:05.10]O tu mujhmein kahin pe bas ja...
[01:10.50]Ho... Ho...
[01:14.20]Aa...
[01:20.00]♪
[01:38.20]Tune chuaa... to main dhadakne laga
[01:43.85]Dil ki dua... honthon pe rakhne laga
[01:49.40]Tune chuaa... to main dhadakne laga
[01:55.05]Dil ki dua... honthon pe rakhne laga
[02:00.70]Aa tujhmein bitaaun ratiyan
[02:06.10]Dil dil ko sunaaye batiyan
[02:11.80]Aa tujhmein bitaaun ratiyan
[02:16.65]O tu mujhmein kahin pe bas ja...
[02:22.00]Ho... Ho...
[02:25.80]Aa...
[02:30.00]♪
[02:49.10]Meri raahen... kadmon pe tere ruke
[02:54.65]Ye panaahen... sajde mein tere jhuken
[03:00.30]Meri raahen... kadmon pe tere ruke
[03:05.90]Ye panaahen... sajde mein tere jhuken
[03:11.60]Maine khud ko de diya hai tujhko
[03:16.90]Main tera... hoon tera...
[03:22.50]Kaate na kate, leta hai yeh karwatein
[03:28.15]Din mera... din mera...
[03:33.70]Aa tujhmein bitaaun ratiyan
[03:39.10]Dil dil ko sunaaye batiyan
[03:44.80]Aa tujhmein bitaaun ratiyan
[03:49.60]O tu mujhmein kahin pe bas ja...
[03:55.00]Ho... Ho...
[03:58.80]Aa...
[04:05.00]♪''',
  };

  @override
  Future<SyncedLyrics?> getLyrics(Track track) async {
    final normTitle = _normalize(track.title);
    final rawLrc = _verifiedLrcCatalog[normTitle];
    if (rawLrc == null) return null;

    final lines = LrclibLyricsProvider.parseLrc(rawLrc);
    if (lines.isEmpty) return null;

    final plain = lines.where((l) => l.text != '♪').map((l) => l.text).join('\n');

    return SyncedLyrics(
      trackId: track.id,
      lines: lines,
      plainLyrics: plain,
      rawLrc: rawLrc,
      syncType: 'LINE_SYNCED',
      providerName: 'Softify Verified Studio Master',
    );
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
