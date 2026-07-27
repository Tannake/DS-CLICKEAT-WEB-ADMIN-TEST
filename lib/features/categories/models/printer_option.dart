/// A printer registered on the premise, as listed by
/// `products/category-preparation/<premId>` → `printer`, used to populate the
/// preparation area's printer picker.
class PrinterOption {
  final int prinId;
  final String prinName;

  const PrinterOption({required this.prinId, required this.prinName});

  factory PrinterOption.fromJson(Map<String, dynamic> json) {
    return PrinterOption(
      prinId: (json['prin_id'] as num?)?.toInt() ?? 0,
      prinName: (json['prin_name'] ?? '').toString(),
    );
  }
}
