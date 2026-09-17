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

  Map<String, dynamic>? captured;
  late Uri capturedUrl;

  KirimiClient clientWith(MockClient mock) => KirimiClient(
        userCode: userCode,
        secret: secret,
        httpClient: mock,
      );

  MockClient capturingMock({Map<String, dynamic>? body}) {
    return MockClient((request) async {
      capturedUrl = request.url;
      captured = jsonDecode(request.body) as Map<String, dynamic>;
      return _jsonResponse(
          body ?? {'success': true, 'data': null, 'message': 'ok'});
    });
  }

  setUp(() {
    captured = null;
  });

  group('sendMessage', () {
    test('sends receiver and never phone', () async {
      final client = clientWith(capturingMock());

      final resp = await client.sendMessage(
        deviceId: 'DEV1',
        receiver: '6281234567890',
        message: 'hello world',
      );

      expect(resp.success, isTrue);
      expect(resp.message, equals('ok'));
      expect(capturedUrl.path, equals('/v1/send-message'));
      expect(captured!['user_code'], equals(userCode));
      expect(captured!['secret'], equals(secret));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['receiver'], equals('6281234567890'));
      expect(captured!.containsKey('phone'), isFalse);
      expect(captured!['message'], equals('hello world'));
      expect(captured!.containsKey('media_url'), isFalse);
      expect(captured!.containsKey('fileName'), isFalse);

      client.close();
    });

    test('includes optional fields when provided', () async {
      final client = clientWith(capturingMock());

      await client.sendMessage(
        deviceId: 'DEV1',
        receiver: '628xxx',
        message: 'see attached',
        mediaUrl: 'https://example.com/img.jpg',
        fileName: 'img.jpg',
        enableTypingEffect: false,
        typingSpeedMs: 200,
        quotedMessageId: 'QID1',
      );

      expect(captured!['media_url'], equals('https://example.com/img.jpg'));
      expect(captured!['fileName'], equals('img.jpg'));
      expect(captured!['enableTypingEffect'], isFalse);
      expect(captured!['typingSpeedMs'], equals(200));
      expect(captured!['quotedMessageId'], equals('QID1'));
      client.close();
    });
  });

  group('sendMessageFast', () {
    test('sends receiver and never phone', () async {
      final client = clientWith(capturingMock());

      await client.sendMessageFast(
        deviceId: 'DEV1',
        receiver: '628999',
        message: 'fast!',
      );

      expect(capturedUrl.path, equals('/v1/send-message-fast'));
      expect(captured!['receiver'], equals('628999'));
      expect(captured!.containsKey('phone'), isFalse);
      expect(captured!['message'], equals('fast!'));
      client.close();
    });
  });

  group('sendMessageFile', () {
    test('sends receiver in multipart fields', () async {
      late Map<String, String> fields;
      late http.MultipartRequest mpr;

      final mock = MockClient.streaming((request, bodyStream) async {
        mpr = request as http.MultipartRequest;
        fields = mpr.fields;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'success': true,
            'data': null,
            'message': 'ok',
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = clientWith(mock);

      final resp = await client.sendMessageFile(
        deviceId: 'DEV1',
        receiver: '628777',
        fileBytes: [1, 2, 3],
        fileName: 'doc.pdf',
        message: 'caption here',
      );

      expect(resp.success, isTrue);
      expect(fields['receiver'], equals('628777'));
      expect(fields.containsKey('phone'), isFalse);
      expect(fields['device_id'], equals('DEV1'));
      expect(fields['fileName'], equals('doc.pdf'));
      expect(fields['message'], equals('caption here'));
      expect(mpr.files.first.field, equals('file'));
      client.close();
    });
  });

  group('broadcastMessage', () {
    test('sends numbers as a List and requires label', () async {
      final client = clientWith(capturingMock());

      await client.broadcastMessage(
        deviceId: 'DEV1',
        label: 'promo-juli',
        numbers: ['628111', '628222', '628333'],
        message: 'promo!',
      );

      expect(capturedUrl.path, equals('/v1/broadcast-message'));
      expect(captured!['numbers'], isA<List<dynamic>>());
      expect(captured!['numbers'], equals(['628111', '628222', '628333']));
      expect(captured!.containsKey('phones'), isFalse);
      expect(captured!['label'], equals('promo-juli'));
      expect(captured!['message'], equals('promo!'));
      client.close();
    });

    test('sends optional scheduling and download params', () async {
      final client = clientWith(capturingMock());

      await client.broadcastMessage(
        deviceId: 'DEV1',
        label: 'promo',
        numbers: ['628111'],
        message: 'hi',
        delay: 30,
        delayMin: 30,
        delayMax: 120,
        mediaUrl: 'https://example.com/a.jpg',
        fileName: 'a.jpg',
        startedAt: '2026-01-01T00:00:00Z',
        enableTypingEffect: true,
        typingSpeedMs: 350,
      );

      expect(captured!['delay'], equals(30));
      expect(captured!['delayMin'], equals(30));
      expect(captured!['delayMax'], equals(120));
      expect(captured!['media_url'], equals('https://example.com/a.jpg'));
      expect(captured!['fileName'], equals('a.jpg'));
      expect(captured!['started_at'], equals('2026-01-01T00:00:00Z'));
      expect(captured!['enableTypingEffect'], isTrue);
      expect(captured!['typingSpeedMs'], equals(350));
      client.close();
    });
  });

  group('WABA', () {
    test('sendWabaMessage sends waba_id, to, template_name', () async {
      final client = clientWith(capturingMock());

      await client.sendWabaMessage(
        wabaId: 'WABA1',
        to: '6281234567890',
        templateName: 'hello_world',
        variables: ['Andi', '12345'],
        header: WabaTemplateHeader(
          type: 'document',
          link: 'https://example.com/doc.pdf',
          filename: 'doc.pdf',
        ),
        buttons: [
          {'type': 'url', 'url': 'https://example.com'}
        ],
      );

      expect(capturedUrl.path, equals('/v1/waba/send-message'));
      expect(captured!['waba_id'], equals('WABA1'));
      expect(captured!['to'], equals('6281234567890'));
      expect(captured!['template_name'], equals('hello_world'));
      expect(captured!['variables'], equals(['Andi', '12345']));
      expect(captured!['header'], equals({
        'type': 'document',
        'link': 'https://example.com/doc.pdf',
        'filename': 'doc.pdf',
      }));
      expect(captured!['buttons'], hasLength(1));
      expect(captured!.containsKey('device_id'), isFalse);
      expect(captured!.containsKey('phone'), isFalse);
      expect(captured!.containsKey('message'), isFalse);
      client.close();
    });

    test('sendWabaMessage omits optional fields', () async {
      final client = clientWith(capturingMock());

      await client.sendWabaMessage(
        wabaId: 'WABA1',
        to: '628xxx',
        templateName: 'otp_template',
      );

      expect(captured!.containsKey('variables'), isFalse);
      expect(captured!.containsKey('header'), isFalse);
      expect(captured!.containsKey('buttons'), isFalse);
      client.close();
    });

    test('wabaReply sends nested message object', () async {
      final client = clientWith(capturingMock());

      await client.wabaReply(
        wabaId: 'WABA1',
        to: '628111',
        message: WabaReplyMessage.text('halo').toJson(),
      );

      expect(capturedUrl.path, equals('/v1/waba/messages/reply'));
      expect(captured!['waba_id'], equals('WABA1'));
      expect(captured!['to'], equals('628111'));
      expect(captured!['message'], equals({'type': 'text', 'text': 'halo'}));
      client.close();
    });

    test('wabaConversations sends pagination', () async {
      final client = clientWith(capturingMock());

      await client.wabaConversations(limit: 20, page: 2);

      expect(capturedUrl.path, equals('/v1/waba/conversations'));
      expect(captured!['limit'], equals(20));
      expect(captured!['page'], equals(2));
      client.close();
    });

    test('wabaConversations omits pagination when absent', () async {
      final client = clientWith(capturingMock());

      await client.wabaConversations();

      expect(captured!.containsKey('limit'), isFalse);
      expect(captured!.containsKey('page'), isFalse);
      client.close();
    });

    test('wabaTemplatesSync sends waba_id', () async {
      final client = clientWith(capturingMock());

      await client.wabaTemplatesSync(wabaId: 'WABA9');

      expect(capturedUrl.path, equals('/v1/waba/templates/sync'));
      expect(captured!['waba_id'], equals('WABA9'));
      client.close();
    });

    test('wabaSendOtp sends waba_id, to, template_name', () async {
      final client = clientWith(capturingMock());

      await client.wabaSendOtp(
        wabaId: 'WABA1',
        to: '628222',
        templateName: 'otp_auth',
      );

      expect(capturedUrl.path, equals('/v1/waba/send-otp'));
      expect(captured!['waba_id'], equals('WABA1'));
      expect(captured!['to'], equals('628222'));
      expect(captured!['template_name'], equals('otp_auth'));
      client.close();
    });

    test('wabaVerifyOtp sends waba_id, to, otp_code', () async {
      final client = clientWith(capturingMock());

      await client.wabaVerifyOtp(
        wabaId: 'WABA1',
        to: '628222',
        otpCode: '123456',
      );

      expect(capturedUrl.path, equals('/v1/waba/verify-otp'));
      expect(captured!['waba_id'], equals('WABA1'));
      expect(captured!['to'], equals('628222'));
      expect(captured!['otp_code'], equals('123456'));
      client.close();
    });
  });

  group('devices', () {
    test('createDevice sends package_id and voucher_code', () async {
      final client = clientWith(capturingMock());

      await client.createDevice(packageId: 12, voucherCode: 'DISC10');

      expect(capturedUrl.path, equals('/v1/create-device'));
      expect(captured!['package_id'], equals(12));
      expect(captured!['voucher_code'], equals('DISC10'));
      client.close();
    });

    test('createDevice omits voucher_code when absent', () async {
      final client = clientWith(capturingMock());

      await client.createDevice(packageId: 'pkg-1');

      expect(captured!['package_id'], equals('pkg-1'));
      expect(captured!.containsKey('voucher_code'), isFalse);
      client.close();
    });

    test('connectDevice sends device_id', () async {
      final client = clientWith(capturingMock());

      await client.connectDevice(deviceId: 'DEV1');

      expect(capturedUrl.path, equals('/v1/connect-device'));
      expect(captured!['device_id'], equals('DEV1'));
      client.close();
    });

    test('renewDevice sends device_id, package_id, voucher_code', () async {
      final client = clientWith(capturingMock());

      await client.renewDevice(
        deviceId: 'DEV1',
        packageId: 3,
        voucherCode: 'VCH',
      );

      expect(capturedUrl.path, equals('/v1/renew-device'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['package_id'], equals(3));
      expect(captured!['voucher_code'], equals('VCH'));
      client.close();
    });

    test('listDevices sends pagination', () async {
      final client = clientWith(capturingMock());

      await client.listDevices(page: 1, limit: 10);

      expect(capturedUrl.path, equals('/v1/list-devices'));
      expect(captured!['page'], equals(1));
      expect(captured!['limit'], equals(10));
      client.close();
    });

    test('listDevices omits pagination when absent', () async {
      final client = clientWith(capturingMock());

      await client.listDevices();

      expect(captured!.containsKey('page'), isFalse);
      expect(captured!.containsKey('limit'), isFalse);
      client.close();
    });

    test('deviceStatus and deviceStatusEnhanced send device_id', () async {
      final client = clientWith(capturingMock());

      await client.deviceStatus(deviceId: 'DEV1');
      expect(capturedUrl.path, equals('/v1/device-status'));
      expect(captured!['device_id'], equals('DEV1'));

      await client.deviceStatusEnhanced(deviceId: 'DEV1');
      expect(capturedUrl.path, equals('/v1/device-status-enhanced'));
      expect(captured!['device_id'], equals('DEV1'));

      client.close();
    });
  });

  group('contacts', () {
    test('saveContact sends nama and nomor, never phone/name', () async {
      final client = clientWith(capturingMock());

      await client.saveContact(
        nama: 'John Doe',
        nomor: '6281234567890',
        deviceId: 'DEV1',
      );

      expect(capturedUrl.path, equals('/v1/save-contact'));
      expect(captured!['nama'], equals('John Doe'));
      expect(captured!['nomor'], equals('6281234567890'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!.containsKey('phone'), isFalse);
      expect(captured!.containsKey('name'), isFalse);
      expect(captured!.containsKey('email'), isFalse);
      client.close();
    });

    test('saveContact omits device_id when absent', () async {
      final client = clientWith(capturingMock());

      await client.saveContact(nama: 'A', nomor: '628000');

      expect(captured!.containsKey('device_id'), isFalse);
      client.close();
    });

    test('saveContactsBulk sends contacts array of {nama, nomor}', () async {
      final client = clientWith(capturingMock());

      await client.saveContactsBulk(
        contacts: const [
          BulkContact(nama: 'Andi', nomor: '628111'),
          BulkContact(nama: 'Budi', nomor: '628222'),
        ],
        deviceId: 'DEV1',
      );

      expect(capturedUrl.path, equals('/v1/save-contacts-bulk'));
      expect(captured!['contacts'], isA<List<dynamic>>());
      expect(captured!['contacts'], equals([
        {'nama': 'Andi', 'nomor': '628111'},
        {'nama': 'Budi', 'nomor': '628222'},
      ]));
      expect(captured!['device_id'], equals('DEV1'));
      client.close();
    });
  });

  group('generateOtp', () {
    test('sends required fields without optional params', () async {
      final client = clientWith(
        capturingMock(body: {'success': true, 'data': {'otp': '123456'}}),
      );

      final resp = await client.generateOtp(
        deviceId: 'DEV1',
        phone: '628xxx',
      );

      expect(resp.success, isTrue);
      expect(capturedUrl.path, equals('/v1/generate-otp'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['phone'], equals('628xxx'));
      expect(captured!.containsKey('otp_length'), isFalse);
      expect(captured!.containsKey('otp_type'), isFalse);
      expect(captured!.containsKey('customOtpMessage'), isFalse);
      expect(captured!.containsKey('customOtpText'), isFalse);
      client.close();
    });

    test('sends snake_case otp_length/otp_type plus custom fields', () async {
      final client = clientWith(capturingMock());

      await client.generateOtp(
        deviceId: 'DEV1',
        phone: '628xxx',
        otpLength: 6,
        otpType: 'numeric',
        customOtpText: 'Kode Anda',
        customOtpMessage: 'Your code is {otp}',
      );

      expect(captured!['otp_length'], equals(6));
      expect(captured!['otp_type'], equals('numeric'));
      expect(captured!['customOtpText'], equals('Kode Anda'));
      expect(captured!['customOtpMessage'], equals('Your code is {otp}'));
      expect(captured!.containsKey('otpLength'), isFalse);
      expect(captured!.containsKey('otpType'), isFalse);
      client.close();
    });
  });

  group('sendOtpV2', () {
    test('method whatsapp sends app_name only', () async {
      final client = clientWith(capturingMock());

      await client.sendOtpV2(
        phone: '6281234567890',
        method: 'whatsapp',
        appName: 'MyApp',
      );

      expect(capturedUrl.path, equals('/v2/otp/send'));
      expect(captured!['phone'], equals('6281234567890'));
      expect(captured!['method'], equals('whatsapp'));
      expect(captured!['app_name'], equals('MyApp'));
      expect(captured!.containsKey('device_id'), isFalse);
      expect(captured!.containsKey('waba_id'), isFalse);
      expect(captured!.containsKey('template_name'), isFalse);
      client.close();
    });

    test('method device sends device_id and custom_message', () async {
      final client = clientWith(capturingMock());

      await client.sendOtpV2(
        phone: '6281234567890',
        method: 'device',
        deviceId: 'DEV1',
        customMessage: 'Kode: {{otp}}',
      );

      expect(captured!['method'], equals('device'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['custom_message'], equals('Kode: {{otp}}'));
      expect(captured!.containsKey('waba_id'), isFalse);
      client.close();
    });

    test('method waba_user sends waba_id and template_name', () async {
      final client = clientWith(capturingMock());

      await client.sendOtpV2(
        phone: '6281234567890',
        method: 'waba_user',
        wabaId: 'WABA1',
        templateName: 'otp_auth',
      );

      expect(captured!['method'], equals('waba_user'));
      expect(captured!['waba_id'], equals('WABA1'));
      expect(captured!['template_name'], equals('otp_auth'));
      expect(captured!.containsKey('device_id'), isFalse);
      client.close();
    });

    test('omits optional params entirely', () async {
      final client = clientWith(capturingMock());

      await client.sendOtpV2(phone: '628xxx');

      expect(captured!['phone'], equals('628xxx'));
      expect(captured!.containsKey('method'), isFalse);
      expect(captured!.containsKey('app_name'), isFalse);
      client.close();
    });
  });

  group('verifyOtpV2 / validateOtp', () {
    test('verifyOtpV2 sends phone and otp_code', () async {
      final client = clientWith(capturingMock());

      await client.verifyOtpV2(phone: '628xxx', otpCode: '123456');

      expect(capturedUrl.path, equals('/v2/otp/verify'));
      expect(captured!['phone'], equals('628xxx'));
      expect(captured!['otp_code'], equals('123456'));
      client.close();
    });

    test('validateOtp sends device_id, phone, otp', () async {
      final client = clientWith(capturingMock());

      await client.validateOtp(
        deviceId: 'DEV1',
        phone: '628xxx',
        otp: '999999',
      );

      expect(capturedUrl.path, equals('/v1/validate-otp'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['phone'], equals('628xxx'));
      expect(captured!['otp'], equals('999999'));
      client.close();
    });
  });

  group('otp reverse', () {
    test('otpReverseCreate sends all fields', () async {
      final client = clientWith(capturingMock());

      await client.otpReverseCreate(
        phone: '628xxx',
        deviceId: 'DEV1',
        appName: 'MyApp',
        callbackUrl: 'https://example.com/cb',
        customMessage: 'Kirim {{token}} dari {{phone}}',
        successMessage: 'OK',
        failureMessage: 'FAIL',
      );

      expect(capturedUrl.path, equals('/v2/otp-reverse/create'));
      expect(captured!['phone'], equals('628xxx'));
      expect(captured!['device_id'], equals('DEV1'));
      expect(captured!['app_name'], equals('MyApp'));
      expect(captured!['callback_url'], equals('https://example.com/cb'));
      expect(captured!['custom_message'], equals('Kirim {{token}} dari {{phone}}'));
      expect(captured!['success_message'], equals('OK'));
      expect(captured!['failure_message'], equals('FAIL'));
      client.close();
    });

    test('otpReverseCreate omits optional fields', () async {
      final client = clientWith(capturingMock());

      await client.otpReverseCreate(phone: '628xxx', deviceId: 'DEV1');

      expect(captured!.containsKey('app_name'), isFalse);
      expect(captured!.containsKey('callback_url'), isFalse);
      expect(captured!.containsKey('custom_message'), isFalse);
      client.close();
    });

    test('otpReverseStatus sends token', () async {
      final client = clientWith(capturingMock());

      await client.otpReverseStatus(token: 'TOKEN123');

      expect(capturedUrl.path, equals('/v2/otp-reverse/status'));
      expect(captured!['token'], equals('TOKEN123'));
      client.close();
    });
  });

  group('deposits & packages', () {
    test('createDeposit sends nominal', () async {
      final client = clientWith(capturingMock());

      await client.createDeposit(nominal: 50000);

      expect(capturedUrl.path, equals('/v1/create-deposit'));
      expect(captured!['nominal'], equals(50000));
      client.close();
    });

    test('depositStatus sends ref', () async {
      final client = clientWith(capturingMock());

      await client.depositStatus(ref: 'REF1');

      expect(capturedUrl.path, equals('/v1/deposit-status'));
      expect(captured!['ref'], equals('REF1'));
      client.close();
    });

    test('cancelDeposit sends ref', () async {
      final client = clientWith(capturingMock());

      await client.cancelDeposit(ref: 'REF1');

      expect(capturedUrl.path, equals('/v1/cancel-deposit'));
      expect(captured!['ref'], equals('REF1'));
      client.close();
    });

    test('listDeposits sends page, limit, status', () async {
      final client = clientWith(capturingMock());

      await client.listDeposits(page: 2, limit: 25, status: 'paid');

      expect(capturedUrl.path, equals('/v1/list-deposits'));
      expect(captured!['page'], equals(2));
      expect(captured!['limit'], equals(25));
      expect(captured!['status'], equals('paid'));
      client.close();
    });

    test('listPackages posts auth only', () async {
      final client = clientWith(capturingMock());

      await client.listPackages();

      expect(capturedUrl.path, equals('/v1/list-packages'));
      expect(captured!['user_code'], equals(userCode));
      expect(captured!['secret'], equals(secret));
      client.close();
    });
  });

  group('userInfo', () {
    test('sends only auth fields', () async {
      final client = clientWith(capturingMock());

      await client.userInfo();

      expect(capturedUrl.path, equals('/v1/user-info'));
      expect(captured, equals({'user_code': userCode, 'secret': secret}));
      client.close();
    });
  });

  group('error handling', () {
    test('throws KirimiApiException on 401', () async {
      final mock = MockClient((request) async => _jsonResponse(
          {'success': false, 'message': 'Unauthorized'},
          status: 401));

      final client = clientWith(mock);

      expect(
        () => client.sendMessage(
          deviceId: 'DEV1',
          receiver: '628xxx',
          message: 'test',
        ),
        throwsA(isA<KirimiApiException>()
            .having((e) => e.statusCode, 'statusCode', equals(401))
            .having((e) => e.message, 'message', equals('Unauthorized'))),
      );

      client.close();
    });

    test('throws KirimiApiException on 500', () async {
      final mock = MockClient((request) async => _jsonResponse(
          {'success': false, 'message': 'Server Error'},
          status: 500));

      final client = clientWith(mock);

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

    test('throws KirimiNetworkException on transport failure', () async {
      final mock = MockClient((request) async {
        throw http.ClientException('connection refused');
      });

      final client = clientWith(mock);

      expect(
        () => client.userInfo(),
        throwsA(isA<KirimiNetworkException>()),
      );

      client.close();
    });
  });
}
