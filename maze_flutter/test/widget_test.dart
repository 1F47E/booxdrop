import 'package:flutter_test/flutter_test.dart';
import 'package:maze_race/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const MazeRaceApp());
    expect(find.text('Maze Race'), findsOneWidget);
  });
}
