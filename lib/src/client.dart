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
///   receiver: '628xxx',
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

  Map<String, dynamic> get _authFields => {
        'user_code': userCode,
        'secret': secret,
      };

  Future<KirimiResponse> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    final payload = <String, dynamic>{
      ..._authFields,
      ...body,
    }..removeWhere((_, value) => value == null);

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

    final message = body is Map
        ? (body['message'] as String? ??
            response.reasonPhrase ??
            'Unknown error')
        : response.reasonPhrase ?? 'Unknown error';
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
      final streamedResponse = await _http.send(request).timeout(timeout);
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
    required String receiver,
    required String message,
    String? mediaUrl,
    String? fileName,
    bool? enableTypingEffect,
    int? typingSpeedMs,
    String? quotedMessageId,
  }) {
    return _post('/v1/send-message', {
      'device_id': deviceId,
      'receiver': receiver,
      'message': message,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (enableTypingEffect != null) 'enableTypingEffect': enableTypingEffect,
      if (typingSpeedMs != null) 'typingSpeedMs': typingSpeedMs,
      if (quotedMessageId != null) 'quotedMessageId': quotedMessageId,
    });
  }

  /// Send a message with a file attachment via multipart/form-data (max 50 MB).
  Future<KirimiResponse> sendMessageFile({
    required String deviceId,
    required String receiver,
    required List<int> fileBytes,
    required String fileName,
    String? message,
    String? caption,
    String? quotedMessageId,
  }) {
    return _postMultipart(
      '/v1/send-message-file',
      {
        'device_id': deviceId,
        'receiver': receiver,
        'fileName': fileName,
        if (message != null) 'message': message,
        if (caption != null) 'caption': caption,
        if (quotedMessageId != null) 'quotedMessageId': quotedMessageId,
      },
      fileBytes,
      fileName,
    );
  }

  /// Send a message instantly (no typing effect).
  Future<KirimiResponse> sendMessageFast({
    required String deviceId,
    required String receiver,
    required String message,
    String? mediaUrl,
    String? fileName,
    String? quotedMessageId,
  }) {
    return _post('/v1/send-message-fast', {
      'device_id': deviceId,
      'receiver': receiver,
      'message': message,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (quotedMessageId != null) 'quotedMessageId': quotedMessageId,
    });
  }

  /// Broadcast a message to multiple recipients.
  ///
  /// [numbers] is sent as a JSON array. Max 1000 numbers per request.
  Future<KirimiResponse> broadcastMessage({
    required String deviceId,
    required String label,
    required List<String> numbers,
    required String message,
    int? delay,
    int? delayMin,
    int? delayMax,
    String? mediaUrl,
    String? fileName,
    String? startedAt,
    bool? enableTypingEffect,
    int? typingSpeedMs,
  }) {
    return _post('/v1/broadcast-message', {
      'device_id': deviceId,
      'label': label,
      'numbers': numbers,
      'message': message,
      if (delay != null) 'delay': delay,
      if (delayMin != null) 'delayMin': delayMin,
      if (delayMax != null) 'delayMax': delayMax,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (startedAt != null) 'started_at': startedAt,
      if (enableTypingEffect != null) 'enableTypingEffect': enableTypingEffect,
      if (typingSpeedMs != null) 'typingSpeedMs': typingSpeedMs,
    });
  }

  // ---------------------------------------------------------------------------
  // WABA
  // ---------------------------------------------------------------------------

  /// Send a Meta-approved template via WhatsApp Business API.
  ///
  /// Uses `waba_id`, never `device_id`.
  Future<KirimiResponse> sendWabaMessage({
    required String wabaId,
    required String to,
    required String templateName,
    List<String>? variables,
    WabaTemplateHeader? header,
    List<dynamic>? buttons,
  }) {
    return _post('/v1/waba/send-message', {
      'waba_id': wabaId,
      'to': to,
      'template_name': templateName,
      if (variables != null) 'variables': variables,
      if (header != null) 'header': header.toJson(),
      if (buttons != null) 'buttons': buttons,
    });
  }

  /// Send a free-form reply inside the 24h customer service window.
  ///
  /// [message] follows the Meta shape, e.g.
  /// `{'type': 'text', 'text': 'halo'}`.
  Future<KirimiResponse> wabaReply({
    required String wabaId,
    required String to,
    required Map<String, dynamic> message,
  }) {
    return _post('/v1/waba/messages/reply', {
      'waba_id': wabaId,
      'to': to,
      'message': message,
    });
  }

  /// List conversations still inside the 24h customer service window.
  Future<KirimiResponse> wabaConversations({int? limit, int? page}) {
    return _post('/v1/waba/conversations', {
      if (limit != null) 'limit': limit,
      if (page != null) 'page': page,
    });
  }

  /// Refresh template status from Meta for one WABA.
  Future<KirimiResponse> wabaTemplatesSync({required String wabaId}) {
    return _post('/v1/waba/templates/sync', {'waba_id': wabaId});
  }

  /// Send an OTP through your own WABA + AUTHENTICATION template.
  Future<KirimiResponse> wabaSendOtp({
    required String wabaId,
    required String to,
    required String templateName,
  }) {
    return _post('/v1/waba/send-otp', {
      'waba_id': wabaId,
      'to': to,
      'template_name': templateName,
    });
  }

  /// Verify an OTP previously sent through [wabaSendOtp].
  Future<KirimiResponse> wabaVerifyOtp({
    required String wabaId,
    required String to,
    required String otpCode,
  }) {
    return _post('/v1/waba/verify-otp', {
      'waba_id': wabaId,
      'to': to,
      'otp_code': otpCode,
    });
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// Create a new device for a package.
  Future<KirimiResponse> createDevice({
    required dynamic packageId,
    String? voucherCode,
  }) {
    return _post('/v1/create-device', {
      'package_id': packageId,
      if (voucherCode != null) 'voucher_code': voucherCode,
    });
  }

  /// Connect a device and obtain its QR/session state.
  Future<KirimiResponse> connectDevice({required String deviceId}) {
    return _post('/v1/connect-device', {'device_id': deviceId});
  }

  /// Renew a device subscription.
  Future<KirimiResponse> renewDevice({
    required String deviceId,
    required dynamic packageId,
    String? voucherCode,
  }) {
    return _post('/v1/renew-device', {
      'device_id': deviceId,
      'package_id': packageId,
      if (voucherCode != null) 'voucher_code': voucherCode,
    });
  }

  /// List all registered devices.
  Future<KirimiResponse> listDevices({int? page, int? limit}) {
    return _post('/v1/list-devices', {
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    });
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

  /// Save a contact to the account. Existing numbers are skipped.
  Future<KirimiResponse> saveContact({
    required String nama,
    required String nomor,
    String? deviceId,
  }) {
    return _post('/v1/save-contact', {
      'nama': nama,
      'nomor': nomor,
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  /// Save up to 1000 contacts in one request.
  Future<KirimiResponse> saveContactsBulk({
    required List<BulkContact> contacts,
    String? deviceId,
  }) {
    return _post('/v1/save-contacts-bulk', {
      'contacts': contacts.map((c) => c.toJson()).toList(),
      if (deviceId != null) 'device_id': deviceId,
    });
  }

  // ---------------------------------------------------------------------------
  // OTP v1
  // ---------------------------------------------------------------------------

  /// Generate and send an OTP via a WhatsApp device.
  Future<KirimiResponse> generateOtp({
    required String deviceId,
    required String phone,
    int? otpLength,
    String? otpType,
    String? customOtpText,
    String? customOtpMessage,
    bool? enableTypingEffect,
    int? typingSpeedMs,
  }) {
    return _post('/v1/generate-otp', {
      'device_id': deviceId,
      'phone': phone,
      if (otpLength != null) 'otp_length': otpLength,
      if (otpType != null) 'otp_type': otpType,
      if (customOtpText != null) 'customOtpText': customOtpText,
      if (customOtpMessage != null) 'customOtpMessage': customOtpMessage,
      if (enableTypingEffect != null) 'enableTypingEffect': enableTypingEffect,
      if (typingSpeedMs != null) 'typingSpeedMs': typingSpeedMs,
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

  // ---------------------------------------------------------------------------
  // OTP v2
  // ---------------------------------------------------------------------------

  /// Send an OTP via the Kirimi provider, your own device, or your own WABA.
  ///
  /// [method] is one of `whatsapp` (alias `waba`), `device`, or `waba_user`.
  /// - `device` requires [deviceId] and a [customMessage] containing `{{otp}}`.
  /// - `waba_user` requires [wabaId] and [templateName].
  Future<KirimiResponse> sendOtpV2({
    required String phone,
    String? method,
    String? appName,
    String? deviceId,
    String? wabaId,
    String? templateName,
    String? customMessage,
  }) {
    return _post('/v2/otp/send', {
      'phone': phone,
      if (method != null) 'method': method,
      if (appName != null) 'app_name': appName,
      if (deviceId != null) 'device_id': deviceId,
      if (wabaId != null) 'waba_id': wabaId,
      if (templateName != null) 'template_name': templateName,
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
  // OTP Reverse
  // ---------------------------------------------------------------------------

  /// Create a reverse OTP token and the message the customer must send back.
  Future<KirimiResponse> otpReverseCreate({
    required String phone,
    required String deviceId,
    String? appName,
    String? callbackUrl,
    String? customMessage,
    String? successMessage,
    String? failureMessage,
  }) {
    return _post('/v2/otp-reverse/create', {
      'phone': phone,
      'device_id': deviceId,
      if (appName != null) 'app_name': appName,
      if (callbackUrl != null) 'callback_url': callbackUrl,
      if (customMessage != null) 'custom_message': customMessage,
      if (successMessage != null) 'success_message': successMessage,
      if (failureMessage != null) 'failure_message': failureMessage,
    });
  }

  /// Check the status of a reverse OTP token.
  Future<KirimiResponse> otpReverseStatus({required String token}) {
    return _post('/v2/otp-reverse/status', {'token': token});
  }

  // ---------------------------------------------------------------------------
  // Packages & Deposits
  // ---------------------------------------------------------------------------

  /// List available packages.
  Future<KirimiResponse> listPackages() {
    return _post('/v1/list-packages', {});
  }

  /// Create a deposit payment link. [nominal] minimum is 100.
  Future<KirimiResponse> createDeposit({required num nominal}) {
    return _post('/v1/create-deposit', {'nominal': nominal});
  }

  /// Check a deposit's status by [ref].
  Future<KirimiResponse> depositStatus({required String ref}) {
    return _post('/v1/deposit-status', {'ref': ref});
  }

  /// Cancel an unpaid deposit by [ref].
  Future<KirimiResponse> cancelDeposit({required String ref}) {
    return _post('/v1/cancel-deposit', {'ref': ref});
  }

  /// List deposits, optionally filtered by [status].
  Future<KirimiResponse> listDeposits({
    int? page,
    int? limit,
    String? status,
  }) {
    return _post('/v1/list-deposits', {
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (status != null) 'status': status,
    });
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Release the underlying HTTP client. Call when done with this instance.
  void close() {
    if (_ownsClient) _http.close();
  }
}
