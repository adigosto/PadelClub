/// A read-only request record returned by the administrator audit endpoint.
///
/// The audit API is deliberately the source of truth: this entity has no
/// mutation helpers and is only constructed from the server response.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.userId,
    this.userName,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.ipAddress,
    required this.correlationId,
    required this.durationMs,
    required this.createdAt,
  });

  final int id;
  final int? userId;
  final String? userName;
  final String method;
  final String path;
  final int statusCode;
  final String ipAddress;
  final String correlationId;
  final int durationMs;
  final DateTime createdAt;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    int requiredInteger(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('Audit event contains an invalid $key.');
    }

    int? optionalInteger(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is num) return value.toInt();
      throw FormatException('Audit event contains an invalid $key.');
    }

    String requiredText(String key) {
      final value = json[key];
      if (value is String) return value;
      throw FormatException('Audit event contains an invalid $key.');
    }

    final createdAtRaw = requiredText('createdAt');
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException('Audit event contains an invalid createdAt.');
    }

    return AuditLogEntry(
      id: requiredInteger('id'),
      userId: optionalInteger('userId'),
      userName: json['userName'] as String?,
      method: requiredText('method'),
      path: requiredText('path'),
      statusCode: requiredInteger('statusCode'),
      ipAddress: requiredText('ipAddress'),
      correlationId: requiredText('correlationId'),
      durationMs: requiredInteger('durationMs'),
      createdAt: createdAt,
    );
  }
}
