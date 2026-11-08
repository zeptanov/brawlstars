import 'dart:math' as math;

/// Оружие. Индекс в списке [kWeapons] — это и есть сетевой id.
enum WeaponId { pistol, smg, shotgun, rifle, sniper }

class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.name,
    required this.short,
    required this.damage,
    required this.fireInterval,
    required this.pellets,
    required this.spread,
    required this.magSize,
    required this.reloadTime,
    required this.bulletSpeed,
    required this.range,
    required this.automatic,
    required this.color,
    required this.rarity,
  });

  final WeaponId id;
  final String name;
  final String short;
  final double damage;
  final double fireInterval;
  final int pellets;
  final double spread;
  final int magSize;
  final double reloadTime;
  final double bulletSpeed;
  final double range;
  final bool automatic;
  final int color;
  final int rarity;

  double get dps => damage * pellets / math.max(fireInterval, 0.01);
}

const List<WeaponDef> kWeapons = <WeaponDef>[
  WeaponDef(
    id: WeaponId.pistol,
    name: 'Пистолет «Оса»',
    short: 'Пистолет',
    damage: 17,
    fireInterval: 0.27,
    pellets: 1,
    spread: 0.03,
    magSize: 12,
    reloadTime: 1.05,
    bulletSpeed: 1080,
    range: 900,
    automatic: true,
    color: 0xFFFFD166,
    rarity: 0,
  ),
  WeaponDef(
    id: WeaponId.smg,
    name: 'ПП «Шершень»',
    short: 'ПП',
    damage: 8.5,
    fireInterval: 0.082,
    pellets: 1,
    spread: 0.115,
    magSize: 30,
    reloadTime: 1.45,
    bulletSpeed: 1010,
    range: 620,
    automatic: true,
    color: 0xFF5BE7FF,
    rarity: 1,
  ),
  WeaponDef(
    id: WeaponId.shotgun,
    name: 'Дробовик «Кабан»',
    short: 'Дробовик',
    damage: 9,
    fireInterval: 0.88,
    pellets: 6,
    spread: 0.30,
    magSize: 5,
    reloadTime: 1.95,
    bulletSpeed: 940,
    range: 400,
    automatic: false,
    color: 0xFFFF8A5B,
    rarity: 1,
  ),
  WeaponDef(
    id: WeaponId.rifle,
    name: 'Винтовка «Рысь»',
    short: 'Винтовка',
    damage: 22,
    fireInterval: 0.155,
    pellets: 1,
    spread: 0.045,
    magSize: 24,
    reloadTime: 1.65,
    bulletSpeed: 1320,
    range: 1150,
    automatic: true,
    color: 0xFF9BFF6B,
    rarity: 2,
  ),
  WeaponDef(
    id: WeaponId.sniper,
    name: 'Снайперка «Гром»',
    short: 'Снайперка',
    damage: 72,
    fireInterval: 1.05,
    pellets: 1,
    spread: 0.0035,
    magSize: 4,
    reloadTime: 2.1,
    bulletSpeed: 2300,
    range: 2100,
    automatic: false,
    color: 0xFFFF5BD1,
    rarity: 3,
  ),
];

WeaponDef weaponByIndex(int index) =>
    kWeapons[index.clamp(0, kWeapons.length - 1)];

int weaponIndexOf(WeaponId id) => id.index;
