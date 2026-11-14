import 'dart:io';
import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../database/app_database.dart';

/// Supported musical languages for regional taste and mood personalization.
enum MusicLanguage {
  hindi('Hindi', 'Bollywood & Hindi'),
  punjabi('Punjabi', 'Punjabi Hits'),
  tamil('Tamil', 'Tamil Hits'),
  telugu('Telugu', 'Telugu Hits'),
  malayalam('Malayalam', 'Malayalam Hits'),
  kannada('Kannada', 'Kannada Hits'),
  bengali('Bengali', 'Bengali Hits'),
  bhojpuri('Bhojpuri', 'Bhojpuri Hits'),
  marathi('Marathi', 'Marathi Hits'),
  spanish('Spanish', 'Spanish & Latin'),
  korean('Korean', 'K-Pop & Korean'),
  japanese('Japanese', 'J-Pop & Anime'),
  english('English', 'English & International');

  final String label;
  final String displayName;
  const MusicLanguage(this.label, this.displayName);
}

class UserListeningLanguages {
  final MusicLanguage primary;
  final MusicLanguage? secondary;
  final Map<MusicLanguage, double> scores;
  final bool isAutoDetected;

  const UserListeningLanguages({
    required this.primary,
    this.secondary,
    this.scores = const {},
    this.isAutoDetected = true,
  });
}

class MusicLanguageService {
  static const String settingKey = 'mood_language_override';

