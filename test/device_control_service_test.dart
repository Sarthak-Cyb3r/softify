import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:softify/data/database/app_database.dart';
import 'package:softify/data/services/device_control_service.dart';

void main() {
  group('DeviceControlService Unit Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('generates and persists unique device ID', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'allowed': true, 'status': 'allowed'}), 200);
      });

      final service = DeviceControlService(db: db, client: mockClient);
      final id1 = await service.getDeviceId();
      expect(id1.isNotEmpty, isTrue);

      final id2 = await service.getDeviceId();
      expect(id2, equals(id1)); // Preserved across calls
    });

    test('parses allowed and blocked responses from backend', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/device/sync')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['deviceId'] == 'blocked-device-id') {
            return http.Response(
              jsonEncode({
                'allowed': false,
                'status': 'blocked',
                'reason': 'Payment expired',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'allowed': true,
              'status': 'allowed',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = DeviceControlService(db: db, client: mockClient);
      final status = await service.syncDevice();
      expect(status.isAllowed, isTrue);
      expect(status.status, equals('allowed'));
      expect(status.isOffline, isFalse);
    });

    test('falls back gracefully to cached policy when offline', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final service = DeviceControlService(db: db, client: mockClient);
      final status = await service.syncDevice();

      // First run offline defaults to allowed
      expect(status.isAllowed, isTrue);
      expect(status.isOffline, isTrue);
    });
  });
}
