import 'weapons.dart';

/// Всё, что можно подобрать на карте. Индекс — сетевой id.
enum PickupType {
  smg,
  shotgun,
  rifle,
  sniper,
  medkit,
  shield,
  speed,
  radar,
  ghost,
}

class PickupDef {
  const PickupDef({
    required this.type,
    required this.name,
    required this.glyph,
    required this.color,
    this.weapon,
    this.weight,
  });

  final PickupType type;
  final String name;
  final String glyph;
  final int color;
  final WeaponId? weapon;
  final int? weight;
}

const List<PickupDef> kPickups = <PickupDef>[
  PickupDef(
    type: PickupType.smg,
    name: 'ПП «Шершень»',
    glyph: 'П',
    color: 0xFF5BE7FF,
    weapon: WeaponId.smg,
    weight: 16,
  ),
  PickupDef(
    type: PickupType.shotgun,
    name: 'Дробовик «Кабан»',
    glyph: 'Д',
    color: 0xFFFF8A5B,
    weapon: WeaponId.shotgun,
    weight: 14,
  ),
  PickupDef(
    type: PickupType.rifle,
    name: 'Винтовка «Рысь»',
    glyph: 'В',
    color: 0xFF9BFF6B,
    weapon: WeaponId.rifle,
    weight: 11,
  ),
  PickupDef(
    type: PickupType.sniper,
    name: 'Снайперка «Гром»',
    glyph: 'С',
    color: 0xFFFF5BD1,
    weapon: WeaponId.sniper,
    weight: 5,
  ),
  PickupDef(
    type: PickupType.medkit,
    name: 'Аптечка',
    glyph: '+',
    color: 0xFF64F5A4,
    weight: 22,
  ),
  PickupDef(
    type: PickupType.shield,
    name: 'Щит',
    glyph: 'Щ',
    color: 0xFF7FB2FF,
    weight: 14,
  ),
  PickupDef(
    type: PickupType.speed,
    name: 'Ускорение',
    glyph: '»',
    color: 0xFFFFE066,
    weight: 9,
  ),
  PickupDef(
    type: PickupType.radar,
    name: 'Радар',
    glyph: 'Р',
    color: 0xFFFF9F5A,
    weight: 7,
  ),
  PickupDef(
    type: PickupType.ghost,
    name: 'Маскировка',
    glyph: 'М',
    color: 0xFFC792FF,
    weight: 6,
  ),
];

PickupDef pickupByIndex(int index) =>
    kPickups[index.clamp(0, kPickups.length - 1)];

int pickupIndexOf(PickupType type) => type.index;
