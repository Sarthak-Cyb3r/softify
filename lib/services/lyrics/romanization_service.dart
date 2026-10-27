import '../../data/lyrics/script_romanizer.dart';
import '../../domain/ports/i_lyrics_provider.dart';

/// Client-side Multilingual Romanization engine for synchronized karaoke lyrics.
/// Transliterates Japanese (Romaji), Korean (Revised Romanization),
/// Chinese (Pinyin), Russian & Ukrainian (Cyrillic to Latin), and
/// Indic scripts (Devanagari / Gurmukhi) deterministically on-device without network calls.
class RomanizationService {
  RomanizationService._();

  // ---------------------------------------------------------------------------
  // Japanese (Kana to Romaji)
  // ---------------------------------------------------------------------------

  static const Map<String, String> _japaneseDigraphs = {
    'キャ': 'kya',
    'キュ': 'kyu',
    'キョ': 'kyo',
    'シャ': 'sha',
    'シュ': 'shu',
    'ショ': 'sho',
    'チャ': 'cha',
    'チュ': 'chu',
    'チョ': 'cho',
    'ニャ': 'nya',
    'ニュ': 'nyu',
    'ニョ': 'nyo',
    'ヒャ': 'hya',
    'ヒュ': 'hyu',
    'ヒョ': 'hyo',
    'ミャ': 'mya',
    'ミュ': 'myu',
    'ミョ': 'myo',
    'リャ': 'rya',
    'リュ': 'ryu',
    'リョ': 'ryo',
    'ギャ': 'gya',
    'ギュ': 'gyu',
    'ギョ': 'gyo',
    'ジャ': 'ja',
    'ジュ': 'ju',
    'ジョ': 'jo',
    'ヂャ': 'ja',
    'ヂュ': 'ju',
    'ヂョ': 'jo',
    'ビャ': 'bya',
    'ビュ': 'byu',
    'ビョ': 'byo',
    'ピャ': 'pya',
    'ピュ': 'pyu',
    'ピョ': 'pyo',
    'ヴァ': 'va',
    'ヴィ': 'vi',
    'ヴ': 'vu',
    'ヴェ': 've',
    'ヴォ': 'vo',
    'ファ': 'fa',
    'フィ': 'fi',
    'フェ': 'fe',
    'フォ': 'fo',
    'チェ': 'che',
    'ジェ': 'je',
    'シェ': 'she',
    'ティ': 'ti',
    'ディ': 'di',
    'トゥ': 'tu',
    'ドゥ': 'du',
  };

  static const Map<String, String> _japaneseBasicKana = {
    'ア': 'a',
    'イ': 'i',
    'ウ': 'u',
    'エ': 'e',
    'オ': 'o',
    'カ': 'ka',
    'キ': 'ki',
    'ク': 'ku',
    'ケ': 'ke',
    'コ': 'ko',
    'サ': 'sa',
    'シ': 'shi',
    'ス': 'su',
    'セ': 'se',
    'ソ': 'so',
    'タ': 'ta',
    'チ': 'chi',
    'ツ': 'tsu',
    'テ': 'te',
    'ト': 'to',
    'ナ': 'na',
    'ニ': 'ni',
    'ヌ': 'nu',
    'ネ': 'ne',
    'ノ': 'no',
    'ハ': 'ha',
    'ヒ': 'hi',
    'フ': 'fu',
    'ヘ': 'he',
    'ホ': 'ho',
    'マ': 'ma',
    'ミ': 'mi',
    'ム': 'mu',
    'メ': 'me',
    'モ': 'mo',
    'ヤ': 'ya',
    'ユ': 'yu',
    'ヨ': 'yo',
    'ラ': 'ra',
    'リ': 'ri',
    'ル': 'ru',
    'レ': 're',
    'ロ': 'ro',
    'ワ': 'wa',
    'ヲ': 'o',
    'ン': 'n',
    'ガ': 'ga',
    'ギ': 'gi',
    'グ': 'gu',
    'ゲ': 'ge',
    'ゴ': 'go',
    'ザ': 'za',
    'ジ': 'ji',
    'ズ': 'zu',
    'ゼ': 'ze',
    'ゾ': 'zo',
    'ダ': 'da',
    'ヂ': 'ji',
    'ヅ': 'zu',
    'デ': 'de',
    'ド': 'do',
    'バ': 'ba',
    'ビ': 'bi',
    'ブ': 'bu',
    'ベ': 'be',
    'ボ': 'bo',
    'パ': 'pa',
    'ピ': 'pi',
    'プ': 'pu',
    'ペ': 'pe',
    'ポ': 'po',
    'ー': '',
  };

