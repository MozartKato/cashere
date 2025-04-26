import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helper/database_helper.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import 'package:uuid/uuid.dart';

class TransactionScreen extends StatefulWidget {
  @override
  _TransactionScreenState createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Product> _products = [];
  Map<int, int> _cart = {};
  final ValueNotifier<int> _cartItemCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    List<Product> products = await _databaseHelper.getAllProducts();
    setState(() {
      _products = products;
    });
  }

  void _addToCart(int productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
      _cartItemCount.value = _cart.values.fold(0, (sum, qty) => sum + qty);
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        _cart[productId] = _cart[productId]! - 1;
        if (_cart[productId]! <= 0) {
          _cart.remove(productId);
        }
        _cartItemCount.value = _cart.values.fold(0, (sum, qty) => sum + qty);
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _cartItemCount.value = 0;
    });
  }

  void _showPaymentMethodDialog() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    String? selectedMethod = 'Cash';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isId ? 'Pilih Metode Pembayaran' : 'Select Payment Method'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Cash', style: TextStyle(fontSize: 14)),
                value: 'Cash',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
              ),
              RadioListTile<String>(
                title: Text('Card', style: TextStyle(fontSize: 14)),
                value: 'Card',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
              ),
              RadioListTile<String>(
                title: Text('QRIS', style: TextStyle(fontSize: 14)),
                value: 'QRIS',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isId ? 'Batal' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedMethod),
            child: Text(isId ? 'Konfirmasi' : 'Confirm'),
          ),
        ],
      ),
    ).then((value) {
      if (value != null) {
        _checkout(value);
      }
    });
  }

  void _checkout(String paymentMethod) async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Keranjang kosong!' : 'Cart is empty!')),
      );
      return;
    }

    for (var entry in _cart.entries) {
      final product = _products.firstWhere((p) => p.id == entry.key);
      final transaction = Transaction(
        transactionId: Uuid().v4(),
        productId: entry.key,
        quantity: entry.value,
        totalPrice: product.price * entry.value,
        transactionDate: DateTime.now().toIso8601String(),
        paymentMethod: paymentMethod,
      );
      await _databaseHelper.insertTransaction(transaction);
    }

    _clearCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isId ? 'Transaksi berhasil!' : 'Transaction successful!')),
    );
  }

  double _calculateTotalPrice() {
    double total = 0;
    for (var entry in _cart.entries) {
      final product = _products.firstWhere((p) => p.id == entry.key);
      total += product.price * entry.value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isId = localeProvider.locale.languageCode == 'id';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isId ? 'Transaksi' : 'Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: theme.primaryColor.withOpacity(0.9),
      ),
      body: Column(
        children: [
          Expanded(
            child: _products.isEmpty
                ? Center(
              child: Text(
                isId ? 'Tidak ada produk' : 'No products found',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
              physics: ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      product.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      isId
                          ? 'Harga: ${currencyProvider.formatPrice(product.price)} | Stok: ${product.quantity}'
                          : 'Price: ${currencyProvider.formatPrice(product.price)} | Stock: ${product.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: theme.primaryColor, size: 24),
                      onPressed: product.quantity > 0 ? () => _addToCart(product.id!) : null,
                      tooltip: isId ? 'Tambah ke Keranjang' : 'Add to Cart',
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: _cart.isEmpty ? 60 : MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: _cart.isEmpty
                ? Center(
              child: Text(
                isId ? 'Keranjang kosong' : 'Cart is empty',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            )
                : Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isId ? 'Keranjang' : 'Cart',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _cartItemCount,
                        builder: (context, count, _) => count > 0
                            ? Chip(
                          label: Text('$count', style: TextStyle(fontSize: 12, color: Colors.white)),
                          backgroundColor: theme.primaryColor,
                          padding: EdgeInsets.zero,
                        )
                            : SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final entry = _cart.entries.elementAt(index);
                      final product = _products.firstWhere((p) => p.id == entry.key);
                      return AnimatedOpacity(
                        duration: Duration(milliseconds: 200),
                        opacity: 1.0,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            product.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            isId
                                ? 'Harga: ${currencyProvider.formatPrice(product.price)} x ${entry.value}'
                                : 'Price: ${currencyProvider.formatPrice(product.price)} x ${entry.value}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey[600]),
                                onPressed: () => _removeFromCart(entry.key),
                                tooltip: isId ? 'Kurangi' : 'Remove',
                              ),
                              Text('${entry.value}', style: TextStyle(fontSize: 14)),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, size: 20, color: theme.primaryColor),
                                onPressed: product.quantity > entry.value ? () => _addToCart(entry.key) : null,
                                tooltip: isId ? 'Tambah' : 'Add',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isId ? 'Total:' : 'Total:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            currencyProvider.formatPrice(_calculateTotalPrice()),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryColor),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: _clearCart,
                            child: Text(
                              isId ? 'Kosongkan' : 'Clear Cart',
                              style: TextStyle(fontSize: 14, color: theme.primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              side: BorderSide(color: theme.primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _showPaymentMethodDialog,
                            child: Text(
                              isId ? 'Bayar' : 'Checkout',
                              style: TextStyle(fontSize: 14, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              backgroundColor: theme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cartItemCount.dispose();
    super.dispose();
  }
}