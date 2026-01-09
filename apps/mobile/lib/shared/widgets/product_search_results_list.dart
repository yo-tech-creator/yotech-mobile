import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/skt/domain/models/product_summary_model.dart';

class ProductSearchResultsList extends StatelessWidget {
  const ProductSearchResultsList({
    super.key,
    required this.searchAsync,
    required this.searching,
    required this.onSelect,
  });

  final AsyncValue<List<ProductSummaryModel>> searchAsync;
  final bool searching;
  final ValueChanged<ProductSummaryModel> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!searching) {
      return Text(
        'En az 3 karakter girerek arama yapın.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return searchAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return Text(
            'Eşleşme bulunamadı.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return SizedBox(
          height: 180,
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Barkod: ${product.barcode}'),
                    if (product.altBarcodes.isNotEmpty)
                      Text('Alt barkodlar: ${product.altBarcodes.join(', ')}'),
                  ],
                ),
                leading: const Icon(Icons.inventory_2_outlined),
                onTap: () => onSelect(product),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Text(
        'Arama sırasında hata oluştu: $error',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
