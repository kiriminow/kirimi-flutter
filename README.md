# kirimi

[![pub package](https://img.shields.io/pub/v/kirimi.svg)](https://pub.dev/packages/kirimi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Official Dart/Flutter SDK for [Kirimi](https://kirimi.id) WhatsApp API.

## Features

- Send WhatsApp text and media messages
- Send messages via file upload (multipart)
- Fast message sending (no typing effect)
- Broadcast to multiple recipients
- WhatsApp Business API (WABA): templates, replies, conversations, OTP
- OTP (v1, v2, and reverse)
- Device management (create, connect, renew, status)
- Contact saving (single and bulk)
- Packages and deposits
- Null-safe, pure Dart — works on Flutter, server-side Dart, and web

## Installation

```yaml
dependencies:
  kirimi: ^0.1.0
```

Or via CLI:

```sh
dart pub add kirimi
# Flutter:
flutter pub add kirimi
```

## Quick Start

```dart
import 'package:kirimi/kirimi.dart';

final client = KirimiClient(
  userCode: 'YOUR_USER_CODE',
  secret: 'YOUR_SECRET',
);

final resp = await client.sendMessage(
  deviceId: 'YOUR_DEVICE_ID',
  receiver: '6281234567890', // country code, no '+'
  message: 'Welcome!',
);
print(resp.success); // true

client.close();
```

## Authentication

`user_code` and `secret` travel **in the request body** on every endpoint — not as a header.

## All Methods

### WhatsApp Messaging

```dart
// Send a text or media message
await client.sendMessage(
  deviceId: 'DEV_ID',
  receiver: '6281234567890',
  message: 'Hello!',
  mediaUrl: 'https://...',        // optional
  fileName: 'image.jpg',          // optional
  enableTypingEffect: true,       // optional, default true server-side
  typingSpeedMs: 350,             // optional, 100–800
  quotedMessageId: 'MSG_ID',      // optional
);

// Send with file upload (max 50 MB)
final bytes = await File('doc.pdf').readAsBytes();
await client.sendMessageFile(
  deviceId: 'DEV_ID',
  receiver: '6281234567890',
  fileBytes: bytes,
  fileName: 'doc.pdf',
  message: 'See attachment', // optional
  caption: 'A document',     // optional
);

// Send without the typing effect
await client.sendMessageFast(
  deviceId: 'DEV_ID',
  receiver: '6281234567890',
  message: 'Instant!',
);
```

### Broadcast

`numbers` is sent as a JSON **array** and `label` is required.

```dart
await client.broadcastMessage(
  deviceId: 'DEV_ID',
  label: 'promo-juli',                        // required, max 100 chars
  numbers: ['628111', '628222', '628333'],    // required, max 1000
  message: 'Promo hari ini!',
  delay: 30,                                  // optional, clamped 30–3600
  startedAt: '2026-01-01T00:00:00Z',          // optional, ISO 8601
);
```

### WABA

WABA endpoints use `waba_id`, never `device_id`.

```dart
// Send a Meta-approved template
await client.sendWabaMessage(
  wabaId: 'WABA_ID',
  to: '6281234567890',
  templateName: 'hello_world',
  variables: ['Andi', '12345'],  // optional
  header: WabaTemplateHeader(    // optional
    type: 'document',
    link: 'https://example.com/doc.pdf',
    filename: 'doc.pdf',
  ),
);

// Free-form reply (only inside the 24h customer service window)
await client.wabaReply(
  wabaId: 'WABA_ID',
  to: '6281234567890',
  message: WabaReplyMessage.text('Halo!').toJson(),
);

// List conversations inside the 24h window
await client.wabaConversations(limit: 50, page: 1);

// Refresh template status from Meta
await client.wabaTemplatesSync(wabaId: 'WABA_ID');

// OTP through your own WABA + AUTHENTICATION template
await client.wabaSendOtp(
  wabaId: 'WABA_ID',
  to: '6281234567890',
  templateName: 'otp_auth',
);
await client.wabaVerifyOtp(
  wabaId: 'WABA_ID',
  to: '6281234567890',
  otpCode: '123456',
);
```

### Devices

```dart
await client.createDevice(packageId: 12, voucherCode: 'DISC10');
await client.connectDevice(deviceId: 'DEV_ID');
await client.renewDevice(deviceId: 'DEV_ID', packageId: 12);
await client.listDevices(page: 1, limit: 10);
await client.deviceStatus(deviceId: 'DEV_ID');
await client.deviceStatusEnhanced(deviceId: 'DEV_ID');
```

### User

```dart
await client.userInfo();
```

### Contacts

```dart
await client.saveContact(
  nama: 'John Doe',
  nomor: '6281234567890',
  deviceId: 'DEV_ID', // optional
);

// Save up to 1000 contacts at once
await client.saveContactsBulk(
  contacts: const [
    BulkContact(nama: 'Andi', nomor: '628111'),
    BulkContact(nama: 'Budi', nomor: '628222'),
  ],
  deviceId: 'DEV_ID', // optional
);
```

### OTP v1

```dart
await client.generateOtp(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  otpLength: 6,                             // optional, 4–20, default 8
  otpType: 'numeric',                       // optional: numeric | alphabetic | alphanumeric
  customOtpText: 'Kode Anda',               // optional, max 20
  customOtpMessage: 'Your code is {otp}',   // optional, must contain {otp}
);

await client.validateOtp(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  otp: '123456',
);
```

### OTP v2

`method` is one of `whatsapp` (alias `waba`), `device`, or `waba_user`.

```dart
// Kirimi provider — Rp 595 per delivered OTP
await client.sendOtpV2(
  phone: '6281234567890',
  method: 'whatsapp',
  appName: 'MyApp', // optional
);

// Your own connected device — free
await client.sendOtpV2(
  phone: '6281234567890',
  method: 'device',
  deviceId: 'DEV_ID',
  customMessage: 'Kode: {{otp}}', // must contain {{otp}}, 10–500 chars
);

// Your own WABA — free
await client.sendOtpV2(
  phone: '6281234567890',
  method: 'waba_user',
  wabaId: 'WABA_ID',
  templateName: 'otp_auth',
);

await client.verifyOtpV2(
  phone: '6281234567890',
  otpCode: '123456',
);
```

### OTP Reverse

```dart
final created = await client.otpReverseCreate(
  phone: '6281234567890',
  deviceId: 'DEV_ID',
  appName: 'MyApp',                          // optional
  callbackUrl: 'https://example.com/cb',     // optional, max 500
  customMessage: 'Kirim {{token}} dari {{phone}}', // optional, 20–500
  successMessage: 'Terima kasih',
  failureMessage: 'Gagal',
);

// Status: pending | verified | phone_mismatch | expired (token valid 10 min, single use)
await client.otpReverseStatus(token: 'TOKEN');
```

### Deposits & Packages

```dart
await client.listPackages();
await client.createDeposit(nominal: 50000);           // min 100
await client.depositStatus(ref: 'REF');
await client.cancelDeposit(ref: 'REF');               // must be unpaid
await client.listDeposits(page: 1, limit: 10, status: 'paid');
```

## Error Handling

```dart
try {
  final resp = await client.sendMessage(
    deviceId: 'DEV',
    receiver: '628xxx',
    message: 'hi',
  );
  print(resp.data);
} on KirimiApiException catch (e) {
  // Non-2xx response from the API
  print('API error ${e.statusCode}: ${e.message}');
  print(e.responseData);
} on KirimiNetworkException catch (e) {
  // No response received (timeout, no internet, etc.)
  print('Network error: ${e.message}');
} on KirimiException catch (e) {
  // Base exception
  print(e.message);
}
```

HTTP status codes: `400` invalid params · `401` wrong secret · `402` insufficient balance ·
`403` feature not in package · `404` not found · `429` rate limited · `500` server error ·
`502` number undeliverable · `503` provider outage.

## Constructor Options

```dart
KirimiClient({
  required String userCode,
  required String secret,
  String baseUrl = 'https://api.kirimi.id',     // override for testing
  Duration timeout = const Duration(seconds: 30),
  http.Client? httpClient,                       // inject custom client
});
```

## Response Envelope

Every method returns `KirimiResponse`, never an unwrapped payload:

```dart
class KirimiResponse {
  final bool success;
  final dynamic data;
  final String? message;
}
```

## License

MIT © 2026 Kirimi
