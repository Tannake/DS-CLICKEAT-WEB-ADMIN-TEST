import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_product.dart';

/// A category + MXN total pair — `product_sales` of `reports/product-category`.
/// Distinct from `report_daily.dart`'s `ProductSalesItem` (`prod_name`), since
/// this report keys by `prodc_name` instead.
class CategorySalesItem {
  final String prodcName;
  final num prodTotal;

  const CategorySalesItem({required this.prodcName, required this.prodTotal});

  factory CategorySalesItem.fromJson(Map<String, dynamic> json) {
    return CategorySalesItem(
      prodcName: (json['prodc_name'] ?? '') as String,
      prodTotal: (json['prod_total'] as num?) ?? 0,
    );
  }
}

/// One row of `reports/product-category-export` — a flat, per-category shape.
/// Used both for the "Exportar CSV" button and as the categories report's
/// detail table rows. `prodSold` is the count of distinct products sold
/// within the category (as opposed to `prodQuantity`, the summed units).
class CategoryCsvRow {
  final String premName;
  final String prodcName;
  final int prodQuantity;
  final String prodTotal;
  final int prodSold;
  final String emplName;

  const CategoryCsvRow({
    required this.premName,
    required this.prodcName,
    required this.prodQuantity,
    required this.prodTotal,
    required this.prodSold,
    required this.emplName,
  });

  factory CategoryCsvRow.fromJson(Map<String, dynamic> json) {
    return CategoryCsvRow(
      premName: (json['prem_name'] ?? '') as String,
      prodcName: (json['prodc_name'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
      prodTotal: (json['prod_total'] ?? '0').toString(),
      prodSold: (json['prod_sold'] as num?)?.toInt() ?? 0,
      emplName: (json['empl_name'] ?? '') as String,
    );
  }
}

/// Full payload of `reports/product-category` — `result` itself. Same
/// `cards` shape as `reports/product`'s [ProductCards] (reused as-is), and
/// `product_sold_type`/`product_sales_type` are byte-for-byte the same shape
/// as [ProductTypeQuantity]/[ProductTypeAmount] (reused from
/// `report_product.dart`). Only `product_sold` (reuses `report_daily.dart`'s
/// [ProductCategoryItem], `prodc_name`+`prod_quantity`) and `product_sales`
/// (this file's [CategorySalesItem], `prodc_name`+`prod_total`) differ from
/// the products report's per-product shapes.
class CategoryReportData {
  final ProductCards cards;
  final List<ProductCategoryItem> productSold;
  final List<CategorySalesItem> productSales;
  final List<ProductTypeQuantity> productSoldType;
  final List<ProductTypeAmount> productSalesType;

  const CategoryReportData({
    required this.cards,
    required this.productSold,
    required this.productSales,
    required this.productSoldType,
    required this.productSalesType,
  });

  factory CategoryReportData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return CategoryReportData(
      cards: json['cards'] is Map
          ? ProductCards.fromJson(Map<String, dynamic>.from(json['cards'] as Map))
          : ProductCards.empty,
      productSold: list('product_sold', ProductCategoryItem.fromJson),
      productSales: list('product_sales', CategorySalesItem.fromJson),
      productSoldType: list('product_sold_type', ProductTypeQuantity.fromJson),
      productSalesType: list('product_sales_type', ProductTypeAmount.fromJson),
    );
  }

  static const empty = CategoryReportData(
    cards: ProductCards.empty,
    productSold: [],
    productSales: [],
    productSoldType: [],
    productSalesType: [],
  );
}