  /// Common Japanese Kanji dictionary in song lyrics
  static const Map<String, String> _japaneseKanjiWords = {
    '私': 'watashi',
    '僕': 'boku',
    '俺': 'ore',
    '君': 'kimi',
    '貴方': 'anata',
    '愛': 'ai',
    '恋': 'koi',
    '歌': 'uta',
    '夢': 'yume',
    '心': 'kokoro',
    '夜': 'yoru',
    '雨': 'ame',
    '空': 'sora',
    '涙': 'namida',
    '桜': 'sakura',
    '風': 'kaze',
    '光': 'hikari',
    '友': 'tomo',
    '道': 'michi',
    '花': 'hana',
    '声': 'koe',
    '月': 'tsuki',
    '星': 'hoshi',
    '音': 'oto',
    '世界': 'sekai',
    '約束': 'yakusoku',
    '未来': 'mirai',
    '永遠': 'eien',
    '今': 'ima',
    '時': 'toki',
    '日': 'hi',
    '人': 'hito',
    '手': 'te',
    '目': 'me',
    '言葉': 'kotoba',
    '笑顔': 'egao',
    '記憶': 'kioku',
    '誰': 'dare',
    '何': 'nani',
    '太陽': 'taiyou',
    '海': 'umi',
    '希望': 'kibou',
    '奇跡': 'kiseki',
    '運命': 'unmei',
    '自由': 'jiyuu',
    '生': 'sei',
    '死': 'shi',
    '想い': 'omoi',
    '想': 'omoi',
  };

  // ---------------------------------------------------------------------------
  // Korean (Hangul Revised Romanization)
  // ---------------------------------------------------------------------------

  static const List<String> _koreanCho = [
    'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '',
    'j', 'jj', 'ch', 'k', 't', 'p', 'h'
  ];

  static const List<String> _koreanJung = [
    'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe',
    'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i'
  ];

