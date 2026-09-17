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
      receiver: '6281234567890',
      message: 'Halo dari Kirimi SDK!',
    );
    print('success: ${msgResp.success}');
    print('message: ${msgResp.message}');
    print('data: ${msgResp.data}');

    // Example 2: broadcast to many numbers (numbers is a List)
    print('\n=== broadcastMessage ===');
    final bcResp = await client.broadcastMessage(
      deviceId: 'YOUR_DEVICE_ID',
      label: 'promo-juli',
      numbers: ['6281234567890', '6289876543210'],
      message: 'Promo hari ini!',
    );
    print('success: ${bcResp.success}');

    // Example 3: send a WABA template
    print('\n=== sendWabaMessage ===');
    final wabaResp = await client.sendWabaMessage(
      wabaId: 'YOUR_WABA_ID',
      to: '6281234567890',
      templateName: 'hello_world',
      variables: ['Andi'],
    );
    print('success: ${wabaResp.success}');

    // Example 4: generate OTP (v1)
    print('\n=== generateOtp ===');
    final otpResp = await client.generateOtp(
      deviceId: 'YOUR_DEVICE_ID',
      phone: '6281234567890',
      otpLength: 6,
      otpType: 'numeric',
    );
    print('success: ${otpResp.success}');
    print('data: ${otpResp.data}');

    // Example 5: save a contact
    print('\n=== saveContact ===');
    final contactResp = await client.saveContact(
      nama: 'John Doe',
      nomor: '6281234567890',
      deviceId: 'YOUR_DEVICE_ID',
    );
    print('success: ${contactResp.success}');

    // Example 6: list devices
    print('\n=== listDevices ===');
    final devicesResp = await client.listDevices(page: 1, limit: 10);
    print('success: ${devicesResp.success}');
    print('data: ${devicesResp.data}');

    // Example 7: create a deposit
    print('\n=== createDeposit ===');
    final depositResp = await client.createDeposit(nominal: 50000);
    print('success: ${depositResp.success}');
    print('data: ${depositResp.data}');
  } on KirimiApiException catch (e) {
    print('API error ${e.statusCode}: ${e.message}');
  } on KirimiNetworkException catch (e) {
    print('Network error: ${e.message}');
  } finally {
    client.close();
  }
}
