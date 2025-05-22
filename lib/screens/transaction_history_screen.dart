import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:open_file/open_file.dart';
import '../helper/database_helper.dart';
import '../models/product.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/printer_provider.dart';
import '../providers/receipt_builder_provider.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

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
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _getGroupedTransactions() async {
    final transactions = await _databaseHelper.getAllTransactions();

    final filteredTransactions = transactions.where((t) {
      final matchesSearch = t.transactionId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDate = (_startDate == null && _endDate == null) ||
          (DateTime.parse(t.transactionDate).isAfter(_startDate!) &&
              DateTime.parse(t.transactionDate).isBefore(_endDate!));
      final matchesPayment = _selectedPaymentMethod == null || t.paymentMethod == _selectedPaymentMethod;
      return matchesSearch && matchesDate && matchesPayment;
    }).toList();

    final List<Map<String, dynamic>> result = [];
    for (var transaction in filteredTransactions) {
      final items = await _databaseHelper.getTransactionItems(transaction.transactionId);
      final filteredItems = items.where((item) {
        if (_selectedCategory == null) return true;
        final product = _cachedProducts.firstWhere(
              (p) => p.id == item.productId,
          orElse: () => Product(id: 0, name: '', price: 0, quantity: 0, category: ''),
        );
        return product.category == _selectedCategory;
      }).toList();

      if (filteredItems.isEmpty && _selectedCategory != null) continue;

      final itemDetails = filteredItems.map((item) {
        final product = _cachedProducts.firstWhere(
              (p) => p.id == item.productId,
          orElse: () => Product(id: 0, name: 'Unknown', price: 0, quantity: 0, category: 'Unknown'),
        );
        return {
          'productName': product.name,
          'quantity': item.quantity,
          'unitPrice': item.price,
          'category': product.category,
          'totalPrice': item.price * item.quantity,
        };
      }).toList();

      if (itemDetails.isEmpty) continue;

      result.add({
        'transactionId': transaction.transactionId,
        'total': transaction.totalPrice,
        'date': transaction.transactionDate,
        'paymentMethod': transaction.paymentMethod,
        'items': itemDetails,
      });
    }

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

  Future<void> _printTransaction(BuildContext context, Map<String, dynamic> transaction) async {
    final printerProvider = Provider.of<PrinterProvider>(context, listen: false);
    final builderProvider = Provider.of<ReceiptBuilderProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    // Cek template
    if (builderProvider.elements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Template kosong, goblok!' : 'Template is empty!')),
      );
      return;
    }
    if (!builderProvider.elements.any((el) => el.type == ReceiptElementType.transaction)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Gak ada elemen transaksi di template!' : 'No transaction element in template!')),
      );
      return;
    }

    // Cek printer
    if (printerProvider.selectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Pilih printer dulu, goblok!' : 'Select printer first!')),
      );
      return;
    }

    // Cek koneksi BLE
    if (printerProvider.isConnected) {
      print('Already connected, skipping reconnect');
    } else {
      try {
        await printerProvider.connect().timeout(const Duration(seconds: 5));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isId ? 'Gagal connect printer: $e' : 'Failed to connect printer: $e')),
        );
        return;
      }
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    try {
      for (var el in builderProvider.elements) {
        switch (el.type) {
          case ReceiptElementType.text:
            bytes += generator.text(
              el.value,
              styles: PosStyles(
                bold: el.textFont == TextFont.bold,
                height: _mapTextSize(el.textSize),
                width: _mapTextSize(el.textSize),
                align: _mapTextAlign(el.textAlign),
                codeTable: 'CP437',
              ),
            );
            break;
          case ReceiptElementType.qr:
            bytes += generator.qrcode(el.value);
            break;
          case ReceiptElementType.barcode:
            if (el.value.length != 12 || int.tryParse(el.value) == null) {
              throw 'Barcode UPC-A harus 12 digit angka, anjir!';
            }
            bytes += generator.barcode(Barcode.upcA(el.value.split('').map(int.parse).toList()));
            break;
          case ReceiptElementType.line:
            final style = el.lineStyle ?? LineStyle.solid;
            switch (style) {
              case LineStyle.solid:
                bytes += generator.hr();
                break;
              case LineStyle.dashed:
                bytes += generator.text('- ' * 16, styles: const PosStyles(align: PosAlign.center));
                break;
              case LineStyle.double:
                bytes += generator.text('=' * 32, styles: const PosStyles(align: PosAlign.center, bold: true));
                break;
              case LineStyle.patterned:
                bytes += generator.text('-*-' * 8, styles: const PosStyles(align: PosAlign.center));
                break;
              case LineStyle.short:
                bytes += generator.text('-' * 20, styles: const PosStyles(align: PosAlign.center));
                break;
              case LineStyle.decorative:
                bytes += generator.text('~' * 32, styles: const PosStyles(align: PosAlign.center));
                break;
            }
            break;
          case ReceiptElementType.image:
            final file = el.value as File;
            if (!file.existsSync()) throw 'Gambar gak ada, bro!';
            final image = img.decodeImage(await file.readAsBytes());
            if (image == null) throw 'Gagal decode gambar, anjir!';
            final resized = img.copyResize(image, width: 384);
            final mono = img.grayscale(resized);
            final pixels = mono.getBytes();
            final bitmap = img.Image.fromBytes(width: mono.width, height: mono.height, bytes: pixels.buffer);
            bytes += generator.image(bitmap);
            break;
          case ReceiptElementType.transaction:
          // Ganti dummy data dengan transaksi asli
            final trans = transaction;
            for (var item in trans['items']) {
              final name = item['productName'].toString().padRight(18).substring(0, 18);
              final qty = item['quantity'].toString().padLeft(4);
              final price = item['unitPrice'].toStringAsFixed(0).padLeft(10);
              bytes += generator.text(
                '$name$qty$price',
                styles: PosStyles(
                  bold: false,
                  height: _mapTextSize(el.textSize),
                  width: _mapTextSize(el.textSize),
                  align: _mapTextAlign(el.textAlign),
                  codeTable: 'CP437',
                ),
              );
            }
            bytes += generator.text(
              'Total: ${trans['total'].toStringAsFixed(0)}'.padLeft(32),
              styles: PosStyles(
                bold: true,
                height: _mapTextSize(el.textSize),
                width: _mapTextSize(el.textSize),
                align: PosAlign.right,
                codeTable: 'CP437',
              ),
            );
            break;
        }
      }

      bytes += generator.cut();

      print('Printer connected: ${printerProvider.isConnected}');
      print('Bytes length: ${bytes.length}');
      await printerProvider.printData(bytes).timeout(const Duration(seconds: 10));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Print sukses, bro! 🎉' : 'Print successful! 🎉')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isId ? 'Gagal print: $e' : 'Failed to print: $e')),
      );
    }
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    final items = transaction['items'] as List<Map<String, dynamic>>;

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 12),
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
                ...items.map((item) => Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['productName'],
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Text(
                          isId ? 'Kategori: ${item['category']}' : 'Category: ${item['category']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        Text(
                          isId
                              ? 'Jumlah: ${item['quantity']} x ${currencyProvider.formatPrice(item['unitPrice'])}'
                              : 'Quantity: ${item['quantity']} x ${currencyProvider.formatPrice(item['unitPrice'])}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        Text(
                          isId
                              ? 'Total: ${currencyProvider.formatPrice(item['totalPrice'])}'
                              : 'Total: ${currencyProvider.formatPrice(item['totalPrice'])}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _printTransaction(context, transaction),
                        child: Text(isId ? 'Print' : 'Print', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Colors.green,
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(isId ? 'Tutup' : 'Close', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: isBold ? Theme.of(context).primaryColor : Colors.grey[800],
            ),
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
      builder: (context) => Dialog(
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(isId ? 'Rentang Tanggal' : 'Date Range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
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
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
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
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(isId ? 'Metode Pembayaran' : 'Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                DropdownButtonFormField<String?>(
                  value: tempPaymentMethod,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey[100],
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
                Text(isId ? 'Kategori Produk' : 'Product Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                DropdownButtonFormField<String?>(
                  value: tempCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey[100],
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
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isId ? 'Batal' : 'Cancel', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _startDate = tempStartDate;
                          _endDate = tempEndDate;
                          _selectedPaymentMethod = tempPaymentMethod;
                          _selectedCategory = tempCategory;
                        });
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text(isId ? 'Terapkan' : 'Apply', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Theme.of(context).primaryColor,
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
          isId ? 'Total Item' : 'Item Total',
          isId ? 'Total Transaksi' : 'Transaction Total',
        ],
        ...transactions.expand((t) => (t['items'] as List<Map<String, dynamic>>).map((item) => [
          t['transactionId'],
          _formatDate(t['date'], isId ? 'id' : 'en'),
          t['paymentMethod'],
          item['productName'],
          item['category'],
          item['quantity'].toString(),
          currencyProvider.formatPrice(item['unitPrice']),
          currencyProvider.formatPrice(item['totalPrice']),
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

  PosTextSize _mapTextSize(TextSize? size) {
    switch (size) {
      case TextSize.small:
        return PosTextSize.size1;
      case TextSize.medium:
        return PosTextSize.size1;
      case TextSize.large:
        return PosTextSize.size2;
      default:
        return PosTextSize.size1;
    }
  }

  PosAlign _mapTextAlign(ReceiptTextAlign? align) {
    switch (align) {
      case ReceiptTextAlign.left:
        return PosAlign.left;
      case ReceiptTextAlign.right:
        return PosAlign.right;
      case ReceiptTextAlign.center:
      default:
        return PosAlign.center;
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
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, size: 24),
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
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: isId ? 'Cari transaksi...' : 'Search transactions...',
                prefixIcon: Icon(Icons.search, size: 24, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              style: TextStyle(fontSize: 14),
              onChanged: (value) {
                setState(() => _searchQuery = value);
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          isId ? 'Belum ada transaksi' : 'No transactions yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }
                final transactions = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  physics: ClampingScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Chip(
                                    label: Text(
                                      transaction['paymentMethod'],
                                      style: TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                    backgroundColor: theme.primaryColor,
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                isId
                                    ? 'Total: ${currencyProvider.formatPrice(transaction['total'])}'
                                    : 'Total: ${currencyProvider.formatPrice(transaction['total'])}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryColor),
                              ),
                              Text(
                                isId
                                    ? 'Tanggal: ${_formatDate(transaction['date'], 'id')}'
                                    : 'Date: ${_formatDate(transaction['date'], 'en')}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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