  static const Map<String, String> _koreanAssimilation = {
    'ᆨ': 'k',
    'ᆩ': 'k',
    'ᆪ': 'k',
    'ᆫ': 'n',
    'ᆬ': 'n',
    'ᆭ': 'n',
    'ᆮ': 't',
    'ᆯ': 'l',
    'ᆰ': 'k',
    'ᆱ': 'm',
    'ᆲ': 'p',
    'ᆳ': 't',
    'ᆴ': 't',
    'ᆵ': 'p',
    'ᆶ': 'l',
    'ᆷ': 'm',
    'ᆸ': 'p',
    'ᆹ': 'p',
    'ᆺ': 't',
    'ᆻ': 't',
    'ᆼ': 'ng',
    'ᆽ': 't',
    'ᆾ': 't',
    'ᆿ': 'k',
    'ᇀ': 't',
    'ᇁ': 'p',
    'ᇂ': 't',
    'ᆨᄋ': 'g',
    'ᆨᄂ': 'ngn',
    'ᆨᄅ': 'ngn',
    'ᆨᄆ': 'ngm',
    'ᆨᄒ': 'kh',
    'ᆩᄋ': 'kg',
    'ᆩᄂ': 'ngn',
    'ᆩᄅ': 'ngn',
    'ᆩᄆ': 'ngm',
    'ᆩᄒ': 'kh',
    'ᆪᄋ': 'ks',
    'ᆪᄂ': 'ngn',
    'ᆪᄅ': 'ngn',
    'ᆪᄆ': 'ngm',
    'ᆪᄒ': 'kch',
    'ᆫᄅ': 'll',
    'ᆬᄋ': 'nj',
    'ᆬᄂ': 'nn',
    'ᆬᄅ': 'nn',
    'ᆬᄆ': 'nm',
    'ᆬᄒ': 'nch',
    'ᆭᄋ': 'nh',
    'ᆭᄅ': 'nn',
    'ᆮᄋ': 'd',
    'ᆮᄂ': 'nn',
    'ᆮᄅ': 'nn',
    'ᆮᄆ': 'nm',
    'ᆮᄒ': 'th',
    'ᆯᄋ': 'r',
    'ᆯᄂ': 'll',
    'ᆯᄅ': 'll',
    'ᆰᄋ': 'lg',
    'ᆰᄂ': 'ngn',
    'ᆰᄅ': 'ngn',
    'ᆰᄆ': 'ngm',
    'ᆰᄒ': 'lkh',
    'ᆱᄋ': 'lm',
    'ᆱᄂ': 'mn',
    'ᆱᄅ': 'mn',
    'ᆱᄆ': 'mm',
    'ᆱᄒ': 'lmh',
    'ᆲᄋ': 'lb',
    'ᆲᄂ': 'mn',
    'ᆲᄅ': 'mn',
    'ᆲᄆ': 'mm',
    'ᆲᄒ': 'lph',
    'ᆳᄋ': 'ls',
    'ᆳᄂ': 'nn',
    'ᆳᄅ': 'nn',
    'ᆳᄆ': 'nm',
    'ᆳᄒ': 'lsh',
    'ᆴᄋ': 'lt',
    'ᆴᄂ': 'nn',
    'ᆴᄅ': 'nn',
    'ᆴᄆ': 'nm',
    'ᆴᄒ': 'lth',
    'ᆵᄋ': 'lp',
    'ᆵᄂ': 'mn',
    'ᆵᄅ': 'mn',
    'ᆵᄆ': 'mm',
    'ᆵᄒ': 'lph',
    'ᆶᄋ': 'lh',
    'ᆶᄂ': 'll',
    'ᆶᄅ': 'll',
    'ᆶᄆ': 'lm',
    'ᆶᄒ': 'lh',
    'ᆷᄅ': 'mn',
    'ᆸᄋ': 'b',
    'ᆸᄂ': 'mn',
    'ᆸᄅ': 'mn',
    'ᆸᄆ': 'mm',
    'ᆸᄒ': 'ph',
    'ᆹᄋ': 'ps',
    'ᆹᄂ': 'mn',
    'ᆹᄅ': 'mn',
    'ᆹᄆ': 'mm',
    'ᆹᄒ': 'psh',
    'ᆺᄋ': 's',
    'ᆺᄂ': 'nn',
    'ᆺᄅ': 'nn',
    'ᆺᄆ': 'nm',
    'ᆺᄒ': 'sh',
    'ᆻᄋ': 'ss',
    'ᆻᄂ': 'tn',
    'ᆻᄅ': 'tn',
    'ᆻᄆ': 'nm',
    'ᆻᄒ': 'th',
    'ᆽᄋ': 'j',
    'ᆽᄂ': 'nn',
    'ᆽᄅ': 'nn',
    'ᆽᄆ': 'nm',
    'ᆽᄒ': 'ch',
    'ᆾᄋ': 'ch',
    'ᆾᄂ': 'nn',
    'ᆾᄅ': 'nn',
    'ᆾᄆ': 'nm',
    'ᆾᄒ': 'ch',
    'ᆿᄋ': 'k',
    'ᆿᄂ': 'ngn',
    'ᆿᄅ': 'ngn',
    'ᆿᄆ': 'ngm',
    'ᆿᄒ': 'kh',
    'ᇀᄋ': 't',
    'ᇀᄂ': 'nn',
    'ᇀᄅ': 'nn',
    'ᇀᄆ': 'nm',
    'ᇀᄒ': 'th',
    'ᇁᄋ': 'p',
    'ᇁᄂ': 'mn',
    'ᇁᄅ': 'mn',
    'ᇁᄆ': 'mm',
    'ᇁᄒ': 'ph',
    'ᇂᄋ': 'h',
    'ᇂᄂ': 'nn',
    'ᇂᄅ': 'nn',
    'ᇂᄆ': 'mm',
    'ᇂᄒ': 't',
    'ᇂᄀ': 'k',
  };

