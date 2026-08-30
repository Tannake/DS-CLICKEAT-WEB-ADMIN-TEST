/// One row of `reports/sales-export` — a flat, per-order shape. Used both for
/// the "Exportar CSV" button and as the sales report's detail table rows
/// (`reports/sales` no longer returns per-order rows itself). `ordeTotal`
/// arrives as a formatted string ("323.00") rather than a number — fine for
/// the CSV cell, parsed with `num.tryParse` for the table.
class SalesCsvRow {
  final int premId;
  final String premName;
  final int ordeId;
  final int custId;
  final String tablId;
  final String ordeTotal;
  final String ordeState;
  final String ordeType;
  final String paymName;
  final num tipsPercentage;
  final String reasName;
  final String emplName;
  final String dateserverCreated;

  const SalesCsvRow({
    required this.premId,
    required this.premName,
    required this.ordeId,
    required this.custId,
    required this.tablId,
    required this.ordeTotal,
    required this.ordeState,
    required this.ordeType,
    required this.paymName,
    required this.tipsPercentage,
    required this.reasName,
    required this.emplName,
    required this.dateserverCreated,
  });

  factory SalesCsvRow.fromJson(Map<String, dynamic> json) {
    return SalesCsvRow(
      premId: (json['prem_id'] as num?)?.toInt() ?? 0,
      premName: (json['prem_name'] ?? '') as String,
      ordeId: (json['orde_id'] as num?)?.toInt() ?? 0,
      custId: (json['cust_id'] as num?)?.toInt() ?? 0,
      tablId: (json['tabl_id'] ?? '').toString(),
      ordeTotal: (json['orde_total'] ?? '0').toString(),
      ordeState: (json['orde_state'] ?? '') as String,
      ordeType: (json['orde_type'] ?? '') as String,
      paymName: (json['paym_name'] ?? '') as String,
      tipsPercentage: (json['tips_percentage'] as num?) ?? 0,
      reasName: (json['reas_name'] ?? '') as String,
      emplName: (json['empl_name'] ?? '') as String,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/orders-state` — a selectable order state
/// for the "Estado" multi-select filter. `ordeState` is the raw code sent
/// back to the backend (e.g. "CANCELLED"); `stateName` is the Spanish label
/// shown to the user (and matches the already-translated `orde_state` value
/// `reports/sales-export` rows carry, so `stateBadge` in `sales_report_view.dart`
/// keys off the same strings).
class OrderStateOption {
  final String ordeState;
  final String stateName;

  const OrderStateOption({required this.ordeState, required this.stateName});

  factory OrderStateOption.fromJson(Map<String, dynamic> json) {
    return OrderStateOption(
      ordeState: (json['orde_state'] ?? '') as String,
      stateName: (json['state_name'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/premises/:user_id` — a selectable branch
/// for the "Sucursal" multi-select filter. A dedicated, lighter shape than
/// `features/premises/models/premise.dart`'s `Premise` (which also carries
/// an address from a different endpoint) so this feature doesn't couple to
/// that one's response shape.
class PremiseOption {
  final int premId;
  final String premName;

  const PremiseOption({required this.premId, required this.premName});

  factory PremiseOption.fromJson(Map<String, dynamic> json) {
    return PremiseOption(
      premId: (json['prem_id'] as num?)?.toInt() ?? 0,
      premName: (json['prem_name'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/payments/:user_id` — a selectable payment
/// method for the "Método de pago" multi-select filter.
class PaymentOption {
  final int paymId;
  final String paymName;
  final bool paymAvailable;

  const PaymentOption({
    required this.paymId,
    required this.paymName,
    required this.paymAvailable,
  });

  factory PaymentOption.fromJson(Map<String, dynamic> json) {
    return PaymentOption(
      paymId: (json['paym_id'] as num?)?.toInt() ?? 0,
      paymName: (json['paym_name'] ?? '') as String,
      paymAvailable: json['paym_available'] == true,
    );
  }
}

/// One entry of `reports/parameter/reason-cancel/:user_id` — a selectable
/// cancellation reason for the "Razón de cancelación" multi-select filter.
class ReasonOption {
  final int reasId;
  final String reasName;

  const ReasonOption({required this.reasId, required this.reasName});

  factory ReasonOption.fromJson(Map<String, dynamic> json) {
    return ReasonOption(
      reasId: (json['reas_id'] as num?)?.toInt() ?? 0,
      reasName: (json['reas_name'] ?? '') as String,
    );
  }
}

/// One day's total — `sales_day` / (minus the running total) `sales_accumulated`.
class SalesDayItem {
  final num ordeTotal;
  final String dateserverCreated;

  const SalesDayItem({required this.ordeTotal, required this.dateserverCreated});

  factory SalesDayItem.fromJson(Map<String, dynamic> json) {
    return SalesDayItem(
      ordeTotal: (json['orde_total'] as num?) ?? 0,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
    );
  }
}

/// One day's total plus its running total — `sales_accumulated`.
class SalesAccumulatedItem {
  final num ordeTotal;
  final String dateserverCreated;
  final num ordeTotalAccumulated;

  const SalesAccumulatedItem({
    required this.ordeTotal,
    required this.dateserverCreated,
    required this.ordeTotalAccumulated,
  });

  factory SalesAccumulatedItem.fromJson(Map<String, dynamic> json) {
    return SalesAccumulatedItem(
      ordeTotal: (json['orde_total'] as num?) ?? 0,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
      ordeTotalAccumulated: (json['orde_total_accumulated'] as num?) ?? 0,
    );
  }
}

/// One order-type's total — `sales_type` (channel breakdown, in MXN rather
/// than the order-count breakdown the daily dashboard used).
class SalesTypeAmount {
  final String ordeType;
  final num ordeTotal;

  const SalesTypeAmount({required this.ordeType, required this.ordeTotal});

  factory SalesTypeAmount.fromJson(Map<String, dynamic> json) {
    return SalesTypeAmount(
      ordeType: (json['orde_type'] ?? '') as String,
      ordeTotal: (json['orde_total'] as num?) ?? 0,
    );
  }
}

/// One payment method's total — `sales_payments` (mirrors `sales_type`'s
/// shape). A real SQL-side aggregate, unlike the daily dashboard's earlier
/// payment breakdown which had to be summed client-side from
/// `orders_summary` before this field existed.
class SalesPaymentAmount {
  final String paymName;
  final num ordeTotal;

  const SalesPaymentAmount({required this.paymName, required this.ordeTotal});

  factory SalesPaymentAmount.fromJson(Map<String, dynamic> json) {
    return SalesPaymentAmount(
      paymName: (json['paym_name'] ?? '') as String,
      ordeTotal: (json['orde_total'] as num?) ?? 0,
    );
  }
}

/// `cards_lower` — the lowest-selling day in the period.
class SalesLow {
  final num? ordeTotalMin;
  final String? dateserverCreatedMin;

  const SalesLow({required this.ordeTotalMin, required this.dateserverCreatedMin});

  factory SalesLow.fromJson(Map<String, dynamic> json) {
    return SalesLow(
      ordeTotalMin: json['orde_total_min'] as num?,
      dateserverCreatedMin: json['dateserver_created_min'] as String?,
    );
  }

  static const empty = SalesLow(ordeTotalMin: null, dateserverCreatedMin: null);
}

/// `cards_highest` — the highest-selling day in the period.
class SalesHigh {
  final num? ordeTotalMax;
  final String? dateserverCreatedMax;

  const SalesHigh({required this.ordeTotalMax, required this.dateserverCreatedMax});

  factory SalesHigh.fromJson(Map<String, dynamic> json) {
    return SalesHigh(
      ordeTotalMax: json['orde_total_max'] as num?,
      dateserverCreatedMax: json['dateserver_created_max'] as String?,
    );
  }

  static const empty = SalesHigh(ordeTotalMax: null, dateserverCreatedMax: null);
}

/// Full payload of `reports/sales` — `result` itself (some deployments still
/// nest it one level under `result.fun_reports_sales`; the repository
/// unwraps that case if present, mirroring `reports/daily`).
class SalesReportData {
  final DailyCardsSales cards;
  final List<SalesDayItem> salesDay;
  final List<SalesTypeAmount> salesType;
  final SalesLow cardsLower;
  final SalesHigh cardsHighest;
  final List<SalesPaymentAmount> salesPayments;
  final List<SalesAccumulatedItem> salesAccumulated;

  const SalesReportData({
    required this.cards,
    required this.salesDay,
    required this.salesType,
    required this.cardsLower,
    required this.cardsHighest,
    required this.salesPayments,
    required this.salesAccumulated,
  });

  factory SalesReportData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return SalesReportData(
      cards: json['cards'] is Map
          ? DailyCardsSales.fromJson(Map<String, dynamic>.from(json['cards'] as Map))
          : DailyCardsSales.empty,
      salesDay: list('sales_day', SalesDayItem.fromJson),
      salesType: list('sales_type', SalesTypeAmount.fromJson),
      cardsLower: json['cards_lower'] is Map
          ? SalesLow.fromJson(Map<String, dynamic>.from(json['cards_lower'] as Map))
          : SalesLow.empty,
      cardsHighest: json['cards_highest'] is Map
          ? SalesHigh.fromJson(Map<String, dynamic>.from(json['cards_highest'] as Map))
          : SalesHigh.empty,
      salesPayments: list('sales_payments', SalesPaymentAmount.fromJson),
      salesAccumulated: list('sales_accumulated', SalesAccumulatedItem.fromJson),
    );
  }

  static const empty = SalesReportData(
    cards: DailyCardsSales.empty,
    salesDay: [],
    salesType: [],
    cardsLower: SalesLow.empty,
    cardsHighest: SalesHigh.empty,
    salesPayments: [],
    salesAccumulated: [],
  );
}

/// The `cards` block of `reports/sales` — same shape as the daily
/// dashboard's `DailyCards` (`cust_total`/`sales_total`/`orders_total`/
/// `average_ticket`/`orders_cancelled`), but named separately since this
/// report has no `cards_previous` to diff against.
class DailyCardsSales {
  final int custTotal;
  final int ordersTotal;
  final num? salesTotal;
  final num? averageTicket;
  final int ordersCancelled;

  const DailyCardsSales({
    required this.custTotal,
    required this.ordersTotal,
    required this.salesTotal,
    required this.averageTicket,
    required this.ordersCancelled,
  });

  factory DailyCardsSales.fromJson(Map<String, dynamic> json) {
    return DailyCardsSales(
      custTotal: (json['cust_total'] as num?)?.toInt() ?? 0,
      ordersTotal: (json['orders_total'] as num?)?.toInt() ?? 0,
      salesTotal: json['sales_total'] as num?,
      averageTicket: json['average_ticket'] as num?,
      ordersCancelled: (json['orders_cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = DailyCardsSales(
    custTotal: 0,
    ordersTotal: 0,
    salesTotal: null,
    averageTicket: null,
    ordersCancelled: 0,
  );
}
