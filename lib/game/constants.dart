/// Общие константы игрового мира и сети.
library;

const double kTileSize = 48.0;
const double kPlayerRadius = 15.0;
const double kBaseSpeed = 232.0;
const double kMaxHp = 100.0;
const double kMaxShield = 60.0;
const double kVisionRadius = 312.0;
const double kGhostVisibleRadius = 150.0;

const int kDefaultMapSize = 61;
const List<int> kMapSizes = <int>[41, 61, 81];
const int kMapGenerationCount = 3;
const List<String> kMapGenerationNames = <String>[
  'Кварталы',
  'Коридоры',
  'Открытая',
];

const int kMaxPlayers = 8;
const int kGamePort = 47777;
const int kDiscoveryPort = 47780;
const int kProtocolVersion = 13;
const int kTeamSize = 2;
const int kDefaultRespawnDelay = 15;
const int kMinRespawnDelay = 5;
const int kMaxRespawnDelay = 60;
const double kHealthRegenPerSecond = 0.2;

const double kSimDt = 1.0 / 30.0;
const double kSnapshotInterval = 1.0 / 20.0;
const double kInputInterval = 1.0 / 30.0;

const int kCountdownSeconds = 5;

const List<String> kBotNames = <String>[
  'Тень',
  'Хаос',
  'Вихрь',
  'Кобра',
  'Призрак',
  'Шторм',
  'Клинок',
  'Рысь',
  'Фантом',
  'Гром',
  'Пепел',
  'Сойка',
  'Молот',
  'Змей',
  'Искра',
  'Туман',
];

const List<String> kNickAdjectives = <String>[
  'Хитрый',
  'Тёмный',
  'Быстрый',
  'Стальной',
  'Дикий',
  'Ночной',
  'Ледяной',
  'Рыжий',
  'Бешеный',
  'Тихий',
];

const List<String> kNickNouns = <String>[
  'Лис',
  'Волк',
  'Сокол',
  'Барс',
  'Ворон',
  'Кот',
  'Дракон',
  'Ёж',
  'Тигр',
  'Сурок',
];
