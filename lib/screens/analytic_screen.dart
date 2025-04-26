import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:open_file/open_file.dart';
import '../helper/database_helper.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  String _selectedPeriod = 'daily';
  String _selectedChartType = 'bar';
  int _topProductsLimit = 10;
  DateTimeRange? _dateRange;
  List<int> _showingTooltip = [];

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isId = localeProvider.locale.languageCode == 'id';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isId ? 'Analitik Penjualan' : 'Sales Analytics'),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
                locale: localeProvider.locale,
              );
              if (picked != null) {
                setState(() {
                  _dateRange = picked;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _exportToCsv(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter dan Statistik
            Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Filter & Statistik' : 'Filter & Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPeriod,
                            decoration: InputDecoration(
                              labelText: isId ? 'Periode' : 'Period',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'daily', child: Text(isId ? 'Harian' : 'Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text(isId ? 'Mingguan' : 'Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text(isId ? 'Bulanan' : 'Monthly')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPeriod = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedChartType,
                            decoration: InputDecoration(
                              labelText: isId ? 'Jenis Diagram' : 'Chart Type',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: 'bar', child: Text(isId ? 'Batang' : 'Bar')),
                              DropdownMenuItem(value: 'line', child: Text(isId ? 'Garis' : 'Line')),
                              DropdownMenuItem(value: 'pie', child: Text(isId ? 'Pie' : 'Pie')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedChartType = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _databaseHelper.getSalesStats(
                        startDate: _dateRange?.start,
                        endDate: _dateRange?.end,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }
                        final stats = snapshot.data ?? {'total_sales': 0, 'avg_transaction': 0, 'transaction_count': 0};
                        final totalSales = stats['total_sales'] as num? ?? 0;
                        final avgTransaction = stats['avg_transaction'] as num? ?? 0;
                        final transactionCount = stats['transaction_count'] as int? ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isId
                                  ? 'Total Penjualan: ${currencyProvider.formatPrice(totalSales.toDouble())}'
                                  : 'Total Sales: ${currencyProvider.formatPrice(totalSales.toDouble())}',
                            ),
                            Text(
                              isId
                                  ? 'Rata-rata Transaksi: ${currencyProvider.formatPrice(avgTransaction.toDouble())}'
                                  : 'Average Transaction: ${currencyProvider.formatPrice(avgTransaction.toDouble())}',
                            ),
                            Text(
                              isId
                                  ? 'Jumlah Transaksi: $transactionCount'
                                  : 'Transaction Count: $transactionCount',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Diagram Penjualan
            Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Penjualan per Periode' : 'Sales by Period',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    AspectRatio(
                      aspectRatio: isMobile ? 1.5 : 2.0,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          key: ValueKey('$_selectedPeriod-$_selectedChartType'),
                          future: _databaseHelper.getSalesByPeriod(
                            _selectedPeriod,
                            startDate: _dateRange?.start,
                            endDate: _dateRange?.end,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(child: Text(isId ? 'Belum ada data penjualan.' : 'No sales data yet.'));
                            }
                            final data = snapshot.data!;
                            final maxY = data.map((e) => e['total_sales'] as double).reduce((a, b) => a > b ? a : b) * 1.2;

                            if (_selectedChartType == 'bar') {
                              return BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: maxY,
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index < data.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Transform.rotate(
                                                angle: isMobile ? -0.5 : 0,
                                                child: Text(
                                                  data[index]['period'],
                                                  style: TextStyle(fontSize: isMobile ? 10 : 12),
                                                ),
                                              ),
                                            );
                                          }
                                          return Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 60,
                                        interval: maxY / 5,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            currencyProvider.formatPrice(value),
                                            style: TextStyle(fontSize: isMobile ? 10 : 12),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      tooltipPadding: const EdgeInsets.all(8),
                                      tooltipMargin: 8,
                                      tooltipRoundedRadius: 4,
                                      tooltipBorder: BorderSide(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                                        width: 1,
                                      ),
                                      getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          currencyProvider.formatPrice(rod.toY),
                                          TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  barGroups: data.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final sales = entry.value['total_sales'] as double;
                                    return BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: sales,
                                          color: Theme.of(context).primaryColor,
                                          width: isMobile ? 8 : 16,
                                        ),
                                      ],
                                      showingTooltipIndicators: _showingTooltip.contains(index) ? [0] : [],
                                    );
                                  }).toList(),
                                ),
                              );
                            } else if (_selectedChartType == 'line') {
                              return LineChart(
                                LineChartData(
                                  maxY: maxY,
                                  gridData: FlGridData(show: true),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index < data.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Transform.rotate(
                                                angle: isMobile ? -0.5 : 0,
                                                child: Text(
                                                  data[index]['period'],
                                                  style: TextStyle(fontSize: isMobile ? 10 : 12),
                                                ),
                                              ),
                                            );
                                          }
                                          return Text('');
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 60,
                                        interval: maxY / 5,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            currencyProvider.formatPrice(value),
                                            style: TextStyle(fontSize: isMobile ? 10 : 12),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      tooltipPadding: const EdgeInsets.all(8),
                                      tooltipMargin: 8,
                                      tooltipRoundedRadius: 4,
                                      tooltipBorder: BorderSide(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                                        width: 1,
                                      ),
                                      getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                                      getTooltipItems: (touchedSpots) {
                                        return touchedSpots.map((spot) {
                                          return LineTooltipItem(
                                            currencyProvider.formatPrice(spot.y),
                                            TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface,
                                              fontSize: isMobile ? 12 : 14,
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: data.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final sales = entry.value['total_sales'] as double;
                                        return FlSpot(index.toDouble(), sales);
                                      }).toList(),
                                      isCurved: true,
                                      color: Theme.of(context).primaryColor,
                                      dotData: FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: isMobile ? 30 : 50,
                                  sections: data.asMap().entries.map((entry) {
                                    final sales = entry.value['total_sales'] as double;
                                    final total = data.fold<double>(0, (sum, e) => sum + (e['total_sales'] as double));
                                    final percentage = (sales / total * 100).toStringAsFixed(1);
                                    return PieChartSectionData(
                                      value: sales,
                                      title: '$percentage%',
                                      radius: isMobile ? 60 : 80,
                                      color: Colors.primaries[entry.key % Colors.primaries.length],
                                      titleStyle: TextStyle(
                                        fontSize: isMobile ? 10 : 12,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Produk Populer
            Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Produk Paling Sering Dibeli' : 'Top Selling Products',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      decoration: InputDecoration(
                        labelText: isId ? 'Jumlah Produk' : 'Number of Products',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _topProductsLimit = int.tryParse(value) ?? 10;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _databaseHelper.getTopProducts(
                        _topProductsLimit,
                        startDate: _dateRange?.start,
                        endDate: _dateRange?.end,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(isId ? 'Belum ada data produk.' : 'No product data yet.');
                        }
                        final products = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ListTile(
                              title: Text(product['name']),
                              subtitle: Text(isId
                                  ? 'Terjual: ${product['total_sold']}'
                                  : 'Sold: ${product['total_sold']}'),
                              onTap: () => _showProductTransactions(context, product['name']),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Kategori Populer
            Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isId ? 'Kategori Populer' : 'Popular Categories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16.0),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _databaseHelper.getTopCategories(
                        startDate: _dateRange?.start,
                        endDate: _dateRange?.end,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Text(isId ? 'Belum ada data kategori.' : 'No category data yet.');
                        }
                        final categories = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return ListTile(
                              title: Text(category['category']),
                              subtitle: Text(isId
                                  ? 'Terjual: ${category['total_sold']}'
                                  : 'Sold: ${category['total_sold']}'),
                              onTap: () => _showCategoryTransactions(context, category['category']),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductTransactions(BuildContext context, String productName) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isId ? 'Transaksi untuk $productName' : 'Transactions for $productName'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _databaseHelper.getTransactionsByProduct(
                productName,
                startDate: _dateRange?.start,
                endDate: _dateRange?.end,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(isId ? 'Belum ada transaksi.' : 'No transactions found.');
                }
                final transactions = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final date = DateTime.parse(transaction['transaction_date']);
                    final formattedDate = DateFormat('dd MMM yyyy').format(date);
                    return ListTile(
                      title: Text(isId ? 'Transaksi #${transaction['transaction_id'].substring(0, 8)}' : 'Transaction #${transaction['transaction_id'].substring(0, 8)}'),
                      subtitle: Text(isId
                          ? 'Jumlah: ${transaction['quantity']} | Total: ${currencyProvider.formatPrice(transaction['total_price'])} | Tanggal: $formattedDate'
                          : 'Quantity: ${transaction['quantity']} | Total: ${currencyProvider.formatPrice(transaction['total_price'])} | Date: $formattedDate'),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Tutup' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryTransactions(BuildContext context, String category) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isId ? 'Transaksi untuk Kategori $category' : 'Transactions for Category $category'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _databaseHelper.getTransactionsByCategory(
                category,
                startDate: _dateRange?.start,
                endDate: _dateRange?.end,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(isId ? 'Belum ada transaksi.' : 'No transactions found.');
                }
                final transactions = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final date = DateTime.parse(transaction['transaction_date']);
                    final formattedDate = DateFormat('dd MMM yyyy').format(date);
                    return ListTile(
                      title: Text(isId ? 'Transaksi #${transaction['transaction_id'].substring(0, 8)}' : 'Transaction #${transaction['transaction_id'].substring(0, 8)}'),
                      subtitle: Text(isId
                          ? 'Produk: ${transaction['name']} | Jumlah: ${transaction['quantity']} | Total: ${currencyProvider.formatPrice(transaction['total_price'])} | Tanggal: $formattedDate'
                          : 'Product: ${transaction['name']} | Quantity: ${transaction['quantity']} | Total: ${currencyProvider.formatPrice(transaction['total_price'])} | Date: $formattedDate'),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Tutup' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToCsv(BuildContext context) async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

    try {
      // Ambil data dari database
      final salesData = await _databaseHelper.getSalesByPeriod(
        _selectedPeriod,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      final topProducts = await _databaseHelper.getTopProducts(
        _topProductsLimit,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      final topCategories = await _databaseHelper.getTopCategories(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      // Buat data CSV
      final csvData = [
        [isId ? 'Penjualan per Periode' : 'Sales by Period'],
        [isId ? 'Periode' : 'Period', isId ? 'Total Penjualan' : 'Total Sales'],
        ...salesData.map((e) => [e['period'], currencyProvider.formatPrice(e['total_sales'])]),
        [],
        [isId ? 'Produk Paling Sering Dibeli' : 'Top Selling Products'],
        [isId ? 'Nama Produk' : 'Product Name', isId ? 'Terjual' : 'Sold'],
        ...topProducts.map((e) => [e['name'], e['total_sold']]),
        [],
        [isId ? 'Kategori Populer' : 'Popular Categories'],
        [isId ? 'Kategori' : 'Category', isId ? 'Terjual' : 'Sold'],
        ...topCategories.map((e) => [e['category'], e['total_sold']]),
      ];

      // Konversi ke CSV
      final csvString = const ListToCsvConverter().convert(csvData);

      // Tentukan direktori tujuan
      Directory? directory;
      if (Platform.isAndroid) {
        // Simpan ke /Download di Android (Scoped Storage)
        directory = await getDownloadsDirectory();
      } else if (Platform.isIOS) {
        // Simpan ke Documents aplikasi di iOS
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception(isId ? 'Tidak bisa menemukan direktori tujuan' : 'Could not find target directory');
      }

      // Simpan file
      final path = '${directory.path}/sales_analytics_${DateTime.now().toIso8601String()}.csv';
      final file = File(path);
      await file.writeAsString(csvString);

      // Notifikasi user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isId ? 'Data diekspor ke folder Download' : 'Data exported to Download folder'),
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
}