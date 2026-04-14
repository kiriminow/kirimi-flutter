import 'package:kirimi/kirimi.dart';

Future<void> main() async {
  final client = KirimiClient(
    userCode: 'YOUR_USER_CODE',
    secret: 'YOUR_SECRET',
  );

  try {
    // Example 1: send a text message
    print('=== sendMessage ===');
    final msgResp = await client.sendMessage(
      deviceId: 'YOUR_DEVICE_ID',
      phone: '6281234567890',
      message: 'Halo dari Kirimi SDK!',
    );
    print('success: ${msgResp.success}');
    print('message: ${msgResp.message}');
    print('data: ${msgResp.data}');

    // Example 2: generate OTP
    print('\n=== generateOtp ===');
    final otpResp = await client.generateOtp(
      deviceId: 'YOUR_DEVICE_ID',
      phone: '6281234567890',
      otpLength: 6,
      otpType: 'numeric',
    );
    print('success: ${otpResp.success}');
    print('data: ${otpResp.data}');

    // Example 3: list devices
    print('\n=== listDevices ===');
    final devicesResp = await client.listDevices();
    print('success: ${devicesResp.success}');
    print('data: ${devicesResp.data}');
  } on KirimiApiException catch (e) {
    print('API error ${e.statusCode}: ${e.message}');
  } on KirimiNetworkException catch (e) {
    print('Network error: ${e.message}');
  } finally {
    client.close();
  }
}
