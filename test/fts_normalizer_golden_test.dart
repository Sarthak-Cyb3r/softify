import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/search/text_normalizer.dart';

void main() {
  group('S2: TextNormalizer Golden Tests', () {
    test('Diacritic stripping handles all European and Romanized accents correctly', () {
      expect(TextNormalizer.normalize('Beyoncé'), 'beyonce');
      expect(TextNormalizer.normalize('Señorita'), 'senorita');
      expect(TextNormalizer.normalize('Motörhead'), 'motorhead');
      expect(TextNormalizer.normalize('Björk'), 'bjork');
      expect(TextNormalizer.normalize('Dvořák'), 'dvorak');
      expect(TextNormalizer.normalize('Café del Mar'), 'cafe del mar');
    });

    test('Punctuation collapse replaces symbols with space and trims whitespace', () {
      expect(TextNormalizer.normalize('A.R. Rahman'), 'a r rahman');
      expect(TextNormalizer.normalize('Jay-Z & Kanye West'), 'jay z kanye west');
      expect(TextNormalizer.normalize('AC/DC - Highway to Hell!'), 'ac dc highway to hell');
      expect(TextNormalizer.normalize('   Starboy (feat. Daft Punk)   '), 'starboy feat daft punk');
    });

    test('Levenshtein distance & similarity ratio are accurate', () {
      expect(TextNormalizer.levenshteinDistance('arijit', 'arijit'), 0);
      expect(TextNormalizer.similarity('arijit', 'arijit'), 1.0);

      // 1 char typo: arijit vs arijt
      expect(TextNormalizer.levenshteinDistance('arijit', 'arijt'), 1);
      expect(TextNormalizer.similarity('arijit', 'arijt'), closeTo(0.83, 0.02));

      // Completely different
      expect(TextNormalizer.levenshteinDistance('arijit', 'coldplay'), 8);
    });

    test('Prefix and exact matching predicates work accurately', () {
      expect(TextNormalizer.isExactMatch('Tum Hi Ho', 'tum hi ho'), isTrue);
      expect(TextNormalizer.isExactMatch('Tum Hi Ho', 'tum hi'), isFalse);

      expect(TextNormalizer.isPrefixMatch('ari', 'Arijit Singh'), isTrue);
      expect(TextNormalizer.isPrefixMatch('singh', 'Arijit Singh'), isTrue);
      expect(TextNormalizer.isPrefixMatch('dil', 'Arijit Singh'), isFalse);
    });

    test('Alias expansion maps tokens and full queries based on alias dictionary', () {
      final aliases = {
        'arijit': ['arijit singh'],
        'kk': ['krishnakumar kunnath'],
        'weeknd': ['the weeknd'],
      };

      final expandedArijit = TextNormalizer.expandAliases('arijit', aliases);
      expect(expandedArijit, contains('arijit'));
      expect(expandedArijit, contains('arijit singh'));

      final expandedCompound = TextNormalizer.expandAliases('songs of kk', aliases);
      expect(expandedCompound, contains('songs of kk'));
      expect(expandedCompound, contains('songs of krishnakumar kunnath'));
    });
  });
}
