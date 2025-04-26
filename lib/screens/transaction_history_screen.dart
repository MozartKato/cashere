import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:open_file/open_file.dart';
import '../helper/database_helper.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  @override
  _TransactionHistoryScreenState createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortAscending = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPaymentMethod;
  String? _selectedCategory;
  List<Product> _cachedProducts = [];

  @override
  void initState() {
    super.initState();
    _loadCachedProducts();
  }

  void _loadCachedProducts() async {
    _cachedProducts = await _databaseHelper.getAllProducts();
  }

  Future<List<Map<String, dynamic>>> _getGroupedTransactions() async {
    final transactions = await _databaseHelper.getAllTransactions();
    final categories = await _databaseHelper.getAllCategories();
    final Map<String, List<Transaction>> grouped = {};

    // Filter transaksi
    final filteredTransactions = transactions.where((t) {
      final matchesSearch = t.transactionId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          _cachedProducts
              .firstWhere((p) => p.id == t.productId, orElse: () => Product(id: 0, name: '', price: 0, quantity: 0, category: ''))
              .name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchesDate = (_startDate == null && _endDate == null) ||
          (DateTime.parse(t.transactionDate).isAfter(_startDate!) && DateTime.parse(t.transactionDate).isBefore(_endDate!));
      final matchesPayment = _selectedPaymentMethod == null || t.paymentMethod == _selectedPaymentMethod;
      final matchesCategory = _selectedCategory == null ||
          _cachedProducts
              .firstWhere((p) => p.id == t.productId, orElse: () => Product(id: 0, name: '', price: 0, quantity: 0, category: ''))
              .category == _selectedCategory;
      return matchesSearch && matchesDate && matchesPayment && matchesCategory;
    }).toList();

    // Kelompokkan berdasarkan transactionId
    for (var transaction in filteredTransactions) {
      grouped.putIfAbsent(transaction.transactionId, () => []).add(transaction);
    }

    // Buat list untuk Card
    final List<Map<String, dynamic>> result = [];
    for (var entry in grouped.entries) {
      final transactionId = entry.key;
      final transactionList = entry.value;
      final total = transactionList.fold<double>(0, (sum, t) => sum + t.totalPrice);
      final date = transactionList.first.transactionDate;
      final paymentMethod = transactionList.first.paymentMethod;
      final items = transactionList.map((t) {
        final product = _cachedProducts.firstWhere(
              (p) => p.id == t.productId,
          orElse: () => Product(id: 0, name: 'Unknown', price: 0, quantity: 0, category: 'Unknown'),
        );
        return {
          'productName': product.name,
          'quantity': t.quantity,
          'unitPrice': t.totalPrice / t.quantity,
          'totalPrice': t.totalPrice,
          'category': product.category,
        };
      }).toList();

      result.add({
        'transactionId': transactionId,
        'total': total,
        'date': date,
        'paymentMethod': paymentMethod,
        'items': items,
      });
    }

    // Sort hasil
    result.sort((a, b) {
      int compare;
      switch (_sortBy) {
        case 'total':
          compare = a['total'].compareTo(b['total']);
          break;
        default:
          compare = DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
      }
      return _sortAscending ? compare : -compare;
    });

    return result;
  }

  String _formatDate(String isoDate, String languageCode) {
    final date = DateTime.parse(isoDate).toLocal();
    final formatter = DateFormat('dd MMM yyyy, HH:mm', languageCode);
    return formatter.format(date);
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    final items = transaction['items'] as List<Map<String, dynamic>>;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isId ? 'Detail Transaksi' : 'Transaction Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 16),
                  _buildDetailRow(
                    isId ? 'ID Transaksi' : 'Transaction ID',
                    transaction['transactionId'].substring(0, 8),
                    context,
                  ),
                  _buildDetailRow(
                    isId ? 'Tanggal' : 'Date',
                    _formatDate(transaction['date'], isId ? 'id' : 'en'),
                    context,
                  ),
                  _buildDetailRow(
                    isId ? 'Metode Pembayaran' : 'Payment Method',
                    transaction['paymentMethod'],
                    context,
                  ),
                  SizedBox(height: 16),
                  Text(
                    isId ? 'Produk Dibeli' : 'Purchased Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  ...items.map((item) => AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['productName'],
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          isId
                              ? 'Kategori: ${item['category']}'
                              : 'Category: ${item['category']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          isId
                              ? 'Jumlah: ${item['quantity']} x ${currencyProvider.formatPrice(item['unitPrice'])}'
                              : 'Quantity: ${item['quantity']} x ${currencyProvider.formatPrice(item['unitPrice'])}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          isId
                              ? 'Total: ${currencyProvider.formatPrice(item['totalPrice'])}'
                              : 'Total: ${currencyProvider.formatPrice(item['totalPrice'])}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )),
                  SizedBox(height: 16),
                  _buildDetailRow(
                    isId ? 'Total Transaksi' : 'Transaction Total',
                    currencyProvider.formatPrice(transaction['total']),
                    context,
                    isBold: true,
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isId ? 'Tutup' : 'Close', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;
    String? tempPaymentMethod = _selectedPaymentMethod;
    String? tempCategory = _selectedCategory;
    final categories = await _databaseHelper.getAllCategories();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Filter Transaksi' : 'Filter Transactions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 16),
                    Text(isId ? 'Rentang Tanggal' : 'Date Range', style: TextStyle(fontSize: 14)),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => tempStartDate = picked);
                              }
                            },
                            child: Text(
                              tempStartDate == null
                                  ? (isId ? 'Pilih Mulai' : 'Select Start')
                                  : _formatDate(tempStartDate!.toIso8601String(), isId ? 'id' : 'en'),
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEndDate ?? DateTime.now(),
                                firstDate: tempStartDate ?? DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => tempEndDate = picked);
                              }
                            },
                            child: Text(
                              tempEndDate == null
                                  ? (isId ? 'Pilih Akhir' : 'Select End')
                                  : _formatDate(tempEndDate!.toIso8601String(), isId ? 'id' : 'en'),
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(isId ? 'Metode Pembayaran' : 'Payment Method', style: TextStyle(fontSize: 14)),
                    DropdownButtonFormField<String?>(
                      value: tempPaymentMethod,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(isId ? 'Semua' : 'All', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'Card', child: Text('Card', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'QRIS', child: Text('QRIS', style: TextStyle(fontSize: 14))),
                      ],
                      onChanged: (value) => setState(() => tempPaymentMethod = value),
                    ),
                    SizedBox(height: 16),
                    Text(isId ? 'Kategori Produk' : 'Product Category', style: TextStyle(fontSize: 14)),
                    DropdownButtonFormField<String?>(
                      value: tempCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(isId ? 'Semua' : 'All', style: TextStyle(fontSize: 14))),
                        ...categories.map((category) => DropdownMenuItem(
                          value: category.name,
                          child: Text(category.name, style: TextStyle(fontSize: 14)),
                        )),
                      ],
                      onChanged: (value) => setState(() => tempCategory = value),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isId ? 'Batal' : 'Cancel', style: TextStyle(fontSize: 14)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _startDate = tempStartDate;
                              _endDate = tempEndDate;
                              _selectedPaymentMethod = tempPaymentMethod;
                              _selectedCategory = tempCategory;
                            });
                            Navigator.pop(context);
                            setState(() {}); // Refresh UI
                          },
                          child: Text(isId ? 'Terapkan' : 'Apply', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _exportToCsv() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

    try {
      final transactions = await _getGroupedTransactions();
      final csvData = [
        [
          isId ? 'ID Transaksi' : 'Transaction ID',
          isId ? 'Tanggal' : 'Date',
          isId ? 'Metode Pembayaran' : 'Payment Method',
          isId ? 'Produk' : 'Products',
          isId ? 'Kategori' : 'Category',
          isId ? 'Jumlah' : 'Quantity',
          isId ? 'Harga Satuan' : 'Unit Price',
          isId ? 'Total' : 'Total',
        ],
        ...transactions.expand((t) => (t['items'] as List<Map<String, dynamic>>).map((item) => [
          t['transactionId'],
          _formatDate(t['date'], isId ? 'id' : 'en'),
          t['paymentMethod'],
          item['productName'],
          item['category'],
          item['quantity'].toString(),
          currencyProvider.formatPrice(item['unitPrice']),
          currencyProvider.formatPrice(t['total']),
        ])),
      ];

      final csvString = const ListToCsvConverter().convert(csvData);
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception(isId ? 'Tidak bisa menemukan direktori tujuan' : 'Could not find target directory');
      }

      final path = '${directory.path}/transaction_history_${DateTime.now().toIso8601String()}.csv';
      final file = File(path);
      await file.writeAsString(csvString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isId ? 'Riwayat diekspor ke folder Download' : 'History exported to Download folder'),
          action: SnackBarAction(
            label: isId ? 'Buka' : 'Open',
            onPressed: () async {
              final result = await OpenFile.open(path);
              if (result.type != ResultType.done) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isId ? 'Gagal membuka file: ${result.message}' : 'Failed to open file: ${result.message}'),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isId ? 'Gagal mengekspor data: $e' : 'Failed to export data: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isId = localeProvider.locale.languageCode == 'id';
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isId ? 'Riwayat Transaksi' : 'Transaction History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.primaryColor.withOpacity(0.9),
        actions: [
          IconButton(
            icon: Icon(Icons.download, size: 20),
            onPressed: _exportToCsv,
            tooltip: isId ? 'Ekspor ke CSV' : 'Export to CSV',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'filter') {
                  _showFilterDialog();
                } else {
                  _sortBy = value;
                  _sortAscending = !_sortAscending;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'filter',
                child: Text(isId ? 'Filter' : 'Filter', style: TextStyle(fontSize: 14)),
              ),
              PopupMenuItem(
                value: 'date',
                child: Text(isId ? 'Urutkan Tanggal' : 'Sort by Date', style: TextStyle(fontSize: 14)),
              ),
              PopupMenuItem(
                value: 'total',
                child: Text(isId ? 'Urutkan Total' : 'Sort by Total', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: isId ? 'Cari transaksi...' : 'Search transactions...',
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              style: TextStyle(fontSize: 14),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getGroupedTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      isId ? 'Belum ada transaksi.' : 'No transactions yet.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  );
                }
                final transactions = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                  physics: ClampingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                      child: InkWell(
                        onTap: () => _showTransactionDetails(context, transaction),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isId
                                        ? 'Transaksi #${transaction['transactionId'].substring(0, 8)}'
                                        : 'Transaction #${transaction['transactionId'].substring(0, 8)}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  Chip(
                                    label: Text(
                                      transaction['paymentMethod'],
                                      style: TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    backgroundColor: theme.primaryColor,
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                isId
                                    ? 'Total: ${currencyProvider.formatPrice(transaction['total'])}'
                                    : 'Total: ${currencyProvider.formatPrice(transaction['total'])}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              ),
                              Text(
                                isId
                                    ? 'Tanggal: ${_formatDate(transaction['date'], 'id')}'
                                    : 'Date: ${_formatDate(transaction['date'], 'en')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}