  static final _devanagariRegex = RegExp(r'[\u0900-\u097F]');
  static final _gurmukhiRegex = RegExp(r'[\u0A00-\u0A7F]');
  static final _tamilRegex = RegExp(r'[\u0B80-\u0BFF]');
  static final _teluguRegex = RegExp(r'[\u0C00-\u0C7F]');
  static final _kannadaRegex = RegExp(r'[\u0C80-\u0CFF]');
  static final _malayalamRegex = RegExp(r'[\u0D00-\u0D7F]');
  static final _bengaliRegex = RegExp(r'[\u0980-\u09FF]');
  static final _gujaratiRegex = RegExp(r'[\u0A80-\u0AFF]');
  static final _hangulRegex = RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]');
  static final _japaneseRegex = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');
  static final _cyrillicRegex = RegExp(r'[\u0400-\u04FF]');

  static const Map<String, MusicLanguage> _knownArtists = {
    // Hindi / Bollywood
    'arijit singh': MusicLanguage.hindi,
    'pritam': MusicLanguage.hindi,
    'neha kakkar': MusicLanguage.hindi,
    'shreya ghoshal': MusicLanguage.hindi,
    'atif aslam': MusicLanguage.hindi,
    'badshah': MusicLanguage.hindi,
    'yo yo honey singh': MusicLanguage.hindi,
    'honey singh': MusicLanguage.hindi,
    'jubin nautiyal': MusicLanguage.hindi,
    'kumar sanu': MusicLanguage.hindi,
    'alka yagnik': MusicLanguage.hindi,
    'udit narayan': MusicLanguage.hindi,
    'kishore kumar': MusicLanguage.hindi,
    'lata mangeshkar': MusicLanguage.hindi,
    'mohammed rafi': MusicLanguage.hindi,
    'sonu nigam': MusicLanguage.hindi,
    'sunidhi chauhan': MusicLanguage.hindi,
    'vishal-shekhar': MusicLanguage.hindi,
    'vishal mishra': MusicLanguage.hindi,
    'sachin-jigar': MusicLanguage.hindi,
    'shankar-ehsaan-loy': MusicLanguage.hindi,
    'amit trivedi': MusicLanguage.hindi,
    'kk': MusicLanguage.hindi,
    'mohit chauhan': MusicLanguage.hindi,
    'darshan raval': MusicLanguage.hindi,
    'armaan malik': MusicLanguage.hindi,
    'anuv jain': MusicLanguage.hindi,
    'jasleen royal': MusicLanguage.hindi,
    'b praak': MusicLanguage.hindi,
    'tanishk bagchi': MusicLanguage.hindi,
    'stebin ben': MusicLanguage.hindi,
    'mithoon': MusicLanguage.hindi,
    'javed ali': MusicLanguage.hindi,
    'lucky ali': MusicLanguage.hindi,
    'rahat fateh ali khan': MusicLanguage.hindi,
    'shilpa rao': MusicLanguage.hindi,
    'monali thakur': MusicLanguage.hindi,
    'king': MusicLanguage.hindi,
    'mc stan': MusicLanguage.hindi,
    'raftaar': MusicLanguage.hindi,
    'divine': MusicLanguage.hindi,
    'emiway bantai': MusicLanguage.hindi,
    'seedhe maut': MusicLanguage.hindi,
    'kr\$na': MusicLanguage.hindi,
    'papon': MusicLanguage.hindi,
    'shaan': MusicLanguage.hindi,
    'himesh reshammiya': MusicLanguage.hindi,
    'mika singh': MusicLanguage.hindi,
    'anuradha paudwal': MusicLanguage.hindi,
    'asha bhosle': MusicLanguage.hindi,
    'jagjit singh': MusicLanguage.hindi,
    'pankaj udhas': MusicLanguage.hindi,

    // Punjabi
    'diljit dosanjh': MusicLanguage.punjabi,
    'sidhu moose wala': MusicLanguage.punjabi,
    'sidhu moosewala': MusicLanguage.punjabi,
    'karan aujla': MusicLanguage.punjabi,
    'ap dhillon': MusicLanguage.punjabi,
    'shubh': MusicLanguage.punjabi,
    'guru randhawa': MusicLanguage.punjabi,
    'amrit maan': MusicLanguage.punjabi,
    'parmish verma': MusicLanguage.punjabi,
    'gippy grewal': MusicLanguage.punjabi,
    'babbu maan': MusicLanguage.punjabi,
    'amrinder gill': MusicLanguage.punjabi,
    'garry sandhu': MusicLanguage.punjabi,
    'jassi gill': MusicLanguage.punjabi,
    'harrdy sandhu': MusicLanguage.punjabi,
    'jasmine sandlas': MusicLanguage.punjabi,
    'sunanda sharma': MusicLanguage.punjabi,
    'prabh deep': MusicLanguage.punjabi,
    'gurinder gill': MusicLanguage.punjabi,
    'intense': MusicLanguage.punjabi,
    'prophec': MusicLanguage.punjabi,
    'sukhe': MusicLanguage.punjabi,
    'mickey singh': MusicLanguage.punjabi,
    'mankirt aulakh': MusicLanguage.punjabi,
    'jordan sandhu': MusicLanguage.punjabi,
    'kulwinder billa': MusicLanguage.punjabi,
    'tarsem jassar': MusicLanguage.punjabi,
    'bohemia': MusicLanguage.punjabi,
    'ammy virk': MusicLanguage.punjabi,
    'nimrat khaira': MusicLanguage.punjabi,

    // Tamil
    'anirudh ravichander': MusicLanguage.tamil,
    'anirudh': MusicLanguage.tamil,
    'a.r. rahman': MusicLanguage.tamil,
    'ar rahman': MusicLanguage.tamil,
    'yuvan shankar raja': MusicLanguage.tamil,
    'harris jayaraj': MusicLanguage.tamil,
    'd. imman': MusicLanguage.tamil,
    'santhosh narayanan': MusicLanguage.tamil,
    'g.v. prakash kumar': MusicLanguage.tamil,
    'gv prakash': MusicLanguage.tamil,
    'ilaiyaraaja': MusicLanguage.tamil,
    'ilayaraja': MusicLanguage.tamil,
    'sid sriram': MusicLanguage.tamil,
    'pradeep kumar': MusicLanguage.tamil,
    'sean roldan': MusicLanguage.tamil,
    'hiphop tamizha': MusicLanguage.tamil,
    'vijay antony': MusicLanguage.tamil,
    's. p. balasubrahmanyam': MusicLanguage.tamil,
    'spb': MusicLanguage.tamil,

    // Telugu
    'devi sri prasad': MusicLanguage.telugu,
    'dsp': MusicLanguage.telugu,
    's. thaman': MusicLanguage.telugu,
    'thaman s': MusicLanguage.telugu,
    'thaman': MusicLanguage.telugu,
    'm.m. keeravaani': MusicLanguage.telugu,
    'mm keeravaani': MusicLanguage.telugu,
    'keeravani': MusicLanguage.telugu,
    'mickey j meyer': MusicLanguage.telugu,
    'ram miriyala': MusicLanguage.telugu,
    'anurag kulkarni': MusicLanguage.telugu,
    'mangli': MusicLanguage.telugu,

    // Malayalam
    'sushin shyam': MusicLanguage.malayalam,
    'hesham abdul wahab': MusicLanguage.malayalam,
    'vidyasagar': MusicLanguage.malayalam,
    'shaan rahman': MusicLanguage.malayalam,
    'jakes bejoy': MusicLanguage.malayalam,
    'deepak dev': MusicLanguage.malayalam,
    'job kurian': MusicLanguage.malayalam,

    // Kannada
    'v. harikrishna': MusicLanguage.kannada,
    'arjun janya': MusicLanguage.kannada,
    'b. ajaneesh loknath': MusicLanguage.kannada,
    'charan raj': MusicLanguage.kannada,
    'raghu dixit': MusicLanguage.kannada,
    'ravi basrur': MusicLanguage.kannada,

    // Bengali
    'anupam roy': MusicLanguage.bengali,
    'somlata': MusicLanguage.bengali,
    'nachiketa': MusicLanguage.bengali,
    'hemanta mukherjee': MusicLanguage.bengali,
    'manna dey': MusicLanguage.bengali,

    // Bhojpuri
    'pawan singh': MusicLanguage.bhojpuri,
    'khesari lal yadav': MusicLanguage.bhojpuri,
    'khesari': MusicLanguage.bhojpuri,
    'shilpi raj': MusicLanguage.bhojpuri,

    // Marathi
    'ajay-atul': MusicLanguage.marathi,
    'swapnil bandodkar': MusicLanguage.marathi,
    'avadhoot gupte': MusicLanguage.marathi,

    // Spanish / Latin
    'bad bunny': MusicLanguage.spanish,
    'rosalía': MusicLanguage.spanish,
    'rosalia': MusicLanguage.spanish,
    'j balvin': MusicLanguage.spanish,
    'daddy yankee': MusicLanguage.spanish,
    'rauw alejandro': MusicLanguage.spanish,
    'ozuna': MusicLanguage.spanish,
    'maluma': MusicLanguage.spanish,
    'karol g': MusicLanguage.spanish,
    'peso pluma': MusicLanguage.spanish,
    'feid': MusicLanguage.spanish,
    'shakira': MusicLanguage.spanish,
    'luis fonsi': MusicLanguage.spanish,
    'anuel aa': MusicLanguage.spanish,
    'becky g': MusicLanguage.spanish,
    'bizarrap': MusicLanguage.spanish,
    'sebastian yatra': MusicLanguage.spanish,
    'camilo': MusicLanguage.spanish,

    // Korean
    'bts': MusicLanguage.korean,
    'blackpink': MusicLanguage.korean,
    'newjeans': MusicLanguage.korean,
    'twice': MusicLanguage.korean,
    'stray kids': MusicLanguage.korean,
    'txt': MusicLanguage.korean,
    'seventeen': MusicLanguage.korean,
    'le sserafim': MusicLanguage.korean,
    'aespa': MusicLanguage.korean,
    'iu': MusicLanguage.korean,
    'jung kook': MusicLanguage.korean,
    'jimin': MusicLanguage.korean,
    'exo': MusicLanguage.korean,
    'red velvet': MusicLanguage.korean,
    'enhypen': MusicLanguage.korean,
    'itzy': MusicLanguage.korean,
    '(g)i-dle': MusicLanguage.korean,
    'ive': MusicLanguage.korean,

    // Japanese
    'yoasobi': MusicLanguage.japanese,
    'kenshi yonezu': MusicLanguage.japanese,
    'ado': MusicLanguage.japanese,
    'radwimps': MusicLanguage.japanese,
    'king gnu': MusicLanguage.japanese,
    'fujii kaze': MusicLanguage.japanese,
    'lisa': MusicLanguage.japanese,
    'eve': MusicLanguage.japanese,
    'official hige dandism': MusicLanguage.japanese,
    'aimer': MusicLanguage.japanese,
    'vaundy': MusicLanguage.japanese,

    // English / Western
    'the weeknd': MusicLanguage.english,
    'taylor swift': MusicLanguage.english,
    'drake': MusicLanguage.english,
    'ed sheeran': MusicLanguage.english,
    'ariana grande': MusicLanguage.english,
    'billie eilish': MusicLanguage.english,
    'bruno mars': MusicLanguage.english,
    'dua lipa': MusicLanguage.english,
    'justin bieber': MusicLanguage.english,
    'post malone': MusicLanguage.english,
    'eminem': MusicLanguage.english,
    'rihanna': MusicLanguage.english,
    'beyoncé': MusicLanguage.english,
    'beyonce': MusicLanguage.english,
    'coldplay': MusicLanguage.english,
    'imagine dragons': MusicLanguage.english,
    'olivia rodrigo': MusicLanguage.english,
    'harry styles': MusicLanguage.english,
    'kendrick lamar': MusicLanguage.english,
    'adele': MusicLanguage.english,
    'travis scott': MusicLanguage.english,
    'kanye west': MusicLanguage.english,
    'sza': MusicLanguage.english,
    'maroon 5': MusicLanguage.english,
    'sam smith': MusicLanguage.english,
    'charlie puth': MusicLanguage.english,
    'shawn mendes': MusicLanguage.english,
    'lady gaga': MusicLanguage.english,
    'katy perry': MusicLanguage.english,
    'david guetta': MusicLanguage.english,
    'calvin harris': MusicLanguage.english,
  };

  static const Map<MusicLanguage, List<String>> _languageKeywords = {
    MusicLanguage.hindi: [
      'bollywood', 'hindi', 'dil', 'pyar', 'pyaar', 'ishq', 'mohabbat', 'zindagi',
      'saathiya', 'humsafar', 'deewana', 'khuda', 'raatan', 'channa', 'kahani',
      'tera', 'teri', 'tere', 'mera', 'meri', 'mere', 'tujhe', 'aashiqui',
      'sanam', 'jaan', 'yaara', 'dhadkan', 'barsaat', 'baarish', 'akhiyan',
      'kasam', 'rabba', 'naina', 'duniya', 'kabhi', 'tum', 'nazar', 'chal',
    ],
    MusicLanguage.punjabi: [
      'punjabi', 'bhangra', 'jatt', 'jatti', 'gabru', 'surma', 'pind', 'yaari',
      'sohniye', 'munda', 'kudi', 'patola', 'gediyan', 'suit', 'kurta', 'paggan',
      'laavan', 'dhol', 'mutiyare', 'shada', 'jatta', 'majha', 'malwa', 'doaba',
    ],
    MusicLanguage.tamil: [
      'tamil', 'kadhal', 'kanmani', 'vaathi', 'kanna', 'uyire', 'thani', 'kuthu',
      'theri', 'rowdy', 'alaipayuthey', 'anbe', 'marakkuma', 'kollywood',
    ],
    MusicLanguage.telugu: [
      'telugu', 'prema', 'cheliya', 'ninnu', 'manasu', 'ravali', 'rapo', 'mass',
      'gunturo', 'pushpa', 'devara', 'tollywood',
    ],
    MusicLanguage.malayalam: [
      'malayalam', 'hridayam', 'sneham', 'kadhakal', 'ente', 'njan', 'kerala',
    ],
    MusicLanguage.kannada: [
      'kannada', 'preethi', 'huduga', 'hudugi', 'sandalwood',
    ],
    MusicLanguage.bengali: [
      'bengali', 'bangla', 'bhalobasha', 'gaan', 'rabindrasangeet',
    ],
    MusicLanguage.bhojpuri: [
      'bhojpuri', 'kamar', 'choli', 'bhatar', 'patna',
    ],
    MusicLanguage.marathi: [
      'marathi', 'lavani',
    ],
    MusicLanguage.spanish: [
      'reggaeton', 'latino', 'despacito', 'bailando', 'amor', 'corazon', 'noche',
      'perreo', 'espanol', 'cancion',
    ],
    MusicLanguage.korean: [
      'k-pop', 'kpop', 'k-drama',
    ],
    MusicLanguage.japanese: [
      'j-pop', 'jpop', 'anime', 'vocaloid', 'city pop',
    ],
  };

  /// Detects the user's listening languages from recent playback history,
  /// liked songs, and taste profile entities.
  static Future<UserListeningLanguages> detectUserLanguages(AppDatabase db) async {
    // 1. Check for manual preference override
    final overrideRow = await (db.select(db.settings)
          ..where((t) => t.key.equals(settingKey)))
        .getSingleOrNull();

    if (overrideRow != null &&
        overrideRow.value.isNotEmpty &&
        overrideRow.value.toLowerCase() != 'auto') {
      for (final lang in MusicLanguage.values) {
        if (lang.name.toLowerCase() == overrideRow.value.toLowerCase()) {
          return UserListeningLanguages(
            primary: lang,
            secondary: null,
            isAutoDetected: false,
          );
        }
      }
    }

    final Map<MusicLanguage, double> scores = {
      for (final lang in MusicLanguage.values) lang: 0.0,
    };

    // 2. Sample recent listening history (high weight, recency decay)
    try {
      final historyRows = await (db.select(db.playHistories).join([
        innerJoin(db.tracks, db.tracks.id.equalsExp(db.playHistories.trackId)),
      ])
            ..orderBy([OrderingTerm.desc(db.playHistories.playedAt)])
            ..limit(60))
          .get();

      for (int i = 0; i < historyRows.length; i++) {
        final row = historyRows[i];
        final track = row.readTable(db.tracks);
        final recencyWeight = 2.0 - (i / historyRows.length);
        _scoreTrack(track.title, track.artist, track.album, recencyWeight, scores);
      }
    } catch (_) {}

    // 3. Sample liked tracks (affinity weight 1.5)
    try {
      final likedRows = await (db.select(db.tracks)
            ..where((t) => t.isLiked.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(40))
          .get();

      for (final track in likedRows) {
        _scoreTrack(track.title, track.artist, track.album, 1.5, scores);
      }
    } catch (_) {}

    // 4. Sample taste profile top artists
    try {
      final tasteProfiles = await (db.select(db.tasteProfiles)
            ..where((t) => t.entityType.equals('artist'))
            ..orderBy([(t) => OrderingTerm.desc(t.slowWeight)])
            ..limit(25))
          .get();

      for (final tp in tasteProfiles) {
        final artistWeight = ((tp.fastWeight * 0.4) + (tp.slowWeight * 0.6)).clamp(0.5, 5.0);
        _scoreArtistOnly(tp.entityId, artistWeight, scores);
      }
    } catch (_) {}

    // 5. Default fallback based on device locale if no history exists yet
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntry = sorted.first;
    if (topEntry.value <= 0.0) {
      final defaultLang = _detectLocaleFallback();
      return UserListeningLanguages(
        primary: defaultLang,
        secondary: null,
        scores: scores,
        isAutoDetected: true,
      );
    }

    final primary = topEntry.key;
    MusicLanguage? secondary;

    // Detect significant secondary language (>= 30% of primary score and >= 3.0 pts)
    if (sorted.length > 1) {
      final runnerUp = sorted[1];
      if (runnerUp.value >= 3.0 &&
          runnerUp.value >= (topEntry.value * 0.30) &&
          runnerUp.key != primary) {
        secondary = runnerUp.key;
      }
    }

    return UserListeningLanguages(
      primary: primary,
      secondary: secondary,
      scores: scores,
      isAutoDetected: true,
    );
  }

  static MusicLanguage _detectLocaleFallback() {
    try {
      final locale = Platform.localeName.toLowerCase();
      if (locale.contains('_in') || locale.startsWith('hi')) {
        return MusicLanguage.hindi;
      } else if (locale.startsWith('pa')) {
        return MusicLanguage.punjabi;
      } else if (locale.startsWith('ta')) {
        return MusicLanguage.tamil;
      } else if (locale.startsWith('te')) {
        return MusicLanguage.telugu;
      } else if (locale.startsWith('ml')) {
        return MusicLanguage.malayalam;
      } else if (locale.startsWith('kn')) {
        return MusicLanguage.kannada;
      } else if (locale.startsWith('bn')) {
        return MusicLanguage.bengali;
      } else if (locale.startsWith('es')) {
        return MusicLanguage.spanish;
      } else if (locale.startsWith('ko')) {
        return MusicLanguage.korean;
      } else if (locale.startsWith('ja')) {
        return MusicLanguage.japanese;
      }
    } catch (_) {}
    return MusicLanguage.english;
  }

  static void _scoreTrack(
    String title,
    String artist,
    String? album,
    double weight,
    Map<MusicLanguage, double> scores,
  ) {
    final fullText = '$title $artist ${album ?? ''}';

    // 1. Script-level detection (strongest signal)
    if (_devanagariRegex.hasMatch(fullText)) {
      scores[MusicLanguage.hindi] = (scores[MusicLanguage.hindi] ?? 0) + (10.0 * weight);
    }
    if (_gurmukhiRegex.hasMatch(fullText)) {
      scores[MusicLanguage.punjabi] = (scores[MusicLanguage.punjabi] ?? 0) + (10.0 * weight);
    }
    if (_tamilRegex.hasMatch(fullText)) {
      scores[MusicLanguage.tamil] = (scores[MusicLanguage.tamil] ?? 0) + (10.0 * weight);
    }
    if (_teluguRegex.hasMatch(fullText)) {
      scores[MusicLanguage.telugu] = (scores[MusicLanguage.telugu] ?? 0) + (10.0 * weight);
    }
    if (_kannadaRegex.hasMatch(fullText)) {
      scores[MusicLanguage.kannada] = (scores[MusicLanguage.kannada] ?? 0) + (10.0 * weight);
    }
    if (_malayalamRegex.hasMatch(fullText)) {
      scores[MusicLanguage.malayalam] = (scores[MusicLanguage.malayalam] ?? 0) + (10.0 * weight);
    }
    if (_bengaliRegex.hasMatch(fullText)) {
      scores[MusicLanguage.bengali] = (scores[MusicLanguage.bengali] ?? 0) + (10.0 * weight);
    }
    if (_hangulRegex.hasMatch(fullText)) {
      scores[MusicLanguage.korean] = (scores[MusicLanguage.korean] ?? 0) + (10.0 * weight);
    }
    if (_japaneseRegex.hasMatch(fullText)) {
      scores[MusicLanguage.japanese] = (scores[MusicLanguage.japanese] ?? 0) + (10.0 * weight);
    }

    // 2. Artist attribution (split collaborative artist strings)
    _scoreArtistOnly(artist, weight, scores);

    // 3. Title & Album keyword tokens
    final words = fullText.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+')).toSet();
    for (final entry in _languageKeywords.entries) {
      final lang = entry.key;
      for (final kw in entry.value) {
        if (words.contains(kw) || fullText.toLowerCase().contains(kw)) {
          scores[lang] = (scores[lang] ?? 0) + (2.5 * weight);
        }
      }
    }
  }

  static void _scoreArtistOnly(
    String artist,
    double weight,
    Map<MusicLanguage, double> scores,
  ) {
    final subArtists = artist
        .split(RegExp(r'[,;&/|]|\s+feat\.?\s+|\s+ft\.?\s+|\s+with\s+', caseSensitive: false))
        .map((a) => a.trim().toLowerCase())
        .where((a) => a.isNotEmpty);

    for (final sub in subArtists) {
      final lang = _knownArtists[sub];
      if (lang != null) {
        scores[lang] = (scores[lang] ?? 0) + (8.0 * weight);
      } else {
        // Partial check for well-known prefixes/substrings
        for (final entry in _knownArtists.entries) {
          if (sub.contains(entry.key) || entry.key.contains(sub)) {
            scores[entry.value] = (scores[entry.value] ?? 0) + (5.0 * weight);
            break;
          }
        }
      }
    }
  }

  /// Builds a localized catalog query tailored to the specified [mood] and [language].
  static String getMoodQuery(String mood, MusicLanguage language) {
    switch (language) {
      case MusicLanguage.hindi:
        return switch (mood) {
          'Relax' => 'hindi chill relaxing acoustic bollywood peaceful',
          'Energize' => 'bollywood dance energizing upbeat hindi hits',
          'Workout' => 'hindi gym workout motivation high energy beats',
          'Focus' => 'indian classical instrumental sitar flute lofi hindi',
          'Commute' => 'bollywood road trip travel commute hindi songs',
          'Party' => 'bollywood party dance club hits bangers remix',
          'Romance' => 'romantic hindi songs bollywood love ballads',
          _ => 'hindi $mood songs bollywood',
        };

      case MusicLanguage.punjabi:
        return switch (mood) {
          'Relax' => 'punjabi acoustic chill soft peaceful songs',
          'Energize' => 'punjabi upbeat bhangra dance energizing hits',
          'Workout' => 'punjabi gym workout motivation high energy',
          'Focus' => 'punjabi lofi acoustic instrumental chill',
          'Commute' => 'punjabi road trip travel car songs commute',
          'Party' => 'punjabi party club dance bangers dhol',
          'Romance' => 'punjabi romantic love songs soft ballads',
          _ => 'punjabi $mood songs',
        };

      case MusicLanguage.tamil:
        return switch (mood) {
          'Relax' => 'tamil chill acoustic melody relaxing soft songs',
          'Energize' => 'tamil kuthu upbeat dance energizing hits',
          'Workout' => 'tamil workout gym motivation high energy beats',
          'Focus' => 'tamil instrumental lofi acoustic melody calm',
          'Commute' => 'tamil road trip travel drive commute songs',
          'Party' => 'tamil party dance kuthu club hits bangers',
          'Romance' => 'tamil romantic love songs melodies',
          _ => 'tamil $mood songs',
        };

      case MusicLanguage.telugu:
        return switch (mood) {
          'Relax' => 'telugu chill melody relaxing acoustic soft songs',
          'Energize' => 'telugu upbeat dance mass energizing hits',
          'Workout' => 'telugu gym workout motivation high energy beats',
          'Focus' => 'telugu instrumental lofi acoustic melody calm',
          'Commute' => 'telugu road trip travel drive commute songs',
          'Party' => 'telugu party mass dance club hits bangers',
          'Romance' => 'telugu romantic love songs melodies',
          _ => 'telugu $mood songs',
        };

      case MusicLanguage.malayalam:
        return switch (mood) {
          'Relax' => 'malayalam chill acoustic melody relaxing songs',
          'Energize' => 'malayalam upbeat dance energizing hits',
          'Workout' => 'malayalam gym workout motivation high energy',
          'Focus' => 'malayalam instrumental lofi acoustic calm',
          'Commute' => 'malayalam road trip travel drive commute songs',
          'Party' => 'malayalam party dance club hits',
          'Romance' => 'malayalam romantic love songs melodies',
          _ => 'malayalam $mood songs',
        };

      case MusicLanguage.kannada:
        return switch (mood) {
          'Relax' => 'kannada chill acoustic melody relaxing songs',
          'Energize' => 'kannada upbeat dance mass energizing hits',
          'Workout' => 'kannada gym workout motivation beats',
          'Focus' => 'kannada instrumental lofi acoustic calm',
          'Commute' => 'kannada road trip travel drive songs',
          'Party' => 'kannada party dance club hits',
          'Romance' => 'kannada romantic love songs',
          _ => 'kannada $mood songs',
        };

      case MusicLanguage.bengali:
        return switch (mood) {
          'Relax' => 'bengali chill acoustic relaxing soft songs',
          'Energize' => 'bengali upbeat dance energizing hits',
          'Workout' => 'bengali gym workout motivation beats',
          'Focus' => 'rabindrasangeet instrumental flute lofi calm',
          'Commute' => 'bengali road trip travel songs',
          'Party' => 'bengali party dance hits',
          'Romance' => 'bengali romantic love songs',
          _ => 'bengali $mood songs',
        };

      case MusicLanguage.bhojpuri:
        return switch (mood) {
          'Relax' => 'bhojpuri acoustic soft songs',
          'Energize' => 'bhojpuri dance upbeat hits',
          'Workout' => 'bhojpuri gym workout beats',
          'Focus' => 'bhojpuri instrumental lofi',
          'Commute' => 'bhojpuri road trip songs',
          'Party' => 'bhojpuri party dance club hits bangers',
          'Romance' => 'bhojpuri romantic love songs',
          _ => 'bhojpuri $mood songs',
        };

      case MusicLanguage.marathi:
        return switch (mood) {
          'Relax' => 'marathi acoustic chill soft songs',
          'Energize' => 'marathi upbeat dance energizing hits',
          'Workout' => 'marathi workout motivation beats',
          'Focus' => 'marathi instrumental lofi calm',
          'Commute' => 'marathi travel road trip songs',
          'Party' => 'marathi party dance club hits',
          'Romance' => 'marathi romantic love songs',
          _ => 'marathi $mood songs',
        };

      case MusicLanguage.spanish:
        return switch (mood) {
          'Relax' => 'espanol chill acustico relajante canciones suaves',
          'Energize' => 'reggaeton latino upbeat fiesta energico hits',
          'Workout' => 'reggaeton gym motivacion entrenamiento beats',
          'Focus' => 'guitarra espanola instrumental lofi estudio calma',
          'Commute' => 'musica latina para viajar carretera viaje',
          'Party' => 'fiesta latina reggaeton dance club bangers perreo',
          'Romance' => 'baladas romanticas canciones de amor espanol',
          _ => 'musica latina $mood',
        };

      case MusicLanguage.korean:
        return switch (mood) {
          'Relax' => 'k-pop chill acoustic calm relaxing soft ballads',
          'Energize' => 'k-pop upbeat dance energizing hype hits',
          'Workout' => 'k-pop workout gym motivation high energy beats',
          'Focus' => 'k-drama ost instrumental piano lofi study focus',
          'Commute' => 'k-pop travel drive commute feel good songs',
          'Party' => 'k-pop party dance club hits bangers',
          'Romance' => 'k-pop romantic love ballads ost',
          _ => 'k-pop $mood songs',
        };

      case MusicLanguage.japanese:
        return switch (mood) {
          'Relax' => 'j-pop chill acoustic relaxing soft calm songs',
          'Energize' => 'j-pop anime upbeat energizing hype hits',
          'Workout' => 'j-rock anime workout gym motivation high energy',
          'Focus' => 'ghibli lofi study beats instrumental calm',
          'Commute' => 'j-pop city pop drive road trip commute',
          'Party' => 'j-pop dance club edm party hits',
          'Romance' => 'j-pop romantic love songs ballads',
          _ => 'j-pop $mood songs',
        };

      case MusicLanguage.english:
        return switch (mood) {
          'Relax' => 'chill relaxing acoustic songs peaceful calm',
          'Energize' => 'energizing upbeat pop dance hype workout hits',
          'Workout' => 'workout gym motivation fitness beats hip hop',
          'Focus' => 'lofi study beats ambient instrumental deep focus',
          'Commute' => 'road trip travel commute feel good vibes',
          'Party' => 'party club dance floor bangers edm pop',
          'Romance' => 'romantic love songs acoustic soft ballads',
          _ => '$mood songs mix',
        };
    }
  }

  /// Saves a manual language preference override in the database.
  static Future<void> setPreferredLanguageOverride(
    AppDatabase db,
    String languageName,
  ) async {
    await db.into(db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: settingKey,
            value: languageName,
          ),
        );
  }

  /// Retrieves the current setting value ('auto' or a specific language name).
  static Future<String> getPreferredLanguageOverride(AppDatabase db) async {
    final row = await (db.select(db.settings)
          ..where((t) => t.key.equals(settingKey)))
        .getSingleOrNull();
    return row?.value ?? 'auto';
  }
}
