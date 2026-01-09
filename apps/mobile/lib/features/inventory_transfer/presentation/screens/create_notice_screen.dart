import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';
import 'package:yotech_mobile/features/skt/domain/models/product_summary_model.dart';
import 'package:yotech_mobile/features/skt/domain/providers/skt_providers.dart';
import 'package:yotech_mobile/shared/widgets/barcode_scanner_page.dart';
import 'package:yotech_mobile/shared/widgets/product_search_results_list.dart';

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
  String _searchQuery = '';
  ProductSummaryModel? _selectedProduct;
  String? _pendingAutoSelectQuery;

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

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir miktar girin.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(inventoryTransferListProvider.notifier).createNotice(
            productName: _productNameController.text.trim(),
            quantity: quantity.toDouble(),
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

    setState(() {
      _productNameController
        ..clear()
        ..text = scanned;
      _searchQuery = scanned;
      _selectedProduct = null;
      _pendingAutoSelectQuery = scanned;
    });
  }

  void _maybeAutoSelect(List<ProductSummaryModel> results) {
    final pendingQuery = _pendingAutoSelectQuery;
    if (pendingQuery == null || results.isEmpty) {
      return;
    }

    final match = _pickBestMatch(pendingQuery, results);
    if (match == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedProduct = match;
        _productNameController.text = match.name;
        _searchQuery = match.name;
        _pendingAutoSelectQuery = null;
      });
    });
  }

  ProductSummaryModel? _pickBestMatch(
    String query,
    List<ProductSummaryModel> results,
  ) {
    if (results.isEmpty) return null;
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
    final trimmedQuery = _searchQuery.trim();
    final searching = trimmedQuery.length >= 3;
    final searchAsync = searching
        ? ref.watch(sktProductSearchProvider(trimmedQuery))
        : const AsyncData<List<ProductSummaryModel>>(<ProductSummaryModel>[]);
    final searchResults = searchAsync.asData?.value;
    if (searchResults != null) {
      _maybeAutoSelect(searchResults);
    }

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
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searching && searchAsync.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            tooltip: 'Temizle',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _productNameController.clear();
                                _searchQuery = '';
                                _selectedProduct = null;
                                _pendingAutoSelectQuery = null;
                              });
                            },
                          ),
                        IconButton(
                          tooltip: 'Barkod Oku',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanBarcode,
                        ),
                      ],
                    ),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    if (value.trim().isEmpty) {
                      _selectedProduct = null;
                      _pendingAutoSelectQuery = null;
                    }
                  });
                },
                validator: (v) => v?.isEmpty == true ? 'Zorunlu alan' : null,
              ),
              _buildSelectedProductInfo(),
              const SizedBox(height: 12),
              ProductSearchResultsList(
                searchAsync: searchAsync,
                searching: searching,
                onSelect: (product) {
                  setState(() {
                    _selectedProduct = product;
                    _productNameController.text = product.name;
                    _searchQuery = product.name;
                    _pendingAutoSelectQuery = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Miktar'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null || value <= 0) {
                          return 'Pozitif tam sayı girin';
                        }
                        return null;
                      },
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
