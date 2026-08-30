import 'package:ds_clickeat_web_admin/features/reports/models/report_sales.dart';

/// One row of `reports/orders-export` — a flat, per-order-*line-item* shape
/// (one row per product, or per product+add-on combination, rather than one
/// row per order like `reports/sales-export`'s `SalesCsvRow`). Used both for
/// the "Exportar CSV" button and as the orders report's detail table rows.
/// `prodsName` (tamaño/size) and the `proda*` add-on fields are commonly
/// empty when a line item has no size or no add-ons.
class OrdersCsvRow {
  final String premName;
  final int ordeId;
  final String tablId;
  final String ordeState;
  final String ordeType;
  final String dateserverCreated;
  final String prodName;
  final int prodQuantity;
  final String prodPriceUnitary;
  final String prodPriceTotal;
  final String prodsName;
  final String prodoName;
  final String prodaName;
  final int prodaQuantity;
  final String prodaPrice;
  final String prodaTotal;
  final String emplName;

  const OrdersCsvRow({
    required this.premName,
    required this.ordeId,
    required this.tablId,
    required this.ordeState,
    required this.ordeType,
    required this.dateserverCreated,
    required this.prodName,
    required this.prodQuantity,
    required this.prodPriceUnitary,
    required this.prodPriceTotal,
    required this.prodsName,
    required this.prodoName,
    required this.prodaName,
    required this.prodaQuantity,
    required this.prodaPrice,
    required this.prodaTotal,
    required this.emplName,
  });

  factory OrdersCsvRow.fromJson(Map<String, dynamic> json) {
    return OrdersCsvRow(
      premName: (json['prem_name'] ?? '') as String,
      ordeId: (json['orde_id'] as num?)?.toInt() ?? 0,
      tablId: (json['tabl_id'] ?? '').toString(),
      ordeState: (json['orde_state'] ?? '') as String,
      ordeType: (json['orde_type'] ?? '') as String,
      dateserverCreated: (json['dateserver_created'] ?? '') as String,
      prodName: (json['prod_name'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
      prodPriceUnitary: (json['prod_price_unitary'] ?? '0').toString(),
      prodPriceTotal: (json['prod_price_total'] ?? '0').toString(),
      prodsName: (json['prods_name'] ?? '') as String,
      prodoName: (json['prodo_name'] ?? '') as String,
      prodaName: (json['proda_name'] ?? '') as String,
      prodaQuantity: (json['proda_quantity'] as num?)?.toInt() ?? 0,
      prodaPrice: (json['proda_price'] ?? '0').toString(),
      prodaTotal: (json['proda_total'] ?? '0').toString(),
      emplName: (json['empl_name'] ?? '') as String,
    );
  }
}

/// The `cards` block of `reports/orders` — order counts rather than money,
/// so a distinct shape from the sales report's `DailyCardsSales`.
class OrdersCards {
  final int ordersPaid;
  final int ordersTotal;
  final int ordersAverage;
  final int ordersPending;
  final int ordersDeclined;
  final int ordersCancelled;

  const OrdersCards({
    required this.ordersPaid,
    required this.ordersTotal,
    required this.ordersAverage,
    required this.ordersPending,
    required this.ordersDeclined,
    required this.ordersCancelled,
  });

  factory OrdersCards.fromJson(Map<String, dynamic> json) {
    return OrdersCards(
      ordersPaid: (json['orders_paid'] as num?)?.toInt() ?? 0,
      ordersTotal: (json['orders_total'] as num?)?.toInt() ?? 0,
      ordersAverage: (json['orders_average'] as num?)?.toInt() ?? 0,
      ordersPending: (json['orders_pending'] as num?)?.toInt() ?? 0,
      ordersDeclined: (json['orders_declined'] as num?)?.toInt() ?? 0,
      ordersCancelled: (json['orders_cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = OrdersCards(
    ordersPaid: 0,
    ordersTotal: 0,
    ordersAverage: 0,
    ordersPending: 0,
    ordersDeclined: 0,
    ordersCancelled: 0,
  );
}

/// Full payload of `reports/orders` — `result` itself (see
/// `ReportsRepository.getOrders` for the older nested `fun_reports_orders`
/// shapes it still tolerates).
///
/// `orders_day`, `orders_type`, `orders_payments` and `orders_accumulated`
/// are byte-for-byte the same shape as the sales report's `sales_day` /
/// `sales_type` / `sales_payments` / `sales_accumulated` (just counting
/// orders instead of summing money), so this reuses those models instead of
/// duplicating near-identical classes.
class OrdersReportData {
  final OrdersCards cards;
  final List<SalesDayItem> ordersDay;
  final List<SalesTypeAmount> ordersType;
  final List<SalesPaymentAmount> ordersPayments;
  final List<SalesAccumulatedItem> ordersAccumulated;

  const OrdersReportData({
    required this.cards,
    required this.ordersDay,
    required this.ordersType,
    required this.ordersPayments,
    required this.ordersAccumulated,
  });

  factory OrdersReportData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return OrdersReportData(
      cards: json['cards'] is Map
          ? OrdersCards.fromJson(Map<String, dynamic>.from(json['cards'] as Map))
          : OrdersCards.empty,
      ordersDay: list('orders_day', SalesDayItem.fromJson),
      ordersType: list('orders_type', SalesTypeAmount.fromJson),
      ordersPayments: list('orders_payments', SalesPaymentAmount.fromJson),
      ordersAccumulated: list('orders_accumulated', SalesAccumulatedItem.fromJson),
    );
  }

  static const empty = OrdersReportData(
    cards: OrdersCards.empty,
    ordersDay: [],
    ordersType: [],
    ordersPayments: [],
    ordersAccumulated: [],
  );
}
