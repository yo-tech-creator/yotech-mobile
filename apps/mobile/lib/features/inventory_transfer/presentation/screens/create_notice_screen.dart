import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';
import 'package:yotech_mobile/features/skt/domain/models/product_summary_model.dart';
import 'package:yotech_mobile/features/skt/domain/providers/skt_providers.dart';
import 'package:yotech_mobile/shared/widgets/barcode_scanner_page.dart';

class CreateNoticeScreen extends ConsumerStatefulWidget {
  const CreateNoticeScreen({super.key});

  @override
  ConsumerState<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends ConsumerState<CreateNoticeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController(text: 'adet');
  final _noteController = TextEditingController();
  DepotNoticeType _type = DepotNoticeType.surplus;
  bool _isLoading = false;
  bool _isSearchingProduct = false;
  ProductSummaryModel? _selectedProduct;
  String? _productSearchError;

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(inventoryTransferListProvider.notifier).createNotice(
            productName: _productNameController.text.trim(),
            quantity: double.parse(_quantityController.text),
            unit: _unitController.text,
            type: _type,
            note: _noteController.text.isEmpty ? null : _noteController.text,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlan oluşturuldu')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanBarcode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scanned == null || scanned.isEmpty) {
      return;
    }

    _productNameController
      ..clear()
      ..text = scanned;
    await _searchProduct(overrideQuery: scanned);
  }

  Future<void> _searchProduct({String? overrideQuery}) async {
    final query = (overrideQuery ?? _productNameController.text).trim();
    if (query.isEmpty) {
      setState(() => _productSearchError = 'Önce ürün adı veya barkod girin.');
      return;
    }
    if (query.length < 3) {
      setState(() => _productSearchError = 'En az 3 karakter girin.');
      return;
    }

    final user =
        ref.read(authProvider).mapOrNull(authenticated: (state) => state.user);
    if (user == null) {
      setState(
          () => _productSearchError = 'Kullanıcı oturum bilgisi bulunamadı.');
      return;
    }

    setState(() {
      _isSearchingProduct = true;
      _productSearchError = null;
    });

    try {
      final results = await ref.read(sktRepositoryProvider).searchProducts(
            tenantId: user.tenantId,
            query: query,
          );

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        setState(() {
          _selectedProduct = null;
          _productSearchError = 'Eşleşen ürün bulunamadı.';
        });
        return;
      }

      final match = _pickBestMatch(query, results);
      setState(() {
        _selectedProduct = match;
        _productNameController.text = match.name;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _productSearchError = 'Arama sırasında hata oluştu: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSearchingProduct = false);
      }
    }
  }

  ProductSummaryModel _pickBestMatch(
    String query,
    List<ProductSummaryModel> results,
  ) {
    final normalized = query.toLowerCase();
    for (final product in results) {
      if (product.barcode == query) {
        return product;
      }
      if (product.altBarcodes.contains(query)) {
        return product;
      }
    }
    for (final product in results) {
      if (product.name.toLowerCase() == normalized) {
        return product;
      }
    }
    return results.first;
  }

  Widget _buildSelectedProductInfo() {
    final product = _selectedProduct;
    if (product == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
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
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selectedProduct = null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İlan Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(
                  labelText: 'Ürün Adı / Barkod',
                  helperText:
                      'Barkod okutabilir veya ürün ismi yazarak arama yapabilirsiniz.',
                  suffixIcon: SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSearchingProduct)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Ürün Ara',
                            icon: const Icon(Icons.search),
                            onPressed: () => _searchProduct(),
                          ),
                        IconButton(
                          tooltip: 'Barkod Oku',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed:
                              _isSearchingProduct ? null : () => _scanBarcode(),
                        ),
                      ],
                    ),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _searchProduct(),
                onChanged: (_) {
                  if (_selectedProduct != null || _productSearchError != null) {
                    setState(() {
                      _selectedProduct = null;
                      _productSearchError = null;
                    });
                  }
                },
                validator: (v) => v?.isEmpty == true ? 'Zorunlu alan' : null,
              ),
              if (_productSearchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _productSearchError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              _buildSelectedProductInfo(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Zorunlu alan' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Birim'),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Zorunlu alan' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DepotNoticeType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tip'),
                items: const [
                  DropdownMenuItem(
                    value: DepotNoticeType.surplus,
                    child: Text('Fazla (Verilecek)'),
                  ),
                  DropdownMenuItem(
                    value: DepotNoticeType.shortage,
                    child: Text('Eksik (Aranıyor)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Not (Opsiyonel)'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
