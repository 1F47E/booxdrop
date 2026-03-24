import 'package:flutter_test/flutter_test.dart';
import 'package:kazyka/main.dart';

void main() {
  testWidgets('App starts with drawing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const KazykaApp());
    expect(find.text('Kazyka'), findsOneWidget);
  });
}
