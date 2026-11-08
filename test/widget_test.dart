import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/main.dart';

void main() {
  testWidgets('главное меню запускается и показывает логотип', (tester) async {
    await tester.pumpWidget(const MazeRoyaleApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('MAZE\nROYALE'), findsOneWidget);
    expect(find.text('СОЗДАТЬ КОМНАТУ'), findsOneWidget);
    expect(find.text('ТРЕНИРОВКА С БОТАМИ'), findsOneWidget);
  });

  testWidgets('гайд открывается и позволяет отмечать задания обучения', (
    tester,
  ) async {
    await tester.pumpWidget(const MazeRoyaleApp());
    await tester.ensureVisible(find.text('Как играть'));
    await tester.tap(find.text('Как играть'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('ГАЙД И ОБУЧЕНИЕ'), findsOneWidget);
    expect(find.text('БОНУСЫ И СНАРЯЖЕНИЕ'), findsOneWidget);
    expect(find.text('МИНИ-ОБУЧЕНИЕ'), findsOneWidget);

    await tester.ensureVisible(find.text('Отметить').first);
    await tester.tap(find.text('Отметить').first);
    await tester.pump();
    expect(find.text('Готово'), findsOneWidget);
  });
}
