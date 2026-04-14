import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kirimi/kirimi.dart';
import 'package:test/test.dart';

// Helpers
http.Response _jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  const userCode = 'TEST_USER';
  const secret = 'TEST_SECRET';

  group('sendMessage', () {
    test('sends correct body fields', () async {
      Map<String, dynamic>? captured;

      final mock = MockClient((request) async {
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'success': true, 'data': null, 'message': 'ok'});
      });

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      final resp = await client.sendMessage(
        deviceId: 'DEV1',
        phone: '6281234567890',
        message: 'hello world',
      );

      expect(resp.success, isTrue);
      expect(resp.message, equals('ok'));
      expect(captured!['user_code'], equals(userCode));
      expect(captured!['secret'], equals(secret));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['phone'], equals('6281234567890'));
      expect(captured!['message'], equals('hello world'));
      expect(captured!.containsKey('media_url'), isFalse);

      client.close();
    });

    test('includes media_url when provided', () async {
      Map<String, dynamic>? captured;

      final mock = MockClient((request) async {
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'success': true});
      });

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      await client.sendMessage(
        deviceId: 'DEV1',
        phone: '628xxx',
        message: 'see attached',
        mediaUrl: 'https://example.com/img.jpg',
      );

      expect(captured!['media_url'], equals('https://example.com/img.jpg'));
      client.close();
    });
  });

  group('generateOtp', () {
    test('sends required fields without optional params', () async {
      Map<String, dynamic>? captured;

      final mock = MockClient((request) async {
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'success': true, 'data': {'otp': '123456'}});
      });

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      final resp = await client.generateOtp(
        deviceId: 'DEV1',
        phone: '628xxx',
      );

      expect(resp.success, isTrue);
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['phone'], equals('628xxx'));
      expect(captured!.containsKey('otp_length'), isFalse);
      expect(captured!.containsKey('otp_type'), isFalse);
      expect(captured!.containsKey('customOtpMessage'), isFalse);
      client.close();
    });

    test('sends optional params when provided', () async {
      Map<String, dynamic>? captured;

      final mock = MockClient((request) async {
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'success': true});
      });

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      await client.generateOtp(
        deviceId: 'DEV1',
        phone: '628xxx',
        otpLength: 6,
        otpType: 'numeric',
        customOtpMessage: 'Your code is {otp}',
      );

      expect(captured!['otp_length'], equals(6));
      expect(captured!['otp_type'], equals('numeric'));
      expect(captured!['customOtpMessage'], equals('Your code is {otp}'));
      client.close();
    });
  });

  group('error handling', () {
    test('throws KirimiApiException on 401', () async {
      final mock = MockClient((request) async =>
          _jsonResponse({'success': false, 'message': 'Unauthorized'}, status: 401));

      final client = KirimiClient(
        userCode: 'bad',
        secret: 'bad',
        httpClient: mock,
      );

      expect(
        () => client.sendMessage(
          deviceId: 'DEV1',
          phone: '628xxx',
          message: 'test',
        ),
        throwsA(isA<KirimiApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          equals(401),
        )),
      );

      client.close();
    });

    test('throws KirimiApiException on 500', () async {
      final mock = MockClient((request) async =>
          _jsonResponse({'success': false, 'message': 'Server Error'}, status: 500));

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      expect(
        () => client.listDevices(),
        throwsA(isA<KirimiApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          equals(500),
        )),
      );

      client.close();
    });
  });

  group('broadcastMessage', () {
    test('joins List<String> phones with comma', () async {
      Map<String, dynamic>? captured;

      final mock = MockClient((request) async {
        captured = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({'success': true});
      });

      final client = KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

      await client.broadcastMessage(
        deviceId: 'DEV1',
        phones: ['628111', '628222', '628333'],
        message: 'promo!',
      );

      expect(captured!['phones'], equals('628111,628222,628333'));
      client.close();
    });
  });
}
