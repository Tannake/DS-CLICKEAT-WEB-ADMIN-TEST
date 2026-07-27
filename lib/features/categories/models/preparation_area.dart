/// A preparation area (área de preparación) scoped to a premise.
///
/// Backend shape (`products/category-preparation/<premId>` → `preparation_area`):
/// `{ prep_id, prep_name, prod_count, prin_name, prep_print_enabled, prep_available }`.
class PreparationArea {
  final int prepId;
  final String prepName;

  /// Number of products linked to this preparation area.
  final int prodCount;

  /// Name of the printer assigned to this area's tickets — either a
  /// registered printer's name or the "Default" sentinel meaning the
  /// premise's default printer.
  final String prinName;

  /// Whether tickets for this area are automatically sent to print.
  final bool prepPrintEnabled;

  /// Whether this preparation area is active.
  final bool prepAvailable;

  const PreparationArea({
    required this.prepId,
    required this.prepName,
    required this.prodCount,
    required this.prinName,
    required this.prepPrintEnabled,
    required this.prepAvailable,
  });

  factory PreparationArea.fromJson(Map<String, dynamic> json) {
    return PreparationArea(
      prepId: (json['prep_id'] as num?)?.toInt() ?? 0,
      prepName: (json['prep_name'] as String?)?.trim() ?? '',
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
      prinName: (json['prin_name'] as String?)?.trim().isNotEmpty == true
          ? (json['prin_name'] as String).trim()
          : 'Default',
      prepPrintEnabled: _parseBool(json['prep_print_enabled']),
      prepAvailable: _parseBool(json['prep_available'], defaultValue: true),
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
