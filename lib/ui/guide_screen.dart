import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/weapons.dart';
import 'widgets.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final Set<int> _completedLessons = <int>{};

  static const List<_Lesson> _lessons = <_Lesson>[
    _Lesson(
      icon: Icons.directions_run_rounded,
      title: 'Осмотрись и двигайся',
      text: 'Пробеги по коридору и запомни путь к безопасной открытой зоне.',
    ),
    _Lesson(
      icon: Icons.gps_fixed_rounded,
      title: 'Наведи прицел и стреляй',
      text: 'Потренируй прицеливание по мыши или правому сенсорному стику.',
    ),
    _Lesson(
      icon: Icons.inventory_2_outlined,
      title: 'Подбери бонус',
      text: 'Найди аптечку, щит или оружие и проверь, как изменился HUD.',
    ),
    _Lesson(
      icon: Icons.my_location_rounded,
      title: 'Следи за зоной',
      text: 'Сверься с мини-картой и переместись внутрь безопасной зоны.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final progress = _completedLessons.length / _lessons.length;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const NeonBackground(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Palette.accent,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'ГАЙД И ОБУЧЕНИЕ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            NeonPanel(
                              padding: const EdgeInsets.all(22),
                              glow: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  Pill(
                                    text: 'ЦЕЛЬ МАТЧА',
                                    icon: Icons.emoji_events_outlined,
                                    color: Palette.gold,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Выживи в лабиринте',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Исследуй процедурную арену, находи оружие и '
                                    'бонусы, побеждай соперников и не попадай под '
                                    'сужающуюся зону. Туман войны скрывает игроков '
                                    'за пределами обзора и стенами, поэтому выбирай '
                                    'маршрут с умом. В одиночном режиме выигрывает '
                                    'последний выживший, в командном — команда, '
                                    'в которой остался боец.',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.55,
                                      color: Palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _GuideSection(
                              title: 'Как устроен матч',
                              icon: Icons.map_outlined,
                              children: <Widget>[
                                _GuideItem(
                                  icon: Icons.visibility_outlined,
                                  title: 'Исследуй',
                                  text:
                                      'Видна только часть карты вокруг тебя. '
                                      'Стены блокируют обзор и выстрелы.',
                                ),
                                _GuideItem(
                                  icon: Icons.backpack_outlined,
                                  title: 'Подготовься',
                                  text:
                                      'Подбирай оружие, лечись и используй '
                                      'временные бонусы в подходящий момент.',
                                ),
                                _GuideItem(
                                  icon: Icons.warning_amber_rounded,
                                  title: 'Держись в зоне',
                                  text:
                                      'Безопасная область постепенно уменьшается. '
                                      'За её пределами здоровье убывает.',
                                ),
                                _GuideItem(
                                  icon: Icons.groups_2_outlined,
                                  title: 'Играй по формату',
                                  text:
                                      'В режиме «Команды 2×2» союзники не наносят '
                                      'урон друг другу, если хост не включил '
                                      'дружественный огонь.',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _GuideSection(
                              title: 'Оружие',
                              icon: Icons.gps_fixed_rounded,
                              children: <Widget>[
                                _GuideItem(
                                  icon: Icons.sports_handball_rounded,
                                  title: kWeapons[0].name,
                                  text:
                                      'Стартовое оружие. ${kWeapons[0].damage} '
                                      'урона за попадание, магазин '
                                      '${kWeapons[0].magSize} патронов.',
                                ),
                                _GuideItem(
                                  icon: Icons.bolt_rounded,
                                  title: kWeapons[1].name,
                                  text:
                                      'Автоматический ближний/средний бой: '
                                      '${kWeapons[1].damage} урона за пулю, '
                                      '${kWeapons[1].magSize} патронов.',
                                ),
                                _GuideItem(
                                  icon: Icons.grain_rounded,
                                  title: kWeapons[2].name,
                                  text:
                                      'На близкой дистанции выпускает '
                                      '${kWeapons[2].pellets} дробин по '
                                      '${kWeapons[2].damage} урона каждая. '
                                      'В магазине ${kWeapons[2].magSize} выстрелов.',
                                ),
                                _GuideItem(
                                  icon: Icons.straighten_rounded,
                                  title: kWeapons[3].name,
                                  text:
                                      'Точный универсальный автомат: '
                                      '${kWeapons[3].damage} урона, '
                                      '${kWeapons[3].magSize} патронов.',
                                ),
                                _GuideItem(
                                  icon: Icons.center_focus_strong_rounded,
                                  title: kWeapons[4].name,
                                  text:
                                      'Медленный, но мощный точный выстрел: '
                                      '${kWeapons[4].damage} урона. В магазине '
                                      '${kWeapons[4].magSize} патрона.',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const _GuideSection(
                              title: 'Бонусы и снаряжение',
                              icon: Icons.auto_awesome_outlined,
                              children: <Widget>[
                                _GuideItem(
                                  icon: Icons.favorite_rounded,
                                  title: 'Аптечка',
                                  text:
                                      '+45 здоровья, но не выше максимума '
                                      '(100 HP). Не трать её при полном здоровье.',
                                  color: Color(0xFF64F5A4),
                                ),
                                _GuideItem(
                                  icon: Icons.shield_rounded,
                                  title: 'Щит',
                                  text:
                                      'Добавляет 40 единиц щита, максимум — '
                                      '60. Щит поглощает урон раньше здоровья.',
                                  color: Color(0xFF7FB2FF),
                                ),
                                _GuideItem(
                                  icon: Icons.speed_rounded,
                                  title: 'Ускорение',
                                  text:
                                      'Увеличивает скорость передвижения на 32% '
                                      'в течение 12 секунд.',
                                  color: Palette.gold,
                                ),
                                _GuideItem(
                                  icon: Icons.radar_rounded,
                                  title: 'Радар',
                                  text:
                                      'На 10 секунд показывает направление и '
                                      'дистанцию до ближайшего врага.',
                                  color: Color(0xFFFF9F5A),
                                ),
                                _GuideItem(
                                  icon: Icons.blur_on_rounded,
                                  title: 'Маскировка',
                                  text:
                                      'На 7 секунд скрывает тебя от дальнего '
                                      'обзора соперников. Вблизи тебя всё ещё '
                                      'можно заметить.',
                                  color: Color(0xFFC792FF),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const _GuideSection(
                              title: 'Управление',
                              icon: Icons.gamepad_outlined,
                              children: <Widget>[
                                _GuideItem(
                                  icon: Icons.keyboard_outlined,
                                  title: 'Клавиатура и мышь',
                                  text:
                                      'WASD или стрелки — движение; мышь — '
                                      'прицел; ЛКМ или пробел — огонь; Shift — '
                                      'рывок; R — перезарядка; Tab — таблица; '
                                      'Esc — меню.',
                                ),
                                _GuideItem(
                                  icon: Icons.touch_app_outlined,
                                  title: 'Сенсорный экран',
                                  text:
                                      'Левый стик — движение; правый — прицел '
                                      'и стрельба. Кнопки справа отвечают за '
                                      'рывок и перезарядку.',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            NeonPanel(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const SectionLabel(
                                    'Мини-обучение',
                                    trailing: Icon(
                                      Icons.school_outlined,
                                      size: 18,
                                      color: Palette.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  const Text(
                                    'Пройди эти короткие задания в тренировочном матче.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Palette.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 5,
                                      backgroundColor: Palette.line,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Palette.accent,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_completedLessons.length} из ${_lessons.length} заданий выполнено',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Palette.mutedDark,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  for (var i = 0; i < _lessons.length; i++)
                                    _LessonTile(
                                      lesson: _lessons[i],
                                      completed: _completedLessons.contains(i),
                                      onToggle: () => setState(() {
                                        if (!_completedLessons.add(i)) {
                                          _completedLessons.remove(i);
                                        }
                                      }),
                                    ),
                                  if (_completedLessons.length ==
                                      _lessons.length) ...<Widget>[
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 17,
                                          color: Palette.accent,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Отлично! Ты готов к матчу.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Palette.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Совет: после перестрелки смени позицию, следи за '
                              'таймером зоны и перезаряжайся в укрытии.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Palette.mutedDark,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(
            title,
            trailing: Icon(icon, size: 18, color: Palette.accent),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.text,
    this.color = Palette.accent,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Lesson {
  const _Lesson({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.completed,
    required this.onToggle,
  });

  final _Lesson lesson;
  final bool completed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Palette.surfaceAlt.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: completed
                ? Palette.accent.withValues(alpha: 0.45)
                : Palette.line,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(lesson.icon, size: 19, color: Palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.text,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 17,
              ),
              label: Text(completed ? 'Готово' : 'Отметить'),
            ),
          ],
        ),
      ),
    );
  }
}
