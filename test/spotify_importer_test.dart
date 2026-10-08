import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:softify/data/importer/keyless_spotify_importer.dart';
import 'package:softify/domain/entities/spotify_import.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/domain/ports/i_catalog_repository.dart';

class MockCatalogRepository implements ICatalogRepository {
  final Map<String, List<Track>> searchMap;

  MockCatalogRepository({this.searchMap = const {}});

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    for (final entry in searchMap.entries) {
      if (query.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return [];
  }

  @override
  Future<List<Track>> getTrendingTracks({int limit = 30}) async => [];

  @override
  Future<List<String>> getSearchSuggestions(String query) async => [];

  @override
  Future<List<Track>> getArtistTracks(String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getAlbumTracks(String album, String artist, {int limit = 25}) async => [];

  @override
  Future<List<Track>> getRelatedTracks(Track track, {int limit = 15}) async => [];
}

void main() {
  group('Milestone 5: Spotify Playlist Importer', () {
    late KeylessSpotifyImporter importer;

    setUp(() {
      importer = KeylessSpotifyImporter();
    });

    test('extractPlaylistId parses all Spotify URL formats correctly', () {
      // Standard web URL with tracking query parameters
      expect(
        importer.extractPlaylistId('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=ab12cd34ef'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Embed URL
      expect(
        importer.extractPlaylistId('https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Spotify desktop URI
      expect(
        importer.extractPlaylistId('spotify:playlist:37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Raw 22-character ID
      expect(
        importer.extractPlaylistId('37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Modern localized Spotify URLs (intl-en, intl-es, intl-hi)
      expect(
        importer.extractPlaylistId('https://open.spotify.com/intl-en/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abcd'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );
      expect(
        importer.extractPlaylistId('https://open.spotify.com/intl-es/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // User playlists
      expect(
        importer.extractPlaylistId('https://open.spotify.com/user/spotify/playlist/37i9dQZF1DXcBWIGoYBM5M'),
        equals('37i9dQZF1DXcBWIGoYBM5M'),
      );

      // Albums and tracks
      expect(
        importer.extractPlaylistId('https://open.spotify.com/album/4m2880jivSbbyEGAKfITCa'),
        equals('4m2880jivSbbyEGAKfITCa'),
      );
      expect(
        importer.extractPlaylistId('spotify:album:4m2880jivSbbyEGAKfITCa'),
        equals('4m2880jivSbbyEGAKfITCa'),
      );
      expect(
        importer.extractPlaylistId('https://open.spotify.com/track/11hcBLPtbMp4aQI6zGQLub'),
        equals('11hcBLPtbMp4aQI6zGQLub'),
      );

      // Invalid links
      expect(importer.extractPlaylistId('https://youtube.com/watch?v=123'), isNull);
      expect(importer.extractPlaylistId('not-a-valid-url'), isNull);
      expect(importer.extractPlaylistId(''), isNull);
    });

    test('matchTrack calculates high confidence for matching catalog tracks', () async {
      final mockCatalog = MockCatalogRepository(
        searchMap: {
          'Blinding Lights': [
            const Track(
              id: 'itunes_123',
              sourceId: 'itunes_123',
              title: 'Blinding Lights',
              artist: 'The Weeknd',
              album: 'After Hours',
              duration: Duration(seconds: 200),
              coverUrl: 'https://example.com/cover.jpg',
              matchConfidence: 1.0,
            ),
          ],
        },
      );

      final matchingImporter = KeylessSpotifyImporter(catalog: mockCatalog);

      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: Duration(seconds: 200),
      );

      final matched = await matchingImporter.matchTrack(spotifyItem);

      expect(matched, isNotNull);
      expect(matched!.title, equals('Blinding Lights'));
      expect(matched.artist, equals('The Weeknd'));
      expect(matched.matchConfidence, greaterThanOrEqualTo(0.85));
    });

    test('matchTrack rejects tracks with confidence below threshold', () async {
      final mockCatalog = MockCatalogRepository(
        searchMap: {
          'Starboy': [
            const Track(
              id: 'yt_abc',
              sourceId: 'abc',
              title: 'Completely Different Song',
              artist: 'Unknown Singer',
              duration: Duration(seconds: 600),
              matchConfidence: 0.1,
            ),
          ],
        },
      );

      final matchingImporter = KeylessSpotifyImporter(catalog: mockCatalog);

      const spotifyItem = SpotifyTrackItem(
        spotifyUri: 'spotify:track:xyz',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: Duration(seconds: 230),
      );

      final matched = await matchingImporter.matchTrack(spotifyItem);

      // Should be rejected because confidence < 0.50
      expect(matched, isNull);
    });

    test('SpotifyImportPlaylist computes match stats accurately', () {
      final tracks = [
        const SpotifyTrackItem(
          spotifyUri: 'uri_1',
          title: 'Track 1',
          artist: 'Artist 1',
          duration: Duration(seconds: 180),
          isMatched: true,
          confidence: 0.95,
        ),
        const SpotifyTrackItem(
          spotifyUri: 'uri_2',
          title: 'Track 2',
          artist: 'Artist 2',
          duration: Duration(seconds: 200),
          isMatched: true,
          confidence: 0.88,
        ),
        const SpotifyTrackItem(
          spotifyUri: 'uri_3',
          title: 'Track 3',
          artist: 'Artist 3',
          duration: Duration(seconds: 220),
          isMatched: false,
          confidence: 0.0,
        ),
      ];

      final playlist = SpotifyImportPlaylist(
        id: 'test_playlist_1',
        name: 'My Spotify Favorites',
        description: 'Test Description',
        tracks: tracks,
      );

      expect(playlist.totalCount, equals(3));
      expect(playlist.matchedCount, equals(2));
      expect(playlist.matchPercentage, closeTo(66.66, 0.1));
    });
  });

  group('Spotify playlist pagination (>100 tracks)', () {
    const playlistId = '46RepFWgIsxxxGNQqD5ymx';

    String embedHtml({required int embedTrackCount}) {
      final trackList = List.generate(
        embedTrackCount,
        (i) => {
          'uri': 'spotify:track:embed$i',
          'title': 'Embed Track $i',
          'subtitle': 'Embed Artist $i',
          'duration': (i + 1) * 1000,
        },
      );
      final data = {
        'props': {
          'pageProps': {
            'state': {
              'data': {
                'entity': {
                  'name': 'Big Playlist',
                  'subtitle': 'Curator',
                  'coverArt': {
                    'sources': [
                      {'url': 'https://i.scdn.co/image/playlist-cover'}
                    ]
                  },
                  'trackList': trackList,
                }
              }
            }
          }
        }
      };
      return '<html><head></head><body>'
          '<script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script>'
          '</body></html>';
    }

    String tokenJson({int expiresInMs = 3600000}) => jsonEncode({
          'accessToken': 'test-token',
          'accessTokenExpirationTimestampMs':
              DateTime.now().millisecondsSinceEpoch + expiresInMs,
          'isAnonymous': true,
        });

    Map<String, dynamic> apiItem(int i) => {
          'track': {
            'uri': 'spotify:track:api$i',
            'name': 'Api Track $i',
            'duration_ms': (i + 1) * 1000,
            'artists': [
              {'name': 'ArtistA$i'},
              {'name': 'ArtistB$i'},
            ],
            'album': {
              'images': [
                {'url': 'https://i.scdn.co/image/album$i'}
              ]
            },
          }
        };

    Map<String, dynamic> page(List<int> indices, {required bool hasNext, required int total}) => {
          'items': indices.map(apiItem).toList(),
          'limit': 100,
          'next': hasNext ? 'https://api.spotify.com/v1/playlists/$playlistId/tracks?offset=100' : null,
          'offset': indices.isEmpty ? 0 : indices.first,
          'total': total,
        };

    http.Response jsonResponse(Object body, int status) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

    test('pages past the embed 100-track cap and returns the full list', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 100), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
          if (offset == 0) {
            return jsonResponse(page(List.generate(100, (i) => i), hasNext: true, total: 111), 200);
          }
          return jsonResponse(
              page(List.generate(11, (i) => 100 + i), hasNext: false, total: 111), 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist('https://open.spotify.com/playlist/$playlistId');

      expect(playlist.name, equals('Big Playlist'));
      expect(playlist.tracks.length, equals(111));

      // API data replaces the truncated embed list.
      expect(playlist.tracks.first.spotifyUri, equals('spotify:track:api0'));
      expect(playlist.tracks.first.title, equals('Api Track 0'));
      expect(playlist.tracks.first.artist, equals('ArtistA0, ArtistB0'));
      expect(playlist.tracks.first.coverUrl, equals('https://i.scdn.co/image/album0'));

      expect(playlist.tracks.last.spotifyUri, equals('spotify:track:api110'));
      expect(playlist.tracks.last.duration, equals(const Duration(seconds: 111)));
    });

    test('falls back to embed tracks when the API reports 404 (editorial lists)', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 100), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        return http.Response(
            jsonEncode({'error': {'status': 404, 'message': 'Resource not found'}}), 404,
            headers: {'content-type': 'application/json'});
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(playlistId);

      expect(playlist.tracks.length, equals(100));
      expect(playlist.tracks.first.title, equals('Embed Track 0'));
      expect(playlist.tracks.first.coverUrl, equals('https://i.scdn.co/image/playlist-cover'));
    });

    test('retries with backoff when Spotify returns 429', () async {
      var trackCalls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 2), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          trackCalls++;
          if (trackCalls == 1) {
            return jsonResponse({'error': {'status': 429, 'reason': 'QUOTA_EXCEEDED'}}, 429);
          }
          return jsonResponse(page([0], hasNext: false, total: 1), 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(playlistId);

      expect(trackCalls, equals(2));
      expect(playlist.tracks.length, equals(1));
      expect(playlist.tracks.first.title, equals('Api Track 0'));
    });

    test('never sleeps on a multi-hour Retry-After and falls back immediately', () async {
      var trackCalls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 100), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          trackCalls++;
          return http.Response(
            jsonEncode({'error': {'status': 429, 'reason': 'QUOTA_EXCEEDED'}}),
            429,
            headers: {'content-type': 'application/json', 'retry-after': '71777'},
          );
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final stopwatch = Stopwatch()..start();
      final playlist = await importer.fetchPlaylist(playlistId);
      stopwatch.stop();

      expect(trackCalls, equals(1));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      expect(playlist.tracks.length, equals(100));
      expect(playlist.notice, isNotNull);
      expect(playlist.notice, contains('quota'));
    });

    test('reports page-by-page progress while paging the Web API', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 100), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
          if (offset == 0) {
            return jsonResponse(page(List.generate(100, (i) => i), hasNext: true, total: 111), 200);
          }
          return jsonResponse(
              page(List.generate(11, (i) => 100 + i), hasNext: false, total: 111), 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final progress = <int>[];
      final playlist =
          await importer.fetchPlaylist(playlistId, onProgress: progress.add);

      expect(playlist.tracks.length, equals(111));
      expect(progress, equals([100, 111]));
    });

    test('refreshes the session token once on 401 and continues paging', () async {
      var tokenCalls = 0;
      var trackCalls = 0;
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          tokenCalls++;
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 1), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          trackCalls++;
          final auth = request.headers['authorization'] ?? '';
          if (trackCalls == 1 && tokenCalls == 1) {
            return http.Response('', 401);
          }
          expect(auth, equals('Bearer test-token'));
          return jsonResponse(page([0], hasNext: false, total: 1), 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(playlistId);

      expect(tokenCalls, equals(2));
      expect(playlist.tracks.length, equals(1));
    });

    test('skips unavailable (null) tracks returned by the API', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/api/token')) {
          return jsonResponse(jsonDecode(tokenJson()), 200);
        }
        if (url.contains('/embed/playlist/')) {
          return http.Response(embedHtml(embedTrackCount: 1), 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        }
        if (url.contains('/tracks')) {
          return jsonResponse({
            'items': [
              {'track': null},
              apiItem(1),
            ],
            'next': null,
            'total': 2,
          }, 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(playlistId);

      expect(playlist.tracks.length, equals(1));
      expect(playlist.tracks.first.spotifyUri, equals('spotify:track:api1'));
    });

    test('imports Spotify album cleanly as a playlist without API limits', () async {
      final client = MockClient((request) async {
        if (request.url.toString().contains('/embed/album/4m2880jivSbbyEGAKfITCa')) {
          final data = {
            'props': {
              'pageProps': {
                'state': {
                  'data': {
                    'entity': {
                      'name': 'Random Access Memories',
                      'subtitle': 'Daft Punk',
                      'visualIdentity': {
                        'image': [
                          {'url': 'https://i.scdn.co/image/ram-cover'}
                        ]
                      },
                      'trackList': [
                        {
                          'uri': 'spotify:track:ram1',
                          'title': 'Give Life Back to Music',
                          'subtitle': 'Daft Punk',
                          'duration': 275000,
                        },
                        {
                          'uri': 'spotify:track:ram2',
                          'title': 'Get Lucky',
                          'subtitle': 'Daft Punk',
                          'duration': 369000,
                        },
                      ],
                    }
                  }
                }
              }
            }
          };
          return http.Response(
            '<html><body><script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(
        'https://open.spotify.com/intl-en/album/4m2880jivSbbyEGAKfITCa?si=xyz',
      );

      expect(playlist.name, equals('Random Access Memories (Album)'));
      expect(playlist.description, contains('Daft Punk'));
      expect(playlist.tracks.length, equals(2));
      expect(playlist.tracks.first.title, equals('Give Life Back to Music'));
      expect(playlist.tracks.last.title, equals('Get Lucky'));
    });

    test('imports single Spotify track link cleanly as a 1-track import', () async {
      final client = MockClient((request) async {
        if (request.url.toString().contains('/embed/track/11hcBLPtbMp4aQI6zGQLub')) {
          final data = {
            'props': {
              'pageProps': {
                'state': {
                  'data': {
                    'entity': {
                      'name': 'Patient Zero',
                      'artists': [{'name': 'Taylor Swift'}],
                      'duration': 225000,
                      'visualIdentity': [
                        {'url': 'https://i.scdn.co/image/track-cover'}
                      ],
                      'uri': 'spotify:track:11hcBLPtbMp4aQI6zGQLub',
                    }
                  }
                }
              }
            }
          };
          return http.Response(
            '<html><body><script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final playlist = await importer.fetchPlaylist(
        'https://open.spotify.com/track/11hcBLPtbMp4aQI6zGQLub',
      );

      expect(playlist.name, equals('Patient Zero'));
      expect(playlist.tracks.length, equals(1));
      expect(playlist.tracks.first.title, equals('Patient Zero'));
      expect(playlist.tracks.first.artist, equals('Taylor Swift'));
    });

    test('paginates large playlists (>100 tracks) seamlessly using Spotify Pathfinder GraphQL', () async {
      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('/embed/playlist/')) {
          final data = {
            'props': {
              'pageProps': {
                'state': {
                  'settings': {
                    'session': {
                      'accessToken': 'mock-pathfinder-token',
                      'accessTokenExpirationTimestampMs':
                          DateTime.now().millisecondsSinceEpoch + 3600000,
                    }
                  },
                  'data': {
                    'entity': {
                      'name': 'Massive 150 Track Playlist',
                      'subtitle': 'Curator',
                      'coverArt': {
                        'sources': [
                          {'url': 'https://i.scdn.co/image/playlist-cover'}
                        ]
                      },
                      'trackList': List.generate(
                        100,
                        (i) => {
                          'uri': 'spotify:track:embed$i',
                          'title': 'Embed Track $i',
                          'subtitle': 'Embed Artist $i',
                          'duration': (i + 1) * 1000,
                        },
                      ),
                    }
                  }
                }
              }
            }
          };
          return http.Response(
            '<html><body><script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></body></html>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        if (url.contains('/pathfinder/v1/query')) {
          final rawVariables = request.url.queryParameters['variables'] ?? '{}';
          final vars = jsonDecode(rawVariables) as Map<String, dynamic>;
          final offset = vars['offset'] as int? ?? 0;

          final itemsCount = offset == 0 ? 100 : (offset == 100 ? 50 : 0);
          final items = List.generate(itemsCount, (i) {
            final idx = offset + i;
            return {
              'itemV2': {
                'data': {
                  '__typename': 'Track',
                  'name': 'Pathfinder Song $idx',
                  'uri': 'spotify:track:pf$idx',
                  'trackDuration': {'totalMilliseconds': 210000 + idx},
                  'artists': {
                    'items': [
                      {
                        'profile': {'name': 'Artist $idx'}
                      }
                    ]
                  },
                  'albumOfTrack': {
                    'coverArt': {
                      'sources': [
                        {'url': 'https://i.scdn.co/image/pf-cover-$idx'}
                      ]
                    }
                  }
                }
              }
            };
          });

          final responseData = {
            'data': {
              'playlistV2': {
                'content': {
                  'totalCount': 150,
                  'items': items,
                }
              }
            }
          };
          return jsonResponse(responseData, 200);
        }
        return http.Response('not found', 404);
      });

      final importer = KeylessSpotifyImporter(client: client);
      final progress = <int>[];
      final playlist = await importer.fetchPlaylist(
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
        onProgress: progress.add,
      );

      expect(playlist.name, equals('Massive 150 Track Playlist'));
      expect(playlist.tracks.length, equals(150));
      expect(playlist.tracks.first.title, equals('Pathfinder Song 0'));
      expect(playlist.tracks.first.artist, equals('Artist 0'));
      expect(playlist.tracks[99].title, equals('Pathfinder Song 99'));
      expect(playlist.tracks[149].title, equals('Pathfinder Song 149'));
      expect(playlist.tracks[149].artist, equals('Artist 149'));
      expect(progress, equals([100, 150]));
    });
  });
}
