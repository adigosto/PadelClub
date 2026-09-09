/// Optional, server-side filters accepted by `GET /Operations/audit`.
class AuditTrailFilter {
  const AuditTrailFilter({this.userId, this.userName, this.method, this.from});

  final int? userId;
  final String? userName;
  final String? method;
  final DateTime? from;

  bool get isEmpty =>
      (userName == null || userName!.isEmpty) &&
      userId == null &&
      method == null &&
      from == null;

  AuditTrailFilter normalized() {
    final normalizedMethod = method?.trim().toUpperCase();
    return AuditTrailFilter(
      userId: userId,
      userName: userName?.trim(),
      method: normalizedMethod == null || normalizedMethod.isEmpty
          ? null
          : normalizedMethod,
      from: from?.toUtc(),
    );
  }

  Map<String, String> toQueryParameters() {
    final value = normalized();
    return {
      if (value.userName?.isNotEmpty == true) 'userName': value.userName!,
      if (value.userId != null) 'userId': '${value.userId}',
      if (value.method != null) 'method': value.method!,
      if (value.from != null) 'from': value.from!.toIso8601String(),
    };
  }
}
