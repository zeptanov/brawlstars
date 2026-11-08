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
}
