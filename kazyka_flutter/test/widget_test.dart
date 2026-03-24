import 'package:flutter_test/flutter_test.dart';
import 'package:kazyka/main.dart';
import 'package:kazyka/services/device_identity_service.dart';

void main() {
  testWidgets('App starts with drawing screen', (WidgetTester tester) async {
    final identity = DeviceIdentityService();
    await tester.pumpWidget(KazykaApp(identity: identity));
    await tester.pumpAndSettle();
    expect(find.text('Kazyka'), findsOneWidget);
  });
}
