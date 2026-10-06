class TestCorpusTrack {
  final String query;
  final String expectedTitleKeyword;
  final String expectedArtistKeyword;
  final String category;
  final bool isLongTrack;

  const TestCorpusTrack({
    required this.query,
    required this.expectedTitleKeyword,
    required this.expectedArtistKeyword,
    required this.category,
    this.isLongTrack = false,
  });
}

class Milestone0TestCorpus {
  static const List<TestCorpusTrack> tracks = [
    // 1-5: Global Hits
    TestCorpusTrack(
      query: 'The Weeknd Blinding Lights',
      expectedTitleKeyword: 'Blinding Lights',
      expectedArtistKeyword: 'The Weeknd',
      category: 'Pop Hits',
    ),
    TestCorpusTrack(
      query: 'Dua Lipa Levitating',
      expectedTitleKeyword: 'Levitating',
      expectedArtistKeyword: 'Dua Lipa',
      category: 'Pop Hits',
    ),
    TestCorpusTrack(
      query: 'Ed Sheeran Shape of You',
      expectedTitleKeyword: 'Shape of You',
      expectedArtistKeyword: 'Ed Sheeran',
      category: 'Pop Hits',
    ),
    TestCorpusTrack(
      query: 'Harry Styles As It Was',
      expectedTitleKeyword: 'As It Was',
      expectedArtistKeyword: 'Harry Styles',
      category: 'Pop Hits',
    ),
    TestCorpusTrack(
      query: 'The Kid LAROI Justin Bieber STAY',
      expectedTitleKeyword: 'STAY',
      expectedArtistKeyword: 'Justin Bieber',
      category: 'Pop Hits',
    ),

    // 6-9: Indie & Alternative
    TestCorpusTrack(
      query: 'Beach House Space Song',
      expectedTitleKeyword: 'Space Song',
      expectedArtistKeyword: 'Beach House',
      category: 'Indie / Alternative',
    ),
    TestCorpusTrack(
      query: 'alt-J Breezeblocks',
      expectedTitleKeyword: 'Breezeblocks',
      expectedArtistKeyword: 'alt-J',
      category: 'Indie / Alternative',
    ),
    TestCorpusTrack(
      query: 'The Neighbourhood Sweater Weather',
      expectedTitleKeyword: 'Sweater Weather',
      expectedArtistKeyword: 'Neighbourhood',
      category: 'Indie / Alternative',
    ),
    TestCorpusTrack(
      query: 'Phoebe Bridgers Motion Sickness',
      expectedTitleKeyword: 'Motion Sickness',
      expectedArtistKeyword: 'Phoebe Bridgers',
      category: 'Indie / Alternative',
    ),

    // 10-13: Classical & Instrumental
    TestCorpusTrack(
      query: 'Claude Debussy Clair de Lune',
      expectedTitleKeyword: 'Clair de Lune',
      expectedArtistKeyword: 'Debussy',
      category: 'Classical',
    ),
    TestCorpusTrack(
      query: 'Erik Satie Gymnopedie No. 1',
      expectedTitleKeyword: 'Gymnopédie',
      expectedArtistKeyword: 'Satie',
      category: 'Classical',
    ),
    TestCorpusTrack(
      query: 'Vivaldi Four Seasons Spring',
      expectedTitleKeyword: 'Spring',
      expectedArtistKeyword: 'Vivaldi',
      category: 'Classical',
    ),
    TestCorpusTrack(
      query: 'Ludovico Einaudi Nuvole Bianche',
      expectedTitleKeyword: 'Nuvole Bianche',
      expectedArtistKeyword: 'Einaudi',
      category: 'Instrumental',
    ),

    // 14-16: Live Recordings
    TestCorpusTrack(
      query: 'Eagles Hotel California Live 1994',
      expectedTitleKeyword: 'Hotel California',
      expectedArtistKeyword: 'Eagles',
      category: 'Live',
    ),
    TestCorpusTrack(
      query: 'Queen Bohemian Rhapsody Live Aid 1985',
      expectedTitleKeyword: 'Bohemian Rhapsody',
      expectedArtistKeyword: 'Queen',
      category: 'Live',
    ),
    TestCorpusTrack(
      query: 'Nirvana Where Did You Sleep Last Night MTV Unplugged',
      expectedTitleKeyword: 'Where Did You Sleep',
      expectedArtistKeyword: 'Nirvana',
      category: 'Live',
    ),

    // 17-18: Global Non-English
    TestCorpusTrack(
      query: 'Arijit Singh Kesariya Brahmastra',
      expectedTitleKeyword: 'Kesariya',
      expectedArtistKeyword: 'Arijit',
      category: 'Global',
    ),
    TestCorpusTrack(
      query: 'Fujii Kaze Shinunoga E-Wa',
      expectedTitleKeyword: 'Shinunoga',
      expectedArtistKeyword: 'Fujii Kaze',
      category: 'Global',
    ),

    // 19-21: Long-Form Audio (> 45 Minutes)
    TestCorpusTrack(
      query: '1 Hour Lofi Hip Hop Beats to Relax Study to',
      expectedTitleKeyword: 'Lofi',
      expectedArtistKeyword: 'Lofi',
      category: 'Long-Form',
      isLongTrack: true,
    ),
    TestCorpusTrack(
      query: '1 Hour Deep Focus Study Music Alpha Waves',
      expectedTitleKeyword: 'Focus',
      expectedArtistKeyword: 'Music',
      category: 'Long-Form',
      isLongTrack: true,
    ),
    TestCorpusTrack(
      query: '1 Hour Ambient Space Music Deep Relaxation',
      expectedTitleKeyword: 'Ambient',
      expectedArtistKeyword: 'Music',
      category: 'Long-Form',
      isLongTrack: true,
    ),
  ];
}