  // ---------------------------------------------------------------------------
  // Cyrillic (Russian & Ukrainian)
  // ---------------------------------------------------------------------------

  static const Map<String, String> _generalCyrillic = {
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Ґ': 'G', 'Д': 'D',
    'Ѓ': 'Gj', 'Ђ': 'Dj', 'Е': 'E', 'Ё': 'Yo', 'Є': 'Ye', 'Ж': 'Zh',
    'З': 'Z', 'Ѕ': 'Dz', 'И': 'I', 'І': 'I', 'Ї': 'Yi', 'Й': 'Y',
    'Ј': 'Y', 'К': 'K', 'Л': 'L', 'Љ': 'Ly', 'М': 'M', 'Н': 'N',
    'Њ': 'Ny', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T',
    'Ћ': 'C', 'У': 'U', 'Ў': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
    'Ч': 'Ch', 'Џ': 'Dzh', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y',
    'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',

    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'ґ': 'g', 'д': 'd',
    'ѓ': 'gj', 'ђ': 'dj', 'е': 'e', 'ё': 'yo', 'є': 'ye', 'ж': 'zh',
    'з': 'z', 'ѕ': 'dz', 'и': 'i', 'і': 'i', 'ї': 'yi', 'й': 'y',
    'ј': 'y', 'к': 'k', 'л': 'l', 'љ': 'ly', 'м': 'm', 'н': 'n',
    'њ': 'ny', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't',
    'ћ': 'c', 'у': 'u', 'ў': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
    'ч': 'ch', 'џ': 'dzh', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y',
    'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  };

  static const Map<String, String> _ukrainianSpecial = {
    'Г': 'H', 'г': 'h',
    'Ґ': 'G', 'ґ': 'g',
    'Є': 'Ye', 'є': 'ye',
    'І': 'I', 'і': 'i',
    'Ї': 'Yi', 'ї': 'yi',
    'И': 'Y', 'и': 'y',
  };

  static const Map<String, String> _russianEndings = {
    'ого': 'ovo',
    'Ого': 'Ovo',
    'его': 'evo',
    'Его': 'Evo',
  };

  // ---------------------------------------------------------------------------
  // Chinese (Hanzi to Pinyin dictionary)
  // ---------------------------------------------------------------------------

  static const Map<String, String> _chinesePinyin = {
    '我': 'wo', '你': 'ni', '他': 'ta', '她': 'ta', '它': 'ta', '们': 'men',
    '的': 'de', '得': 'de', '地': 'de', '是': 'shi', '在': 'zai', '了': 'le',
    '有': 'you', '和': 'he', '这': 'zhe', '那': 'na', '不': 'bu', '要': 'yao',
    '会': 'hui', '能': 'neng', '想': 'xiang', '爱': 'ai', '恨': 'hen', '说': 'shuo',
    '话': 'hua', '听': 'ting', '见': 'jian', '看': 'kan', '走': 'zou', '来': 'lai',
    '去': 'qu', '回': 'hui', '家': 'jia', '心': 'xin', '意': 'yi', '情': 'qing',
    '天': 'tian', '人': 'ren', '生': 'sheng', '死': 'si', '梦': 'meng', '泪': 'lei',
    '哭': 'ku', '笑': 'xiao', '光': 'guang', '夜': 'ye', '月': 'yue', '日': 'ri',
    '星': 'xing', '风': 'feng', '雨': 'yu', '云': 'yun', '雪': 'xue', '海': 'hai',
    '山': 'shan', '水': 'shui', '花': 'hua', '歌': 'ge', '唱': 'chang', '声': 'sheng',
    '音': 'yin', '等': 'deng', '待': 'dai', '谁': 'shui', '怎': 'zen', '么': 'me',
    '什': 'shen', '为': 'wei', '因': 'yin', '所': 'suo', '以': 'yi', '但': 'dan',
    '已': 'yi', '经': 'jing', '过': 'guo', '曾': 'ceng', '别': 'bie', '离': 'li',
    '痛': 'tong', '伤': 'shang', '醉': 'zui', '醒': 'xing', '希': 'xi', '望': 'wang',
    '孤': 'gu', '单': 'dan', '寂': 'ji', '寞': 'mo', '暖': 'nuan', '冷': 'leng',
    '温': 'wen', '柔': 'rou', '甜': 'tian', '蜜': 'mi', '苦': 'ku', '真': 'zhen',
    '好': 'hao', '多': 'duo', '少': 'shao', '快': 'kuai', '慢': 'man', '新': 'xin',
    '旧': 'jiu', '手': 'shou', '抱': 'bao', '吻': 'wen', '陪': 'pei', '伴': 'ban',
    '身': 'shen', '影': 'ying', '眼': 'yan', '眸': 'mou', '再': 'zai', '懂': 'dong',
    '念': 'nian', '思': 'si', '愿': 'yuan', '一': 'yi', '二': 'er', '三': 'san',
    '四': 'si', '五': 'wu', '六': 'liu', '七': 'qi', '八': 'ba', '九': 'jiu',
    '十': 'shi', '百': 'bai', '千': 'qian', '万': 'wan', '红': 'hong', '蓝': 'lan',
    '白': 'bai', '黑': 'hei', '黄': 'huang', '绿': 'lv', '金': 'jin', '银': 'yin',
    '大': 'da', '小': 'xiao', '高': 'gao', '低': 'di', '深': 'shen', '浅': 'qian',
    '远': 'yuan', '近': 'jin', '明': 'ming', '暗': 'an', '无': 'wu', '如': 'ru',
    '果': 'guo', '就': 'jiu', '让': 'rang', '被': 'bei', '给': 'gei', '把': 'ba',
    '到': 'dao', '从': 'cong', '向': 'xiang', '着': 'zhe', '起': 'qi', '落': 'luo',
    '开': 'kai', '关': 'guan', '停': 'ting', '留': 'liu', '飞': 'fei', '翔': 'xiang',
    '追': 'zhui', '逐': 'zhu', '忘': 'wang', '记': 'ji', '忆': 'yi', '知': 'zhi',
    '道': 'dao', '现': 'xian', '未': 'wei', '永': 'yong', '直': 'zhi', '都': 'dou',
    '只': 'zhi', '还': 'hai', '次': 'ci', '时': 'shi', '刻': 'ke', '分': 'fen',
    '秒': 'miao', '世': 'shi', '界': 'jie', '美': 'mei', '丽': 'li', '乐': 'le',
    '幸': 'xing', '福': 'fu', '悲': 'bei', '安': 'an', '静': 'jing', '喧': 'xuan',
    '闹': 'nao', '清': 'qing', '晰': 'xi', '模': 'mo', '糊': 'hu', '完': 'wan',
    '整': 'zheng', '碎': 'sui', '破': 'po', '裂': 'lie', '重': 'zhong', '轻': 'qing',
    '长': 'chang', '短': 'duan', '简': 'jian', '繁': 'fan', '复': 'fu', '始': 'shi',
    '终': 'zhong', '难': 'nan', '随': 'sui', '变': 'bian', '容': 'rong', '颜': 'yan',
    '昨': 'zuo', '今': 'jin', '晨': 'chen', '暮': 'mu', '依': 'yi', '寻': 'xun',
    '觅': 'mi', '彷': 'pang', '徨': 'huang', '迷': 'mi', '茫': 'mang', '执': 'zhi',
    '坚': 'jian', '强': 'qiang', '勇': 'yong', '敢': 'gan', '默': 'mo', '呼': 'hu',
    '吸': 'xi', '脉': 'mai', '搏': 'bo', '跳': 'tiao', '动': 'dong', '紧': 'jin',
    '握': 'wo', '拥': 'yong', '里': 'li',
  };

  // ---------------------------------------------------------------------------
  // Script Detection
  // ---------------------------------------------------------------------------

  /// Returns true if text contains Japanese Hiragana, Katakana, or Kanji
  static bool isJapanese(String text) {
    bool hasKana = false;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if ((code >= 0x3040 && code <= 0x309F) ||
          (code >= 0x30A0 && code <= 0x30FF)) {
        hasKana = true;
        break;
      }
    }
    return hasKana;
  }

