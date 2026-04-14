import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

/// Main client for the Kirimi WhatsApp API.
///
/// ```dart
/// final client = KirimiClient(userCode: 'USER', secret: 'SECRET');
/// final resp = await client.sendMessage(
///   deviceId: 'DEV',
///   phone: '628xxx',
///   message: 'halo',
/// );
/// client.close();
/// ```
class KirimiClient {
  final String userCode;
  final String secret;
  final String baseUrl;
  final Duration timeout;

  final http.Client _http;
  final bool _ownsClient;

  KirimiClient({
    required this.userCode,
    required this.secret,
    this.baseUrl = 'https://api.kirimi.id',
    this.timeout = const Duration(seconds: 30),
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Map<String, String> get _authFields => {
        'user_code': userCode,
        'secret': secret,
      };

  Future<KirimiResponse> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    final payload = {..._authFields, ...body};

    try {
      final response = await _http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } on KirimiException {
      rethrow;
    } catch (e) {
      throw KirimiNetworkException('Network error: $e', cause: e);
    }
  }

  KirimiResponse _handleResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return KirimiResponse.fromJson(body);
      }
      return KirimiResponse(success: true, data: body);
    }

    final message = body is Map ? (body['message'] as String? ?? response.reasonPhrase ?? 'Unknown error') : response.reasonPhrase ?? 'Unknown error';
    throw KirimiApiException(response.statusCode, message, responseData: body);
  }

  Future<KirimiResponse> _postMultipart(
    String path,
    Map<String, String> fields,
    List<int> fileBytes,
    String fileName,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', url)
      ..fields.addAll({..._authFields, ...fields})
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

    try {
      final streamedResponse =
          await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on KirimiException {
      rethrow;
    } catch (e) {
      throw KirimiNetworkException('Network error: $e', cause: e);
    }
  }

  // ---------------------------------------------------------------------------
  // WhatsApp Unofficial
  // ---------------------------------------------------------------------------

  /// Send a text/media message to a single recipient.
  Future<KirimiResponse> sendMessage({
    required String deviceId,
    required String phone,
    required String message,
    String? mediaUrl,
  }) {
    return _post('/v1/send-message', {
      'device_id': deviceId,
      'phone': phone,
      'message': message,
      if (mediaUrl != null) 'media_url': mediaUrl,
    });
  }

  /// Send a message with a file attachment via multipart/form-data (max 50 MB).
  Future<KirimiResponse> sendMessageFile({
    required String deviceId,
    required String phone,
    required List<int> fileBytes,
    required String fileName,
    String? message,
  }) {
    return _postMultipart(
      '/v1/send-message-file',
      {
        'device_id': deviceId,
        'phone': phone,
        if (message != null) 'message': message,
        'fileName': fileName,
      },
      fileBytes,
      fileName,
    );
  }

  /// Send a message instantly (no typing effect).
  Future<KirimiResponse> sendMessageFast({
    required String deviceId,
    required String phone,
    required String message,
    String? mediaUrl,
  }) {
    return _post('/v1/send-message-fast', {
      'device_id': deviceId,
      'phone': phone,
      'message': message,
      if (mediaUrl != null) 'media_url': mediaUrl,
    });
  }

  // ---------------------------------------------------------------------------
  // WABA
  // ---------------------------------------------------------------------------

  /// Send a message via WhatsApp Business API (Meta Cloud API).
  Future<KirimiResponse> sendWabaMessage({
    required String deviceId,
    required String phone,
    required String message,
  }) {
    return _post('/v1/waba/send-message', {
      'device_id': deviceId,
      'phone': phone,
      'message': message,
    });
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// List all registered devices.
  Future<KirimiResponse> listDevices() {
    return _post('/v1/list-devices', {});
  }

  /// Get connection status for a device.
  Future<KirimiResponse> deviceStatus({required String deviceId}) {
    return _post('/v1/device-status', {'device_id': deviceId});
  }

  /// Get detailed/enhanced status for a device.
  Future<KirimiResponse> deviceStatusEnhanced({required String deviceId}) {
    return _post('/v1/device-status-enhanced', {'device_id': deviceId});
  }

  // ---------------------------------------------------------------------------
  // User
  // ---------------------------------------------------------------------------

  /// Get current account information.
  Future<KirimiResponse> userInfo() {
    return _post('/v1/user-info', {});
  }

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------

  /// Save a contact to the account.
  Future<KirimiResponse> saveContact({
    required String phone,
    String? name,
    String? email,
  }) {
    return _post('/v1/save-contact', {
      'phone': phone,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
  }

  // ---------------------------------------------------------------------------
  // OTP
  // ---------------------------------------------------------------------------

  /// Generate and send an OTP via a WhatsApp device.
  Future<KirimiResponse> generateOtp({
    required String deviceId,
    required String phone,
    int? otpLength,
    String? otpType,
    String? customOtpMessage,
  }) {
    return _post('/v1/generate-otp', {
      'device_id': deviceId,
      'phone': phone,
      if (otpLength != null) 'otp_length': otpLength,
      if (otpType != null) 'otp_type': otpType,
      if (customOtpMessage != null) 'customOtpMessage': customOtpMessage,
    });
  }

  /// Validate an OTP code that was previously generated.
  Future<KirimiResponse> validateOtp({
    required String deviceId,
    required String phone,
    required String otp,
  }) {
    return _post('/v1/validate-otp', {
      'device_id': deviceId,
      'phone': phone,
      'otp': otp,
    });
  }

  /// Send OTP via WABA template or device (v2).
  Future<KirimiResponse> sendOtpV2({
    required String phone,
    required String deviceId,
    String? method,
    String? appName,
    String? templateCode,
    String? customMessage,
  }) {
    return _post('/v2/otp/send', {
      'phone': phone,
      'device_id': deviceId,
      if (method != null) 'method': method,
      if (appName != null) 'app_name': appName,
      if (templateCode != null) 'template_code': templateCode,
      if (customMessage != null) 'custom_message': customMessage,
    });
  }

  /// Verify an OTP code (v2).
  Future<KirimiResponse> verifyOtpV2({
    required String phone,
    required String otpCode,
  }) {
    return _post('/v2/otp/verify', {
      'phone': phone,
      'otp_code': otpCode,
    });
  }

  // ---------------------------------------------------------------------------
  // Broadcast
  // ---------------------------------------------------------------------------

  /// Broadcast a message to multiple recipients.
  ///
  /// [phones] can be a comma-separated [String] or a [List<String>].
  Future<KirimiResponse> broadcastMessage({
    required String deviceId,
    required dynamic phones,
    required String message,
    int? delay,
  }) {
    final String phonesStr;
    if (phones is List<String>) {
      phonesStr = phones.join(',');
    } else if (phones is String) {
      phonesStr = phones;
    } else {
      throw ArgumentError('phones must be a String or List<String>');
    }

    return _post('/v1/broadcast-message', {
      'device_id': deviceId,
      'phones': phonesStr,
      'message': message,
      if (delay != null) 'delay': delay,
    });
  }

  // ---------------------------------------------------------------------------
  // Deposits
  // ---------------------------------------------------------------------------

  /// List deposits. Optionally filter by [status] (paid, unpaid, expired).
  Future<KirimiResponse> listDeposits({String? status}) {
    return _post('/v1/list-deposits', {
      if (status != null) 'status': status,
    });
  }

  /// List available packages.
  Future<KirimiResponse> listPackages() {
    return _post('/v1/list-packages', {});
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Release the underlying HTTP client. Call when done with this instance.
  void close() {
    if (_ownsClient) _http.close();
  }
}
