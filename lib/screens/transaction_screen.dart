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

  Future<void> _loadProducts() async {
    List<Product> products = await _databaseHelper.getAllProducts();
    setState(() {
      _products = products;
    });
  }

  void _addToCart(int productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final isId = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'id';
    if (product.quantity <= (_cart[productId] ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Stok tidak cukup!' : 'Insufficient stock!')),
      );
      return;
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isId ? 'Pilih Metode Pembayaran' : 'Select Payment Method',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Cash', style: TextStyle(fontSize: 14)),
                value: 'Cash',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
                activeColor: Theme.of(context).primaryColor,
              ),
              RadioListTile<String>(
                title: Text('Card', style: TextStyle(fontSize: 14)),
                value: 'Card',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
                activeColor: Theme.of(context).primaryColor,
              ),
              RadioListTile<String>(
                title: Text('QRIS', style: TextStyle(fontSize: 14)),
                value: 'QRIS',
                groupValue: selectedMethod,
                onChanged: (value) => setState(() => selectedMethod = value),
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isId ? 'Batal' : 'Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedMethod),
            child: Text(isId ? 'Konfirmasi' : 'Confirm'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Theme.of(context).primaryColor,
            ),
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

    try {
      double totalPrice = _calculateTotalPrice();
      final transaction = Transaction(
        transactionId: Uuid().v4(),
        transactionDate: DateTime.now().toIso8601String(),
        totalPrice: totalPrice,
        paymentMethod: paymentMethod,
      );

      await _databaseHelper.insertTransaction(transaction);

      for (var entry in _cart.entries) {
        final product = _products.firstWhere((p) => p.id == entry.key);
        final transactionItem = TransactionItem(
          transactionId: transaction.transactionId,
          productId: entry.key,
          quantity: entry.value,
          price: product.price,
        );
        await _databaseHelper.insertTransactionItem(transactionItem);
        await _databaseHelper.updateProductQuantity(
          product.id!,
          product.quantity - entry.value,
        );
      }

      _clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Transaksi berhasil!' : 'Transaction successful!')),
      );
      await _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Gagal menyimpan transaksi: $e' : 'Failed to save transaction: $e')),
      );
    }
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
        title: Text(
          isId ? 'Transaksi' : 'Transaction',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: theme.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _products.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    isId ? 'Tidak ada produk' : 'No products found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              physics: ClampingScrollPhysics(),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Card(
                  elevation: 3,
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      product.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      isId
                          ? 'Harga: ${currencyProvider.formatPrice(product.price)}\nStok: ${product.quantity}'
                          : 'Price: ${currencyProvider.formatPrice(product.price)}\nStock: ${product.quantity}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: product.quantity > 0 ? theme.primaryColor : Colors.grey[400],
                        size: 28,
                      ),
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
            height: _cart.isEmpty ? 80 : MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: _cart.isEmpty
                ? Center(
              child: Text(
                isId ? 'Keranjang kosong' : 'Cart is empty',
                style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            )
                : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isId ? 'Keranjang' : 'Cart',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _cartItemCount,
                        builder: (context, count, _) => count > 0
                            ? Chip(
                          label: Text('$count', style: TextStyle(fontSize: 12, color: Colors.white)),
                          backgroundColor: theme.primaryColor,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        )
                            : SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final entry = _cart.entries.elementAt(index);
                      final product = _products.firstWhere((p) => p.id == entry.key);
                      return Dismissible(
                        key: Key('${product.id}'),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeFromCart(entry.key),
                        child: Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              product.name,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              isId
                                  ? '${currencyProvider.formatPrice(product.price)} x ${entry.value}'
                                  : '${currencyProvider.formatPrice(product.price)} x ${entry.value}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle, size: 24, color: Colors.grey[600]),
                                  onPressed: () => _removeFromCart(entry.key),
                                  tooltip: isId ? 'Kurangi' : 'Remove',
                                ),
                                Text('${entry.value}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                IconButton(
                                  icon: Icon(Icons.add_circle, size: 24, color: theme.primaryColor),
                                  onPressed: product.quantity > entry.value ? () => _addToCart(entry.key) : null,
                                  tooltip: isId ? 'Tambah' : 'Add',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isId ? 'Total' : 'Total',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            currencyProvider.formatPrice(_calculateTotalPrice()),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearCart,
                              child: Text(
                                isId ? 'Kosongkan' : 'Clear',
                                style: TextStyle(fontSize: 14, color: theme.primaryColor),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: theme.primaryColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _showPaymentMethodDialog,
                              child: Text(
                                isId ? 'Bayar' : 'Checkout',
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: theme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
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