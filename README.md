# kirimi

[![pub package](https://img.shields.io/pub/v/kirimi.svg)](https://pub.dev/packages/kirimi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Official Dart/Flutter SDK for [Kirimi](https://kirimi.id) WhatsApp API.

## Features

- Send WhatsApp text and media messages
- Send messages via file upload (multipart)
- Fast message sending (no typing effect)
- WhatsApp Business API (WABA) support
- OTP generation and validation (v1 & v2)
- Device management
- Broadcast to multiple recipients
- Contact saving
- Deposit and package listing
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

### Flutter

```dart
import 'package:kirimi/kirimi.dart';

class MyService {
  final _client = KirimiClient(
    userCode: 'YOUR_USER_CODE',
    secret: 'YOUR_SECRET',
  );

  Future<void> sendWelcome(String phone) async {
    final resp = await _client.sendMessage(
      deviceId: 'YOUR_DEVICE_ID',
      phone: phone,
      message: 'Welcome!',
    );
    print(resp.success); // true
  }

  void dispose() => _client.close();
}
```

### Server-side Dart

```dart
import 'package:kirimi/kirimi.dart';

Future<void> main() async {
  final client = KirimiClient(
    userCode: 'YOUR_USER_CODE',
    secret: 'YOUR_SECRET',
  );

  final resp = await client.userInfo();
  print(resp.data);

  client.close();
}
```

## All Methods

### WhatsApp Messaging

```dart
// Send text or media message
await client.sendMessage(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  message: 'Hello!',
  mediaUrl: 'https://...', // optional
);

// Send with file upload (max 50 MB)
final bytes = await File('doc.pdf').readAsBytes();
await client.sendMessageFile(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  fileBytes: bytes,
  fileName: 'doc.pdf',
  message: 'See attachment', // optional
);

// Send without typing effect
await client.sendMessageFast(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  message: 'Instant!',
);
```

### WABA

```dart
await client.sendWabaMessage(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  message: 'WABA message',
);
```

### Devices

```dart
await client.listDevices();
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
  phone: '6281234567890',
  name: 'John Doe',    // optional
  email: 'j@doe.com', // optional
);
```

### OTP

```dart
// Generate OTP (v1)
await client.generateOtp(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  otpLength: 6,         // optional
  otpType: 'numeric',   // optional: numeric | alphabetic | alphanumeric
  customOtpMessage: 'Your code is {otp}', // optional
);

// Validate OTP (v1)
await client.validateOtp(
  deviceId: 'DEV_ID',
  phone: '6281234567890',
  otp: '123456',
);

// Send OTP (v2)
await client.sendOtpV2(
  phone: '6281234567890',
  deviceId: 'DEV_ID',
  method: 'device',    // optional: device | waba
  appName: 'MyApp',    // optional
);

// Verify OTP (v2)
await client.verifyOtpV2(
  phone: '6281234567890',
  otpCode: '123456',
);
```

### Broadcast

```dart
// Pass a list or a comma-separated string
await client.broadcastMessage(
  deviceId: 'DEV_ID',
  phones: ['628111', '628222', '628333'],
  message: 'Promo hari ini!',
  delay: 2, // optional, seconds between messages
);
```

### Deposits & Packages

```dart
await client.listDeposits(status: 'paid'); // optional filter
await client.listPackages();
```

## Error Handling

```dart
try {
  final resp = await client.sendMessage(
    deviceId: 'DEV',
    phone: '628xxx',
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

## License

MIT © 2026 Kirimi