  /// Returns true if text contains Hangul syllables
  static bool isKorean(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if text contains Chinese Hanzi without Japanese kana
  static bool isChinese(String text) {
    if (text.isEmpty) return false;
    if (isJapanese(text)) return false; // If it has kana, prioritize Japanese
    int hanziCount = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        hanziCount++;
      }
    }
    return hanziCount > 0;
  }

  /// Returns true if text contains Cyrillic characters
  static bool isCyrillic(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0400 && code <= 0x04FF) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if text contains Ukrainian-specific Cyrillic letters (Ґ, Є, І, Ї)
  static bool isUkrainian(String text) {
    const ukrLetters = 'ҐґЄєІіЇї';
    for (int i = 0; i < text.length; i++) {
      if (ukrLetters.contains(text[i])) return true;
    }
    return false;
  }

  /// Returns true if text is Cyrillic and does not contain Ukrainian-specific characters
  static bool isRussian(String text) {
    return isCyrillic(text) && !isUkrainian(text);
  }

  /// Returns true if text contains Indic scripts (Devanagari / Gurmukhi)
  static bool isIndic(String text) => ScriptRomanizer.hasRomanizableScript(text);

  /// Automatically identifies the predominant non-Latin script of the input text.
  static String? detectLanguage(String text) {
    if (isJapanese(text)) return 'Japanese';
    if (isKorean(text)) return 'Korean';
    if (isChinese(text)) return 'Chinese';
    if (isUkrainian(text)) return 'Ukrainian';
    if (isRussian(text)) return 'Russian';
    if (isIndic(text)) return 'Indic';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Transliteration Implementations
  // ---------------------------------------------------------------------------

  /// Transliterates Japanese text (Hiragana, Katakana, common Kanji) into Romaji.
  static String romanizeJapanese(String text) {
    if (text.isEmpty) return text;

    // 1. Substitute common Kanji words
    String processed = text;
    for (final entry in _japaneseKanjiWords.entries) {
      processed = processed.replaceAll(entry.key, '${entry.value} ');
    }

    // 2. Transliterate Kana
    final buffer = StringBuffer();
    final runes = processed.runes.toList();
    final n = runes.length;
    int i = 0;

    while (i < n) {
      final ch = String.fromCharCode(runes[i]);

      // Normalize Hiragana to Katakana
      final code = runes[i];
      final katakanaChar = (code >= 0x3041 && code <= 0x3096)
          ? String.fromCharCode(code + 0x60)
          : ch;

      // Check 2-character digraph (Yōon)
      if (i + 1 < n) {
        final nextCode = runes[i + 1];
        final nextKatakanaChar = (nextCode >= 0x3041 && nextCode <= 0x3096)
            ? String.fromCharCode(nextCode + 0x60)
            : String.fromCharCode(nextCode);

        final digraph = katakanaChar + nextKatakanaChar;
        if (_japaneseDigraphs.containsKey(digraph)) {
          buffer.write(_japaneseDigraphs[digraph]);
          i += 2;
          continue;
        }
      }

      // Check small tsu (sokuon: ッ or っ) -> double next consonant
      if (katakanaChar == 'ッ') {
        if (i + 1 < n) {
          final nextCode = runes[i + 1];
          final nextKatakana = (nextCode >= 0x3041 && nextCode <= 0x3096)
              ? String.fromCharCode(nextCode + 0x60)
              : String.fromCharCode(nextCode);
          final nextRomaji = _japaneseBasicKana[nextKatakana] ?? '';
          if (nextRomaji.isNotEmpty) {
            buffer.write(nextRomaji[0]);
          }
        }
        i++;
        continue;
      }

      // Check single Katakana
      if (_japaneseBasicKana.containsKey(katakanaChar)) {
        buffer.write(_japaneseBasicKana[katakanaChar]);
      } else {
        buffer.write(ch);
      }
      i++;
    }

    return _cleanupSpacing(buffer.toString());
  }

  /// Transliterates Korean Hangul into Latin script using Revised Romanization.
  static String romanizeKorean(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    final runes = text.runes.toList();
    final n = runes.length;

    String? prevFinalJamo;

    for (int i = 0; i < n; i++) {
      final code = runes[i];

      if (code >= 0xAC00 && code <= 0xD7A3) {
        final syllableIndex = code - 0xAC00;
        final choIndex = syllableIndex ~/ (21 * 28);
        final jungIndex = (syllableIndex % (21 * 28)) ~/ 28;
        final jongIndex = syllableIndex % 28;

        final choJamo = String.fromCharCode(0x1100 + choIndex);
        final jongJamo = jongIndex == 0 ? null : String.fromCharCode(0x11A7 + jongIndex);

        bool contextMatched = false;
        // Apply phonetic assimilation with previous syllable's final consonant
        if (prevFinalJamo != null) {
          final contextKey = prevFinalJamo + choJamo;
          if (_koreanAssimilation.containsKey(contextKey)) {
            buffer.write(_koreanAssimilation[contextKey]);
            contextMatched = true;
          } else {
            final assimilated = _koreanAssimilation[prevFinalJamo] ?? prevFinalJamo;
            buffer.write(assimilated);
          }
        }

        if (!contextMatched) {
          final choRomaji = _koreanCho[choIndex];
          buffer.write(choRomaji);
        }
        final jungRomaji = _koreanJung[jungIndex];
        buffer.write(jungRomaji);

        prevFinalJamo = jongJamo;
      } else {
        if (prevFinalJamo != null) {
          final assimilated = _koreanAssimilation[prevFinalJamo] ?? prevFinalJamo;
          buffer.write(assimilated);
          prevFinalJamo = null;
        }
        buffer.write(String.fromCharCode(code));
      }
    }

    if (prevFinalJamo != null) {
      final assimilated = _koreanAssimilation[prevFinalJamo] ?? prevFinalJamo;
      buffer.write(assimilated);
    }

    return buffer.toString();
  }

  /// Transliterates Chinese Hanzi characters into Pinyin.
  static String romanizeChinese(String text) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    final runes = text.runes.toList();
    final n = runes.length;

    for (int i = 0; i < n; i++) {
      final ch = String.fromCharCode(runes[i]);
      final pinyin = _chinesePinyin[ch];
      if (pinyin != null) {
        buffer.write(pinyin);
        buffer.write(' ');
      } else {
        buffer.write(ch);
      }
    }

    return _cleanupSpacing(buffer.toString());
  }

  /// Transliterates Russian Cyrillic into Latin alphabet.
  static String romanizeRussian(String text) => romanizeCyrillic(text, language: 'Russian');

  /// Transliterates Ukrainian Cyrillic into Latin alphabet.
  static String romanizeUkrainian(String text) => romanizeCyrillic(text, language: 'Ukrainian');

  /// Transliterates Cyrillic text into Latin script with Russian or Ukrainian grammar rules.
  static String romanizeCyrillic(String text, {String? language}) {
    if (text.isEmpty) return text;

    final isUkr = language == 'Ukrainian' || (language == null && isUkrainian(text));
    final buffer = StringBuffer();

    var i = 0;
    while (i < text.length) {
      // Check 3-char endings like -ого / -его in Russian
      if (!isUkr && i + 3 <= text.length) {
        final sub3 = text.substring(i, i + 3);
        final mapped = _russianEndings[sub3];
        if (mapped != null && (i + 3 == text.length || !RegExp(r'[a-zA-Zа-яА-Я]').hasMatch(text[i + 3]))) {
          buffer.write(mapped);
          i += 3;
          continue;
        }
      }

      final ch = text[i];

      // Ukrainian-specific character substitutions
      if (isUkr && _ukrainianSpecial.containsKey(ch)) {
        buffer.write(_ukrainianSpecial[ch]);
        i++;
        continue;
      }

      // Ukrainian iotation after consonant: Ю -> iu, Я -> ia
      if (isUkr && (ch == 'ю' || ch == 'я' || ch == 'Ю' || ch == 'Я')) {
        if (i > 0 && RegExp(r'[бвгґджзклмнпрстфхцчшщ]').hasMatch(text[i - 1].toLowerCase())) {
          if (ch == 'ю') {
            buffer.write('iu');
          } else if (ch == 'Ю') {
            buffer.write('Iu');
          } else if (ch == 'я') {
            buffer.write('ia');
          } else if (ch == 'Я') {
            buffer.write('Ia');
          }
          i++;
          continue;
        }
      }

      // Russian initial 'е' / 'Е' -> 'ye' / 'Ye'
      if (!isUkr && (ch == 'е' || ch == 'Е')) {
        final isWordStart = i == 0 || RegExp(r'\s|[.,!?;:()\[\]{}]').hasMatch(text[i - 1]);
        if (isWordStart) {
          buffer.write(ch == 'е' ? 'ye' : 'Ye');
          i++;
          continue;
        }
      }

      // General Cyrillic mapping
      if (_generalCyrillic.containsKey(ch)) {
        buffer.write(_generalCyrillic[ch]);
      } else {
        buffer.write(ch);
      }
      i++;
    }

    return buffer.toString();
  }

  /// General entry point: detects script automatically (or uses specified [language])
  /// and transliterates to phonetic Latin text.
  static String romanize(
    String text, {
    String? language,
    List<String>? enabledLanguages,
  }) {
    if (text.isEmpty) return text;

    final lang = language ?? detectLanguage(text);
    if (lang == null) return text;

    if (enabledLanguages != null && !enabledLanguages.contains(lang)) {
      return text;
    }

    switch (lang) {
      case 'Japanese':
        return romanizeJapanese(text);
      case 'Korean':
        return romanizeKorean(text);
      case 'Chinese':
        return romanizeChinese(text);
      case 'Ukrainian':
        return romanizeUkrainian(text);
      case 'Russian':
        return romanizeRussian(text);
      case 'Indic':
        return ScriptRomanizer.romanize(text);
      default:
        return text;
    }
  }

  /// Transliterates an entire [SyncedLyrics] model.
  /// If [asMain] is true, the primary line texts are replaced with romanized versions.
  static SyncedLyrics romanizeSyncedLyrics(
    SyncedLyrics lyrics, {
    bool asMain = true,
    List<String>? enabledLanguages,
  }) {
    final romanizedLines = lyrics.lines.map((line) {
      final romText = romanize(line.text, enabledLanguages: enabledLanguages);

      List<LyricWord>? romWords;
      if (line.words != null && line.words!.isNotEmpty) {
        romWords = line.words!.map((w) {
          final rw = romanize(w.text, enabledLanguages: enabledLanguages);
          return LyricWord(
            timestamp: w.timestamp,
            text: rw,
            duration: w.duration,
          );
        }).toList();
      }

      return LyricLine(
        timestamp: line.timestamp,
        text: asMain ? romText : line.text,
        words: asMain ? romWords : line.words,
        agent: line.agent,
      );
    }).toList();

    return SyncedLyrics(
      trackId: lyrics.trackId,
      lines: romanizedLines,
      plainLyrics: lyrics.plainLyrics != null
          ? romanize(lyrics.plainLyrics!, enabledLanguages: enabledLanguages)
          : null,
      rawLrc: lyrics.rawLrc,
      syncType: lyrics.syncType,
      providerName: '${lyrics.providerName ?? "Lyrics"} (Romanized)',
      colors: lyrics.colors,
    );
  }

  static String _cleanupSpacing(String text) {
    return text
        .replaceAll(RegExp(r'\s+([,.!?;:])'), r'$1')
        .replaceAll(RegExp(r'\s+([，。！？；：、（）《》〈〉【】『』「」])'), r'$1')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
