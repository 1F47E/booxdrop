import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kazyka/main.dart';
import 'package:kazyka/services/device_identity_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches and shows drawing screen', (tester) async {
    final identity = DeviceIdentityService();
    await tester.pumpWidget(KazykaApp(identity: identity));
    await tester.pumpAndSettle();

    expect(find.text('Kazyka'), findsOneWidget);
  });
}
