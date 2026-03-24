import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kazyka/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows drawing screen', (tester) async {
    await tester.pumpWidget(const KazykaApp());
    await tester.pumpAndSettle();

    // Verify app title is shown
    expect(find.text('Kazyka'), findsOneWidget);
  });
}
