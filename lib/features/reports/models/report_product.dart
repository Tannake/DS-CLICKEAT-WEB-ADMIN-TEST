import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';

/// One entry of `reports/parameter/product/:user_id` — a selectable product
/// for the "Producto" multi-select filter.
class ProductParamOption {
  final int prodId;
  final String prodName;

  const ProductParamOption({required this.prodId, required this.prodName});

  factory ProductParamOption.fromJson(Map<String, dynamic> json) {
    return ProductParamOption(
      prodId: (json['prod_id'] as num?)?.toInt() ?? 0,
      prodName: (json['prod_name'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/product-category/:user_id` — a selectable
/// category for the "Categoría" multi-select filter.
class ProductCategoryParamOption {
  final int prodcId;
  final String prodcName;

  const ProductCategoryParamOption({required this.prodcId, required this.prodcName});

  factory ProductCategoryParamOption.fromJson(Map<String, dynamic> json) {
    return ProductCategoryParamOption(
      prodcId: (json['prodc_id'] as num?)?.toInt() ?? 0,
      prodcName: (json['prodc_name'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/product-size/:user_id` — a selectable
/// size for the "Tamaño" multi-select filter.
class ProductSizeParamOption {
  final int prodsId;
  final String prodsName;

  const ProductSizeParamOption({required this.prodsId, required this.prodsName});

  factory ProductSizeParamOption.fromJson(Map<String, dynamic> json) {
    return ProductSizeParamOption(
      prodsId: (json['prods_id'] as num?)?.toInt() ?? 0,
      prodsName: (json['prods_name'] ?? '') as String,
    );
  }
}

/// One entry of `reports/parameter/product-option/:user_id` — a selectable
/// option/add-on for the "Opción" multi-select filter.
class ProductOptionParamOption {
  final int prodoId;
  final String prodoName;

  const ProductOptionParamOption({required this.prodoId, required this.prodoName});

  factory ProductOptionParamOption.fromJson(Map<String, dynamic> json) {
    return ProductOptionParamOption(
      prodoId: (json['prodo_id'] as num?)?.toInt() ?? 0,
      prodoName: (json['prodo_name'] ?? '') as String,
    );
  }
}

/// One row of `reports/product-export` — a flat, per-product (or
/// per-product+size/option combination) shape. Used both for the "Exportar
/// CSV" button and as the products report's detail table rows. `prodsName`
/// (tamaño) and `prodoName` (opción) are commonly empty when a line has no
/// size or no option. `prodPriceUnitary`/`prodTotal` arrive as formatted
/// strings ("149.00") rather than numbers, same as `reports/orders-export`.
class ProductCsvRow {
  final String premName;
  final String prodName;
  final String prodcName;
  final String prodsName;
  final String prodoName;
  final int prodQuantity;
  final String prodPriceUnitary;
  final String prodTotal;
  final String emplName;

  const ProductCsvRow({
    required this.premName,
    required this.prodName,
    required this.prodcName,
    required this.prodsName,
    required this.prodoName,
    required this.prodQuantity,
    required this.prodPriceUnitary,
    required this.prodTotal,
    required this.emplName,
  });

  factory ProductCsvRow.fromJson(Map<String, dynamic> json) {
    return ProductCsvRow(
      premName: (json['prem_name'] ?? '') as String,
      prodName: (json['prod_name'] ?? '') as String,
      prodcName: (json['prodc_name'] ?? '') as String,
      prodsName: (json['prods_name'] ?? '') as String,
      prodoName: (json['prodo_name'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
      prodPriceUnitary: (json['prod_price_unitary'] ?? '0').toString(),
      prodTotal: (json['prod_total'] ?? '0').toString(),
      emplName: (json['empl_name'] ?? '') as String,
    );
  }
}

/// The `cards` block of `reports/product`.
class ProductCards {
  final int productSold;
  final num productSales;
  final String? productSoldLowerName;
  final String? productSalesLowerName;
  final int? productSoldLowerTotal;
  final num? productSalesLowerTotal;
  final String? productSoldHightestName;
  final String? productSalesHightestName;
  final int? productSoldHightestTotal;
  final num? productSalesHightestTotal;

  const ProductCards({
    required this.productSold,
    required this.productSales,
    required this.productSoldLowerName,
    required this.productSalesLowerName,
    required this.productSoldLowerTotal,
    required this.productSalesLowerTotal,
    required this.productSoldHightestName,
    required this.productSalesHightestName,
    required this.productSoldHightestTotal,
    required this.productSalesHightestTotal,
  });

  factory ProductCards.fromJson(Map<String, dynamic> json) {
    return ProductCards(
      productSold: (json['product_sold'] as num?)?.toInt() ?? 0,
      productSales: json['product_sales'] as num? ?? 0,
      productSoldLowerName: json['product_sold_lower_name'] as String?,
      productSalesLowerName: json['product_sales_lower_name'] as String?,
      productSoldLowerTotal: (json['product_sold_lower_total'] as num?)?.toInt(),
      productSalesLowerTotal: json['product_sales_lower_total'] as num?,
      productSoldHightestName: json['product_sold_hightest_name'] as String?,
      productSalesHightestName: json['product_sales_hightest_name'] as String?,
      productSoldHightestTotal: (json['product_sold_hightest_total'] as num?)?.toInt(),
      productSalesHightestTotal: json['product_sales_hightest_total'] as num?,
    );
  }

  static const empty = ProductCards(
    productSold: 0,
    productSales: 0,
    productSoldLowerName: null,
    productSalesLowerName: null,
    productSoldLowerTotal: null,
    productSalesLowerTotal: null,
    productSoldHightestName: null,
    productSalesHightestName: null,
    productSoldHightestTotal: null,
    productSalesHightestTotal: null,
  );
}

/// One order-type's units sold — `product_sold_type`.
class ProductTypeQuantity {
  final String ordeType;
  final int prodQuantity;

  const ProductTypeQuantity({required this.ordeType, required this.prodQuantity});

  factory ProductTypeQuantity.fromJson(Map<String, dynamic> json) {
    return ProductTypeQuantity(
      ordeType: (json['orde_type'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One order-type's sales total — `product_sales_type`.
class ProductTypeAmount {
  final String ordeType;
  final num prodTotal;

  const ProductTypeAmount({required this.ordeType, required this.prodTotal});

  factory ProductTypeAmount.fromJson(Map<String, dynamic> json) {
    return ProductTypeAmount(
      ordeType: (json['orde_type'] ?? '') as String,
      prodTotal: (json['prod_total'] as num?) ?? 0,
    );
  }
}

/// Full payload of `reports/product`. `productSold`/`productSales` reuse
/// [ProductQuantityItem]/[ProductSalesItem] from `report_daily.dart` — same
/// `prod_name`/`prod_quantity` and `prod_name`/`prod_total` shapes the daily
/// dashboard's product buckets already carry.
class ProductReportData {
  final ProductCards cards;
  final List<ProductQuantityItem> productSold;
  final List<ProductSalesItem> productSales;
  final List<ProductTypeQuantity> productSoldType;
  final List<ProductTypeAmount> productSalesType;

  const ProductReportData({
    required this.cards,
    required this.productSold,
    required this.productSales,
    required this.productSoldType,
    required this.productSalesType,
  });

  factory ProductReportData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return ProductReportData(
      cards: json['cards'] is Map
          ? ProductCards.fromJson(Map<String, dynamic>.from(json['cards'] as Map))
          : ProductCards.empty,
      productSold: list('product_sold', ProductQuantityItem.fromJson),
      productSales: list('product_sales', ProductSalesItem.fromJson),
      productSoldType: list('product_sold_type', ProductTypeQuantity.fromJson),
      productSalesType: list('product_sales_type', ProductTypeAmount.fromJson),
    );
  }

  static const empty = ProductReportData(
    cards: ProductCards.empty,
    productSold: [],
    productSales: [],
    productSoldType: [],
    productSalesType: [],
  );
}
