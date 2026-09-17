/// Response model for all Kirimi API calls.
class KirimiResponse {
  final bool success;
  final dynamic data;
  final String? message;

  factory KirimiResponse.fromJson(Map<String, dynamic> json) {
    return KirimiResponse(
      success: json['success'] as bool? ?? false,
      data: json['data'],
      message: json['message'] as String?,
    );
  }

  const KirimiResponse({
    required this.success,
    this.data,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        if (data != null) 'data': data,
        if (message != null) 'message': message,
      };

  @override
  String toString() =>
      'KirimiResponse(success: $success, message: $message, data: $data)';
}

/// A single recipient for a bulk contact save.
///
/// The wire field names ARE `nama` and `nomor` — they are not snake_cased.
class BulkContact {
  final String nama;
  final String nomor;

  factory BulkContact.fromJson(Map<String, dynamic> json) => BulkContact(
        nama: json['nama'] as String? ?? '',
        nomor: json['nomor'] as String? ?? '',
      );

  const BulkContact({required this.nama, required this.nomor});

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'nomor': nomor,
      };

  @override
  String toString() => 'BulkContact(nama: $nama, nomor: $nomor)';
}

/// Header component for a WABA template send.
class WabaTemplateHeader {
  /// `document` | `image` | `video` | `text`
  final String type;

  /// Media URL, fetched by Meta.
  final String? link;

  /// Meta media handle, alternative to [link].
  final String? id;

  /// Document filename. Only used when [type] is `document`.
  final String? filename;

  /// Header text. Only used when [type] is `text`.
  final String? text;

  factory WabaTemplateHeader.fromJson(Map<String, dynamic> json) =>
      WabaTemplateHeader(
        type: json['type'] as String? ?? '',
        link: json['link'] as String?,
        id: json['id'] as String?,
        filename: json['filename'] as String?,
        text: json['text'] as String?,
      );

  const WabaTemplateHeader({
    required this.type,
    this.link,
    this.id,
    this.filename,
    this.text,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        if (link != null) 'link': link,
        if (id != null) 'id': id,
        if (filename != null) 'filename': filename,
        if (text != null) 'text': text,
      };

  @override
  String toString() => 'WabaTemplateHeader(type: $type)';
}

/// Convenience builder for free-form WABA reply payloads.
///
/// The value produced is a plain map matching the Meta message shape.
class WabaReplyMessage {
  final Map<String, dynamic> _json;

  const WabaReplyMessage._(this._json);

  /// `{ "type": "text", "text": "..." }`
  factory WabaReplyMessage.text(String text) =>
      WabaReplyMessage._({'type': 'text', 'text': text});

  /// `{ "type": "image"|"audio"|"video", "media_url": "...", "caption": "..." }`
  factory WabaReplyMessage.media({
    required String type,
    required String mediaUrl,
    String? caption,
  }) =>
      WabaReplyMessage._({
        'type': type,
        'media_url': mediaUrl,
        if (caption != null) 'caption': caption,
      });

  /// `{ "type": "document", "media_url": "...", "filename": "..." }`
  factory WabaReplyMessage.document({
    required String mediaUrl,
    String? caption,
    String? filename,
  }) =>
      WabaReplyMessage._({
        'type': 'document',
        'media_url': mediaUrl,
        if (caption != null) 'caption': caption,
        if (filename != null) 'filename': filename,
      });

  /// `{ "type": "interactive", "interactive": { ...Meta object... } }`
  factory WabaReplyMessage.interactive(Map<String, dynamic> interactive) =>
      WabaReplyMessage._({'type': 'interactive', 'interactive': interactive});

  Map<String, dynamic> toJson() => _json;

  @override
  String toString() => 'WabaReplyMessage($_json)';
}
