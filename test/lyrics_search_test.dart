import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:softify/data/search/linear_search_reranker.dart';
import 'package:softify/data/services/spotify_api_service.dart';
import 'package:softify/domain/entities/search_candidate.dart';
import 'package:softify/domain/entities/track.dart';
import 'package:softify/presentation/providers/search_providers.dart';
import 'package:softify/presentation/theme/app_theme.dart';
import 'package:softify/presentation/widgets/shared/track_row.dart';

void main() {
  group('Lyrics Search Engine - Comprehensive Edge Case Suite', () {
    // -------------------------------------------------------------------------
    // 1. DOMAIN & ENTITY SERIALIZATION EDGE CASES
    // -------------------------------------------------------------------------
    group('Track Entity & Serialization Edge Cases', () {
      test('Serializes and deserializes isLyricsMatch and matchedLyricSnippet accurately', () {
        const track = Track(
          id: 'spotify_bohemian_rhapsody',
          sourceId: 'spotify_bohemian_rhapsody',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night At The Opera',
          duration: Duration(seconds: 355),
          isLyricsMatch: true,
          matchedLyricSnippet: 'Is this the real life? Is this just fantasy?',
        );

        final map = track.toMap();
        expect(map['is_lyrics_match'], isTrue);
        expect(map['matched_lyric_snippet'], 'Is this the real life? Is this just fantasy?');

        final reconstructed = Track.fromMap(map);
        expect(reconstructed.isLyricsMatch, isTrue);
        expect(reconstructed.matchedLyricSnippet, 'Is this the real life? Is this just fantasy?');
      });

      test('Backward compatibility: Legacy map lacking is_lyrics_match safely defaults to false', () {
        final legacyMap = {
          'id': 'legacy_track_1',
          'source_id': 'legacy_track_1',
          'title': 'Yesterday',
          'artist': 'The Beatles',
          'duration_ms': 125000,
        };

        final track = Track.fromMap(legacyMap);
        expect(track.isLyricsMatch, isFalse);
        expect(track.matchedLyricSnippet, isNull);
      });

      test('Tolerates explicit null values in map without crashing', () {
        final nullFieldsMap = {
          'id': 'null_track_1',
          'source_id': 'null_track_1',
          'title': 'Imagine',
          'artist': 'John Lennon',
          'duration_ms': 180000,
          'is_lyrics_match': null,
          'matched_lyric_snippet': null,
        };

        final track = Track.fromMap(nullFieldsMap);
        expect(track.isLyricsMatch, isFalse);
        expect(track.matchedLyricSnippet, isNull);
      });

      test('copyWith correctly maintains or overrides isLyricsMatch and matchedLyricSnippet', () {
        const baseTrack = Track(
          id: 't_1',
          sourceId: 't_1',
          title: 'Test Song',
          artist: 'Test Artist',
          duration: Duration(seconds: 200),
          isLyricsMatch: false,
        );

        final upgraded = baseTrack.copyWith(
          isLyricsMatch: true,
          matchedLyricSnippet: 'matched line',
        );
        expect(upgraded.isLyricsMatch, isTrue);
        expect(upgraded.matchedLyricSnippet, 'matched line');

        final reverted = upgraded.copyWith(isLyricsMatch: false);
        expect(reverted.isLyricsMatch, isFalse);
        expect(reverted.matchedLyricSnippet, 'matched line');
      });
    });

    // -------------------------------------------------------------------------
    // 2. SPOTIFY PATHFINDER GRAPHQL SEARCH EDGE CASES (MOCKCLIENT)
    // -------------------------------------------------------------------------
    group('SpotifyApiService Pathfinder Search Edge Cases', () {
      http.Client createMockSpotifyClient(Map<String, dynamic> searchV2Payload) {
        return MockClient((request) async {
          if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
            return http.Response(
              jsonEncode({
                'accessToken': 'test_token',
                'accessTokenExpirationTimestampMs':
                    DateTime.now().millisecondsSinceEpoch + 3600000,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.contains('/pathfinder/v1/query') &&
              request.url.queryParameters['operationName'] == 'searchDesktop') {
            return http.Response(
              jsonEncode({'data': {'searchV2': searchV2Payload}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not Found', 404);
        });
      }

      test('Pure lyrics match: matchedFields=["LYRICS"] sets isLyricsMatch=true', () async {
        final client = createMockSpotifyClient({
          'tracksV2': {
            'items': [
              {
                'matchedFields': ['LYRICS'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:2JiDi0qAXsPwhPqA2qaKGt',
                    'name': 'Bohemian Rhapsody',
                    'duration': {'totalMilliseconds': 355000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('is this the real life is this just fantasy');

        expect(result.tracks.length, 1);
        expect(result.tracks.first.title, 'Bohemian Rhapsody');
        expect(result.tracks.first.artist, 'Queen');
        expect(result.tracks.first.isLyricsMatch, isTrue);
      });

      test('Name match: matchedFields=["NAME"] sets isLyricsMatch=false', () async {
        final client = createMockSpotifyClient({
          'tracksV2': {
            'items': [
              {
                'matchedFields': ['NAME'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:111',
                    'name': 'Bohemian Rhapsody',
                    'duration': {'totalMilliseconds': 355000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('Bohemian Rhapsody');

        expect(result.tracks.first.isLyricsMatch, isFalse);
      });

      test('Dual match: matchedFields=["LYRICS", "NAME"] sets isLyricsMatch=false', () async {
        // When both name and lyrics match, title matching dominates; not a pure lyrics match
        final client = createMockSpotifyClient({
          'tracksV2': {
            'items': [
              {
                'matchedFields': ['LYRICS', 'NAME'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:111',
                    'name': 'Radio Ga Ga',
                    'duration': {'totalMilliseconds': 340000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('Radio Ga Ga');

        expect(result.tracks.first.isLyricsMatch, isFalse);
      });

      test('Case insensitivity: matchedFields=["lyrics"] (lowercase) is parsed as isLyricsMatch=true', () async {
        final client = createMockSpotifyClient({
          'tracksV2': {
            'items': [
              {
                'matchedFields': ['lyrics'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:123',
                    'name': 'Humdard',
                    'duration': {'totalMilliseconds': 260000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Arijit Singh'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('pal do pal ka shayar');

        expect(result.tracks.first.isLyricsMatch, isTrue);
      });

      test('Missing matchedFields or null matchedFields safely evaluates to isLyricsMatch=false', () async {
        final client = createMockSpotifyClient({
          'tracksV2': {
            'items': [
              {
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:999',
                    'name': 'Test Title',
                    'duration': {'totalMilliseconds': 120000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Artist'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('test');

        expect(result.tracks.first.isLyricsMatch, isFalse);
      });

      test('Top result track with lyrics match is prioritized at index 0 without duplication', () async {
        final client = createMockSpotifyClient({
          'topResultsV2': {
            'itemsV2': [
              {
                'matchedFields': ['LYRICS'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:queen_top',
                    'name': 'Bohemian Rhapsody',
                    'duration': {'totalMilliseconds': 355000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          },
          'tracksV2': {
            'items': [
              {
                'matchedFields': [],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:other_track',
                    'name': 'Other Song',
                    'duration': {'totalMilliseconds': 200000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Other Artist'}
                        }
                      ]
                    }
                  }
                }
              },
              {
                'matchedFields': ['LYRICS'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:queen_top',
                    'name': 'Bohemian Rhapsody',
                    'duration': {'totalMilliseconds': 355000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('is this the real life is this just fantasy');

        // Bohemian Rhapsody must be promoted to index 0, and total count must be 2 (no duplicates)
        expect(result.tracks.length, 2);
        expect(result.tracks.first.id, 'spotify_queen_top');
        expect(result.tracks.first.isLyricsMatch, isTrue);
      });

      test('Non-track items in topResultsV2 (Artist, Playlist) are ignored as top tracks', () async {
        final client = createMockSpotifyClient({
          'topResultsV2': {
            'itemsV2': [
              {
                'matchedFields': [],
                'item': {
                  'data': {
                    '__typename': 'Artist',
                    'uri': 'spotify:artist:artist1',
                    'profile': {'name': 'Queen'}
                  }
                }
              }
            ]
          },
          'tracksV2': {
            'items': [
              {
                'matchedFields': ['LYRICS'],
                'item': {
                  'data': {
                    '__typename': 'Track',
                    'uri': 'spotify:track:track1',
                    'name': 'Bohemian Rhapsody',
                    'duration': {'totalMilliseconds': 355000},
                    'artists': {
                      'items': [
                        {
                          'profile': {'name': 'Queen'}
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        });

        final service = SpotifyApiService(client: client);
        final result = await service.search('is this the real life');

        expect(result.tracks.length, 1);
        expect(result.tracks.first.id, 'spotify_track1');
        expect(result.topResultTitles, contains('Queen'));
      });

      test('Empty or whitespace query returns empty SpotifySearchResult immediately without network call', () async {
        final client = MockClient((_) async => throw Exception('Should not be called'));
        final service = SpotifyApiService(client: client);

        final res1 = await service.search('');
        expect(res1.tracks, isEmpty);

        final res2 = await service.search('   \t\n  ');
        expect(res2.tracks, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // 3. SCORING & RERANKING EDGE CASES
    // -------------------------------------------------------------------------
    group('Scoring and Reranker Edge Cases', () {
      final reranker = LinearSearchReranker();

      test('Exact title query dominates over competing lyrics match for another song', () {
        // User searches for exact title "Bohemian Rhapsody"
        const query = 'Bohemian Rhapsody';

        const exactTitleTrack = Track(
          id: 'spotify_exact',
          sourceId: 'spotify_exact',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: Duration(seconds: 355),
          isLyricsMatch: false,
        );

        const competingLyricsTrack = Track(
          id: 'spotify_competing',
          sourceId: 'spotify_competing',
          title: 'Song Mentioning Bohemian Rhapsody in Lyrics',
          artist: 'Some Artist',
          duration: Duration(seconds: 240),
          isLyricsMatch: true,
        );

        final results = reranker.rerank(
          query: query,
          candidates: [
            SearchCandidate(track: competingLyricsTrack, source: 'network', features: {}),
            SearchCandidate(track: exactTitleTrack, source: 'network', features: {}),
          ],
        );

        expect(results.first.track.id, 'spotify_exact',
            reason: 'Exact title matches must always retain strict top priority over lyrics matches');
      });

      test('Special characters, punctuation, and emojis in lyric query handled deterministically', () {
        const query = '??? Is this the real life??? 👑🎶';

        const lyricsMatchTrack = Track(
          id: 'spotify_queen',
          sourceId: 'spotify_queen',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: Duration(seconds: 355),
          isLyricsMatch: true,
        );

        const randomTrack = Track(
          id: 'spotify_random',
          sourceId: 'spotify_random',
          title: 'Something Else',
          artist: 'Another Artist',
          duration: Duration(seconds: 180),
          isLyricsMatch: false,
        );

        final results = reranker.rerank(
          query: query,
          candidates: [
            SearchCandidate(track: randomTrack, source: 'network', features: {}),
            SearchCandidate(track: lyricsMatchTrack, source: 'network', features: {}),
          ],
        );

        expect(results.first.track.id, 'spotify_queen');
        expect(results.first.track.isLyricsMatch, isTrue);
      });

      test('Deduplication retains isLyricsMatch=true when first candidate has isLyricsMatch=false', () {
        // Cluster: duplicate tracks of the same song where the first has false and second has true
        const trackA = Track(
          id: 'saavn_same_song',
          sourceId: 'saavn_same_song',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh',
          album: 'Aashiqui 2',
          duration: Duration(seconds: 262),
          isLyricsMatch: false,
        );

        const trackB = Track(
          id: 'spotify_same_song',
          sourceId: 'spotify_same_song',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh',
          album: 'Aashiqui 2',
          duration: Duration(seconds: 262),
          isLyricsMatch: true,
          matchedLyricSnippet: 'Kyunki tum hi ho',
        );

        final results = reranker.rerank(
          query: 'kyunki tum hi ho ab tum hi ho',
          candidates: [
            SearchCandidate(track: trackA, source: 'local_fts', features: {'is_exact': 0.0}),
            SearchCandidate(track: trackB, source: 'network', features: {'is_exact': 0.0}),
          ],
          deduplicate: true,
        );

        expect(results.length, 1);
        expect(results.first.track.isLyricsMatch, isTrue,
            reason: 'Deduplicated cluster must adopt isLyricsMatch=true from network candidate');
      });

      test('Empty candidate list returns empty list safely without exception', () {
        final results = reranker.rerank(query: 'any query', candidates: []);
        expect(results, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // 4. SEARCHSTATE COMBINED RESULTS MERGE EDGE CASES
    // -------------------------------------------------------------------------
    group('SearchState.combinedResults Merge Edge Cases', () {
      test('Local track with same ID is upgraded to isLyricsMatch=true when network finds it via lyrics', () {
        const localTrack = Track(
          id: 'track_123',
          sourceId: 'track_123',
          title: 'Tujhe Kitna Chahne Lage',
          artist: 'Arijit Singh',
          duration: Duration(seconds: 284),
          isLyricsMatch: false,
        );

        const networkTrack = Track(
          id: 'track_123',
          sourceId: 'track_123',
          title: 'Tujhe Kitna Chahne Lage',
          artist: 'Arijit Singh',
          duration: Duration(seconds: 284),
          isLyricsMatch: true,
          matchedLyricSnippet: 'tere bin ab na lenge ek bhi dum',
        );

        const state = SearchState(
          query: 'tere bin ab na lenge ek bhi dum',
          localResults: [localTrack],
          networkResults: [networkTrack],
        );

        final combined = state.combinedResults;
        expect(combined.length, 1);
        expect(combined.first.isLyricsMatch, isTrue);
        expect(combined.first.matchedLyricSnippet, 'tere bin ab na lenge ek bhi dum');
      });

      test('Local track clustered with different ID is upgraded to isLyricsMatch=true from network counterpart', () {
        const localTrack = Track(
          id: 'local_tujhe_kitna',
          sourceId: 'local_tujhe_kitna',
          title: 'Tujhe Kitna Chahne Lage',
          artist: 'Arijit Singh',
          album: 'Kabir Singh',
          duration: Duration(seconds: 284),
          isLyricsMatch: false,
        );

        const networkTrack = Track(
          id: 'spotify_tujhe_kitna',
          sourceId: 'spotify_tujhe_kitna',
          title: 'Tujhe Kitna Chahne Lage (From "Kabir Singh")',
          artist: 'Arijit Singh, Mithoon',
          album: 'Kabir Singh',
          duration: Duration(seconds: 284),
          isLyricsMatch: true,
        );

        const state = SearchState(
          query: 'tere bin ab na lenge ek bhi dum',
          localResults: [localTrack],
          networkResults: [networkTrack],
        );

        final combined = state.combinedResults;
        expect(combined.length, 1);
        expect(combined.first.isLyricsMatch, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 5. WIDGET RENDERING & LAYOUT OVERFLOW EDGE CASES
    // -------------------------------------------------------------------------
    group('UI Rendering & Layout Overflow Edge Cases', () {
      testWidgets('TrackRow renders without overflow in narrow 320px screen with long metadata', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const trackLongMetadata = Track(
          id: 'spotify_long',
          sourceId: 'spotify_long',
          title: 'Supercalifragilisticexpialidocious Ultra Remastered Deluxe 50th Anniversary Edition',
          artist: 'An Exceptionally Long Artist Name Featuring Multiple Other Artists and Producers',
          duration: Duration(seconds: 400),
          isLyricsMatch: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SizedBox(
                width: 320,
                child: TrackRow(
                  track: trackLongMetadata,
                  showArtwork: true,
                  showDuration: true,
                  showLikeButton: true,
                  showOptionsButton: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Lyrics match'), findsOneWidget);
        expect(find.byIcon(Icons.lyrics_outlined), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow under narrow mobile constraint');
      });

      testWidgets('TrackRow renders seamlessly in both Glass and Standard theme tokens', (tester) async {
        const track = Track(
          id: 'spotify_theme_test',
          sourceId: 'spotify_theme_test',
          title: 'A Night At The Opera',
          artist: 'Queen',
          duration: Duration(seconds: 300),
          isLyricsMatch: true,
        );

        // Standard Theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: TrackRow(track: track, showArtwork: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lyrics match'), findsOneWidget);

        // Glass Theme
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.auroraDarkTheme,
            home: const Scaffold(
              body: TrackRow(track: track, showArtwork: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lyrics match'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('All TrackRow interactive callbacks invoke reliably with isLyricsMatch=true', (tester) async {
        bool tapped = false;
        bool likeTapped = false;
        bool optionsTapped = false;

        const track = Track(
          id: 'interactive_track',
          sourceId: 'interactive_track',
          title: 'Interaction Test',
          artist: 'Queen',
          duration: Duration(seconds: 150),
          isLyricsMatch: true,
          isLiked: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: TrackRow(
                track: track,
                showLikeButton: true,
                showOptionsButton: true,
                onTap: () => tapped = true,
                onLikeTap: () => likeTapped = true,
                onOptionsTap: () => optionsTapped = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap Row
        await tester.tap(find.text('Interaction Test'));
        expect(tapped, isTrue);

        // Tap Like
        await tester.tap(find.byTooltip('Unlike'));
        expect(likeTapped, isTrue);

        // Tap Options
        await tester.tap(find.byTooltip('More options'));
        expect(optionsTapped, isTrue);
      });

      testWidgets('Top Result card renders Lyrics match pill alongside Song tag without overflow', (tester) async {
        const topTrack = Track(
          id: 'top_1',
          sourceId: 'top_1',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: Duration(seconds: 355),
          isLyricsMatch: true,
        );

        const tokens = AppTokens.standardTokens;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 76, height: 76),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOP RESULT',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontUi,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                topTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontPageTitle,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      topTrack.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontUi,
                                        fontSize: 12,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceElevated,
                                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                                    ),
                                    child: Text(
                                      'Song',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontUi,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (topTrack.isLyricsMatch) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: tokens.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lyrics_outlined,
                                            size: 11,
                                            color: tokens.accent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Lyrics match',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontUi,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('TOP RESULT'), findsOneWidget);
        expect(find.text('Bohemian Rhapsody'), findsOneWidget);
        expect(find.text('Song'), findsOneWidget);
        expect(find.text('Lyrics match'), findsOneWidget);
        expect(find.byIcon(Icons.lyrics_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
