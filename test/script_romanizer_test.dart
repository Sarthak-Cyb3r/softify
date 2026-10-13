import 'package:flutter_test/flutter_test.dart';
import 'package:softify/data/lyrics/script_romanizer.dart';

void main() {
  group('ScriptRomanizer', () {
    test('detects Indic scripts accurately', () {
      expect(ScriptRomanizer.hasRomanizableScript('Hello world'), isFalse);
      expect(ScriptRomanizer.hasRomanizableScript('तुम ही हो'), isTrue);
      expect(ScriptRomanizer.hasRomanizableScript('ਸੋਹਣੇ ਸੱਜਣ'), isTrue);
      expect(ScriptRomanizer.hasRomanizableScript('12345 @#%'), isFalse);
    });

    test('preserves Latin, numbers, and symbols without mutation', () {
      const latinText = "Shape of You - Ed Sheeran (2017) [Remix]!";
      expect(ScriptRomanizer.romanize(latinText), equals(latinText));
    });

    test('phonetically transliterates Devanagari lyrics', () {
      final input = 'तुम ही हो, अब तुम ही हो';
      final romanized = ScriptRomanizer.romanize(input);
      expect(romanized, contains('tum hee ho'));
      expect(romanized, contains('ab tum hee ho'));
    });

    test('phonetically transliterates Gurmukhi lyrics', () {
      final input = 'ਦਿਲ ਦਾ ਮਾਮਲਾ';
      final romanized = ScriptRomanizer.romanize(input);
      expect(romanized, contains('dil'));
      expect(romanized, contains('da'));
    });
  });
}
