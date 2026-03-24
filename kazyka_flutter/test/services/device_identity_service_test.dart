import 'package:flutter_test/flutter_test.dart';
import 'package:kazyka/services/device_identity_service.dart';

void main() {
  group('isValidJoinCode', () {
    test('accepts valid 6-char code', () {
      expect(isValidJoinCode('ABCD92'), isTrue);
      expect(isValidJoinCode('XYZW38'), isTrue);
      expect(isValidJoinCode('HJKLMN'), isTrue);
      expect(isValidJoinCode('234567'), isTrue);
    });

    test('rejects wrong length', () {
      expect(isValidJoinCode(''), isFalse);
      expect(isValidJoinCode('ABC'), isFalse);
      expect(isValidJoinCode('ABCDE'), isFalse);
      expect(isValidJoinCode('ABCDEFG'), isFalse);
    });

    test('rejects ambiguous characters O, 0, I, 1', () {
      expect(isValidJoinCode('OABCDE'), isFalse);
      expect(isValidJoinCode('0ABCDE'), isFalse);
      expect(isValidJoinCode('IABCDE'), isFalse);
      expect(isValidJoinCode('1ABCDE'), isFalse);
    });

    test('rejects lowercase', () {
      expect(isValidJoinCode('abcd92'), isFalse);
    });

    test('rejects special characters', () {
      expect(isValidJoinCode('ABC-92'), isFalse);
      expect(isValidJoinCode('ABC 92'), isFalse);
    });
  });

  group('DeviceIdentityService', () {
    test('deviceLabel returns last 4 chars uppercased', () {
      final service = DeviceIdentityService();
      // Before init, deviceId is 'unknown'
      expect(service.deviceLabel, 'NOWN');
    });

    test('displayName defaults to empty', () {
      final service = DeviceIdentityService();
      expect(service.displayName, '');
    });
  });
}
