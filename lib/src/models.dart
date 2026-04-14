/// Response model for all Kirimi API calls.
class KirimiResponse {
  final bool success;
  final dynamic data;
  final String? message;

  const KirimiResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory KirimiResponse.fromJson(Map<String, dynamic> json) {
    return KirimiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'],
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (data != null) 'data': data,
        if (message != null) 'message': message,
      };

  @override
  String toString() =>
      'KirimiResponse(success: $success, message: $message, data: $data)';
}
