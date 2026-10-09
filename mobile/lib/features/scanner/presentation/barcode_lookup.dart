import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import 'scanner_screen.dart';

/// Opens the scanner and returns the barcode, or null if cancelled.
/// Overridable in tests (the camera can't run there).
final barcodeScannerProvider =
    Provider<Future<String?> Function(BuildContext context, {String? title})>(
      (_) =>
          (context, {title}) =>
              Navigator.of(context, rootNavigator: true).push<String>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ScannerScreen(title: title ?? 'Scan barcode'),
                ),
              ),
    );

/// Scans a barcode and resolves it to a product. Shows a SnackBar and
/// returns null if the scan was cancelled, unknown, or the lookup failed.
Future<Product?> scanProduct(
  BuildContext context,
  WidgetRef ref, {
  String? title,
}) async {
  final code = await ref.read(barcodeScannerProvider)(context, title: title);
  if (code == null || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  try {
    return await ref.read(productsRepositoryProvider).getByBarcode(code);
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.statusCode == 404 ? 'No product with barcode $code' : e.message,
        ),
      ),
    );
    return null;
  }
}
