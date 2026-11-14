import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:softify/data/services/spotify_api_service.dart';

void main() {
  group('SpotifyApiService Reverse Engineered Pathfinder Tests', () {
    test('Token management fetches anonymous embed token when logged out', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(
            jsonEncode({
              'accessToken': 'test_anon_token_12345',
              'accessTokenExpirationTimestampMs':
                  DateTime.now().millisecondsSinceEpoch + 3600000,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final token = await service.getValidToken();
      expect(token, equals('test_anon_token_12345'));
    });

    test('searchDesktop parses tracks, artists, and albums correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(
            jsonEncode({
              'accessToken': 'test_token',
              'accessTokenExpirationTimestampMs':
                  DateTime.now().millisecondsSinceEpoch + 3600000,
            }),
            200,
          );
        }

        if (request.url.path.contains('/pathfinder/v1/query') &&
            request.url.queryParameters['operationName'] == 'searchDesktop') {
          expect(request.headers['Authorization'], equals('Bearer test_token'));
          return http.Response(
            jsonEncode({
              'data': {
                'searchV2': {
                  'tracksV2': {
                    'items': [
                      {
                        'item': {
                          'data': {
                            'uri': 'spotify:track:56zZ48jdyY2oDXHVnwg5Di',
                            'name': 'Tum Hi Ho',
                            'artists': {
                              'items': [
                                {
                                  'profile': {'name': 'Arijit Singh'}
                                },
                                {
                                  'profile': {'name': 'Mithoon'}
                                }
                              ]
                            },
                            'albumOfTrack': {
                              'name': 'Aashiqui 2',
                              'coverArt': {
                                'sources': [
                                  {
                                    'url':
                                        'https://i.scdn.co/image/ab67616d00001e026404721c1943d5069f0805f3'
                                  }
                                ]
                              }
                            },
                            'trackDuration': {'totalMilliseconds': 261974}
                          }
                        }
                      }
                    ]
                  },
                  'artists': {
                    'items': [
                      {
                        'data': {
                          'uri': 'spotify:artist:4YRxDV8wJFPHPTeXepOstw',
                          'profile': {'name': 'Arijit Singh'},
                          'visuals': {
                            'avatarImage': {
                              'sources': [{'url': 'https://artist.img'}]
                            }
                          }
                        }
                      }
                    ]
                  },
                  'albumsV2': {
                    'items': [
                      {
                        'data': {
                          'uri': 'spotify:album:1QOwvBk3LNWAaEvARxPDNd',
                          'name': 'The Arijit Singh Collection',
                          'artists': {
                            'items': [
                              {
                                'profile': {'name': 'Arijit Singh'}
                              }
                            ]
                          },
                          'coverArt': {
                            'sources': [{'url': 'https://album.img'}]
                          }
                        }
                      }
                    ]
                  },
                  'topResultsV2': {
                    'itemsV2': [
                      {
                        'item': {
                          'data': {'name': 'Tum Hi Ho'}
                        }
                      }
                    ]
                  }
                }
              }
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final res = await service.search('Tum Hi Ho');

      expect(res.tracks.length, equals(1));
      final track = res.tracks.first;
      expect(track.id, equals('spotify_56zZ48jdyY2oDXHVnwg5Di'));
      expect(track.title, equals('Tum Hi Ho'));
      expect(track.artist, equals('Arijit Singh, Mithoon'));
      expect(track.album, equals('Aashiqui 2'));
      expect(track.duration.inMilliseconds, equals(261974));
      expect(track.coverUrl, contains('https://i.scdn.co/image/'));

      expect(res.artists.length, equals(1));
      expect(res.artists.first.name, equals('Arijit Singh'));

      expect(res.albums.length, equals(1));
      expect(res.albums.first.name, equals('The Arijit Singh Collection'));

      expect(res.topResultTitles, contains('Tum Hi Ho'));
    });

    test('searchSuggestions returns real-time autocomplete suggestions', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(
            jsonEncode({'accessToken': 'test_token'}),
            200,
          );
        }

        if (request.url.path.contains('/pathfinder/v1/query') &&
            request.url.queryParameters['operationName'] == 'searchSuggestions') {
          return http.Response(
            jsonEncode({
              'data': {
                'searchV2': {
                  'topResultsV2': {
                    'itemsV2': [
                      {
                        'item': {
                          'data': {'text': 'arijit singh songs'}
                        }
                      },
                      {
                        'item': {
                          'data': {'text': 'arijit singh sad song'}
                        }
                      }
                    ]
                  }
                }
              }
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final suggestions = await service.getSearchSuggestions('arijit');
      expect(suggestions, equals(['arijit singh songs', 'arijit singh sad song']));
    });

    test('internalLinkRecommenderTrack returns algorithmic recommendations', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(
            jsonEncode({'accessToken': 'test_token'}),
            200,
          );
        }

        if (request.url.path.contains('/pathfinder/v1/query') &&
            request.url.queryParameters['operationName'] ==
                'internalLinkRecommenderTrack') {
          return http.Response(
            jsonEncode({
              'data': {
                'seoRecommendedTrack': {
                  'items': [
                    {
                      'data': {
                        'uri': 'spotify:track:1HT0RzPuChHC1kWbIplHyw',
                        'name': 'Teri Meri',
                        'artists': {
                          'items': [
                            {
                              'profile': {'name': 'Rahat Fateh Ali Khan'}
                            },
                            {
                              'profile': {'name': 'Shreya Ghoshal'}
                            }
                          ]
                        },
                        'albumOfTrack': {
                          'coverArt': {
                            'sources': [{'url': 'https://cover.url'}]
                          }
                        },
                        'trackDuration': {'totalMilliseconds': 319000}
                      }
                    }
                  ]
                }
              }
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final recs = await service.getRecommendedTracks('spotify:track:56zZ48jdyY2oDXHVnwg5Di');

      expect(recs.length, equals(1));
      expect(recs.first.title, equals('Teri Meri'));
      expect(recs.first.artist, equals('Rahat Fateh Ali Khan, Shreya Ghoshal'));
      expect(recs.first.id, equals('spotify_1HT0RzPuChHC1kWbIplHyw'));
    });

    test('queryArtistRelated returns related artists', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(jsonEncode({'accessToken': 'test_token'}), 200);
        }

        if (request.url.path.contains('/pathfinder/v1/query') &&
            request.url.queryParameters['operationName'] == 'queryArtistRelated') {
          return http.Response(
            jsonEncode({
              'data': {
                'artistUnion': {
                  'relatedContent': {
                    'relatedArtists': {
                      'items': [
                        {
                          'uri': 'spotify:artist:1wRPtKGflJrBx9BmLsSwlU',
                          'profile': {'name': 'Pritam'}
                        },
                        {
                          'uri': 'spotify:artist:0oOet2f43PA68X5RxKobEy',
                          'profile': {'name': 'Shreya Ghoshal'}
                        }
                      ]
                    }
                  }
                }
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final related = await service.getRelatedArtists('spotify:artist:4YRxDV8wJFPHPTeXepOstw');

      expect(related.length, equals(2));
      expect(related.first.name, equals('Pritam'));
      expect(related.last.name, equals('Shreya Ghoshal'));
    });

    test('queryArtistOverview returns top tracks', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(jsonEncode({'accessToken': 'test_token'}), 200);
        }

        if (request.url.path.contains('/pathfinder/v1/query') &&
            request.url.queryParameters['operationName'] == 'queryArtistOverview') {
          return http.Response(
            jsonEncode({
              'data': {
                'artistUnion': {
                  'discography': {
                    'topTracks': {
                      'items': [
                        {
                          'track': {
                            'uri': 'spotify:track:1hA697u7e1jX2XM8sWA6Uy',
                            'name': 'Apna Bana Le',
                            'artists': {
                              'items': [
                                {
                                  'profile': {'name': 'Arijit Singh'}
                                }
                              ]
                            },
                            'trackDuration': {'totalMilliseconds': 261000}
                          }
                        }
                      ]
                    }
                  }
                }
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final topTracks = await service.getArtistTopTracks('spotify:artist:4YRxDV8wJFPHPTeXepOstw');

      expect(topTracks.length, equals(1));
      expect(topTracks.first.title, equals('Apna Bana Le'));
    });

    test('getTrackRadio resolves dynamic inspiredby playlist and extracts recommendation tracks', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://open.spotify.com/embed/api/token') {
          return http.Response(jsonEncode({'accessToken': 'test_token'}), 200);
        }

        if (request.url.toString().contains('inspiredby-mix/v2/seed_to_playlist/spotify:track:56zZ48jdyY2oDXHVnwg5Di')) {
          return http.Response('  :) \'spotify:playlist:37i9dQZF1E8KSkwN97FGwv', 200);
        }

        if (request.url.toString().contains('open.spotify.com/embed/playlist/37i9dQZF1E8KSkwN97FGwv')) {
          final payload = {
            'props': {
              'pageProps': {
                'state': {
                  'data': {
                    'entity': {
                      'coverArt': {
                        'sources': [{'url': 'https://cover.art/radio.jpg'}]
                      },
                      'trackList': [
                        {
                          'uri': 'spotify:track:1UWacd8x8tPPwmrPB1MoBI',
                          'title': 'Ae Dil Hai Mushkil Title Track',
                          'subtitle': 'Pritam, Arijit Singh',
                          'duration': 269032,
                        },
                        {
                          'uri': 'spotify:track:50tdR4i1B32jD9fTq3lYwM',
                          'title': 'Dil Diyan Gallan',
                          'subtitle': 'Atif Aslam',
                          'duration': 260000,
                        }
                      ]
                    }
                  }
                }
              }
            }
          };
          return http.Response(
            '<html><script id="__NEXT_DATA__" type="application/json">${jsonEncode(payload)}</script></html>',
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = SpotifyApiService(client: mockClient);
      final tracks = await service.getTrackRadio('56zZ48jdyY2oDXHVnwg5Di');

      expect(tracks.length, equals(2));
      expect(tracks.first.title, equals('Ae Dil Hai Mushkil Title Track'));
      expect(tracks.first.artist, equals('Pritam, Arijit Singh'));
      expect(tracks.last.title, equals('Dil Diyan Gallan'));
    });
  });
}
