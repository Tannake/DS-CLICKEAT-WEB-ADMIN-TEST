/// A ticket/receipt printer configured for a premise. The backend
/// (`premises/printer/<premId>`) returns the connection details (network
/// IP/port or a Windows shared-printer name, depending on
/// [prinConnectionType]) plus print behavior flags.
class Printer {
  final int prinId;
  final String prinName;
  final String prinConnectionType; // NETWORK | USB | WINDOWS
  final String prinUsageType; // RECEIPT or a business-defined custom area
  final String? prinIp;
  final int? prinPort;
  final String? prinWindowsName;
  final int prinPaperWidth;
  final bool prinAutoCut;
  final bool prinBeep;
  final bool prinIsDefault;
  final bool prinIsActive;

  const Printer({
    required this.prinId,
    required this.prinName,
    required this.prinConnectionType,
    required this.prinUsageType,
    this.prinIp,
    this.prinPort,
    this.prinWindowsName,
    required this.prinPaperWidth,
    required this.prinAutoCut,
    required this.prinBeep,
    required this.prinIsDefault,
    required this.prinIsActive,
  });

  Printer copyWith({
    String? prinName,
    String? prinConnectionType,
    String? prinUsageType,
    String? prinIp,
    int? prinPort,
    String? prinWindowsName,
    int? prinPaperWidth,
    bool? prinAutoCut,
    bool? prinBeep,
    bool? prinIsDefault,
    bool? prinIsActive,
  }) => Printer(
        prinId: prinId,
        prinName: prinName ?? this.prinName,
        prinConnectionType: prinConnectionType ?? this.prinConnectionType,
        prinUsageType: prinUsageType ?? this.prinUsageType,
        prinIp: prinIp ?? this.prinIp,
        prinPort: prinPort ?? this.prinPort,
        prinWindowsName: prinWindowsName ?? this.prinWindowsName,
        prinPaperWidth: prinPaperWidth ?? this.prinPaperWidth,
        prinAutoCut: prinAutoCut ?? this.prinAutoCut,
        prinBeep: prinBeep ?? this.prinBeep,
        prinIsDefault: prinIsDefault ?? this.prinIsDefault,
        prinIsActive: prinIsActive ?? this.prinIsActive,
      );

  factory Printer.fromJson(Map<String, dynamic> j) {
    return Printer(
      prinId: (j['prin_id'] as num).toInt(),
      prinName: (j['prin_name'] ?? '').toString(),
      prinConnectionType: (j['prin_connection_type'] ?? 'NETWORK').toString(),
      prinUsageType: (j['prin_usage_type'] ?? 'RECEIPT').toString(),
      prinIp: j['prin_ip']?.toString(),
      prinPort: (j['prin_port'] as num?)?.toInt(),
      prinWindowsName: j['prin_windows_name']?.toString(),
      prinPaperWidth: (j['prin_paper_width'] as num?)?.toInt() ?? 80,
      prinAutoCut: _parseBool(j['prin_auto_cut']),
      prinBeep: _parseBool(j['prin_beep']),
      prinIsDefault: _parseBool(j['prin_is_default']),
      prinIsActive: _parseBool(j['prin_is_active'], defaultValue: true),
    );
  }
}

bool _parseBool(dynamic raw, {bool defaultValue = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw.toInt() == 1;
  if (raw is String) {
    final s = raw.toLowerCase().trim();
    return s == 'true' || s == '1';
  }
  return defaultValue;
}
