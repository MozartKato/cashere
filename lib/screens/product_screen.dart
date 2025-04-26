import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../helper/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import 'category_management_screen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'name';
  bool _sortAscending = true;
  List<int> _selectedProductIds = [];
  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    List<Product> products = await _databaseHelper.getAllProducts();
    List<Category> categories = await _databaseHelper.getAllCategories();
    setState(() {
      _products = products;
      _categories = categories;
      _filteredProducts = products;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Product> filtered = _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      int compare;
      switch (_sortBy) {
        case 'price':
          compare = a.price.compareTo(b.price);
          break;
        case 'quantity':
          compare = a.quantity.compareTo(b.quantity);
          break;
        case 'category':
          compare = a.category.compareTo(b.category);
          break;
        default:
          compare = a.name.compareTo(b.name);
      }
      return _sortAscending ? compare : -compare;
    });

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _showAddProductDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    String? selectedCategory;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Tambah Produk' : 'Add Product'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Nama Produk' : 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? (isId ? 'Masukkan nama' : 'Enter name') : null,
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Harga' : 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return isId ? 'Masukkan harga' : 'Enter price';
                      if (double.tryParse(value) == null) return isId ? 'Harga tidak valid' : 'Invalid price';
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Jumlah' : 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return isId ? 'Masukkan jumlah' : 'Enter quantity';
                      if (int.tryParse(value) == null) return isId ? 'Jumlah tidak valid' : 'Invalid quantity';
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: isId ? 'Kategori' : 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._categories.map((category) => DropdownMenuItem(
                        value: category.name,
                        child: Text(category.name, style: TextStyle(fontSize: 14)),
                      )),
                      DropdownMenuItem(
                        value: 'add_new',
                        child: Text(isId ? 'Tambah Kategori Baru' : 'Add New Category', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new') {
                        final newCategory = await _showAddCategoryDialog();
                        if (newCategory != null) {
                          setState(() {
                            selectedCategory = newCategory.name;
                            _categories.add(newCategory);
                          });
                        }
                      } else {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                    validator: (value) => value == null ? (isId ? 'Pilih kategori' : 'Select category') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final product = Product(
                    name: nameController.text,
                    price: double.parse(priceController.text),
                    quantity: int.parse(quantityController.text),
                    category: selectedCategory!,
                  );
                  _databaseHelper.insertProduct(product).then((_) {
                    _loadData();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isId ? 'Produk ditambahkan' : 'Product added')),
                    );
                  });
                }
              },
              child: Text(isId ? 'Simpan' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<Category?> _showAddCategoryDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    return showDialog<Category>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Tambah Kategori' : 'Add Category'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isId ? 'Nama Kategori' : 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? (isId ? 'Masukkan nama kategori' : 'Enter category name') : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final category = Category(name: nameController.text);
                  _databaseHelper.insertCategory(category).then((_) {
                    Navigator.pop(context, category);
                  });
                }
              },
              child: Text(isId ? 'Simpan' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProductDialog(Product product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toString());
    final quantityController = TextEditingController(text: product.quantity.toString());
    String? selectedCategory = product.category;
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Edit Produk' : 'Edit Product'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Nama Produk' : 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? (isId ? 'Masukkan nama' : 'Enter name') : null,
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Harga' : 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return isId ? 'Masukkan harga' : 'Enter price';
                      if (double.tryParse(value) == null) return isId ? 'Harga tidak valid' : 'Invalid price';
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: isId ? 'Jumlah' : 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value!.isEmpty) return isId ? 'Masukkan jumlah' : 'Enter quantity';
                      if (int.tryParse(value) == null) return isId ? 'Jumlah tidak valid' : 'Invalid quantity';
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: isId ? 'Kategori' : 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._categories.map((category) => DropdownMenuItem(
                        value: category.name,
                        child: Text(category.name, style: TextStyle(fontSize: 14)),
                      )),
                      DropdownMenuItem(
                        value: 'add_new',
                        child: Text(isId ? 'Tambah Kategori Baru' : 'Add New Category', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new') {
                        final newCategory = await _showAddCategoryDialog();
                        if (newCategory != null) {
                          setState(() {
                            selectedCategory = newCategory.name;
                            _categories.add(newCategory);
                          });
                        }
                      } else {
                        setState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                    validator: (value) => value == null ? (isId ? 'Pilih kategori' : 'Select category') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final updatedProduct = Product(
                    id: product.id,
                    name: nameController.text,
                    price: double.parse(priceController.text),
                    quantity: int.parse(quantityController.text),
                    category: selectedCategory!,
                  );
                  _databaseHelper.updateProduct(updatedProduct).then((_) {
                    _loadData();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isId ? 'Produk diperbarui' : 'Product updated')),
                    );
                  });
                }
              },
              child: Text(isId ? 'Simpan' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct(int id) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Hapus Produk' : 'Delete Product'),
          content: Text(isId ? 'Yakin ingin menghapus produk ini?' : 'Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _databaseHelper.deleteProduct(id).then((_) {
                  _loadData();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isId ? 'Produk dihapus' : 'Product deleted')),
                  );
                });
              },
              child: Text(isId ? 'Hapus' : 'Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteSelectedProducts() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Hapus Produk Terpilih' : 'Delete Selected Products'),
          content: Text(isId
              ? 'Yakin ingin menghapus ${_selectedProductIds.length} produk?'
              : 'Are you sure you want to delete ${_selectedProductIds.length} products?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                for (var id in _selectedProductIds) {
                  _databaseHelper.deleteProduct(id);
                }
                setState(() {
                  _selectedProductIds.clear();
                  _isSelectMode = false;
                });
                _loadData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isId ? 'Produk terpilih dihapus' : 'Selected products deleted')),
                );
              },
              child: Text(isId ? 'Hapus' : 'Delete'),
            ),
          ],
        );
      },
    );
  }

  void _exportToCsv() async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    try {
      final csvData = [
        [isId ? 'Nama Produk' : 'Product Name', isId ? 'Harga' : 'Price', isId ? 'Jumlah' : 'Quantity', isId ? 'Kategori' : 'Category'],
        ..._products.map((p) => [p.name, currencyProvider.formatPrice(p.price), p.quantity, p.category]),
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

      final path = '${directory.path}/products_${DateTime.now().toIso8601String()}.csv';
      final file = File(path);
      await file.writeAsString(csvString);

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

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isId = localeProvider.locale.languageCode == 'id';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final categories = _products.map((p) => p.category).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isId ? 'Daftar Produk' : 'Product List'),
        actions: [
          if (_isSelectMode)
            IconButton(
              icon: Icon(Icons.delete, size: 18),
              onPressed: _selectedProductIds.isNotEmpty ? _deleteSelectedProducts : null,
              tooltip: isId ? 'Hapus Terpilih' : 'Delete Selected',
            ),
          IconButton(
            icon: Icon(Icons.download, size: 18),
            onPressed: _exportToCsv,
            tooltip: isId ? 'Ekspor ke CSV' : 'Export to CSV',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'select') {
                  _isSelectMode = !_isSelectMode;
                  _selectedProductIds.clear();
                } else {
                  _sortBy = value;
                  _sortAscending = !_sortAscending;
                  _applyFilters();
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'select',
                child: Text(isId ? (_isSelectMode ? 'Batalkan Pilihan' : 'Pilih Banyak') : (_isSelectMode ? 'Cancel Selection' : 'Select Multiple')),
              ),
              PopupMenuItem(
                value: 'name',
                child: Text(isId ? 'Urutkan Nama' : 'Sort by Name'),
              ),
              PopupMenuItem(
                value: 'price',
                child: Text(isId ? 'Urutkan Harga' : 'Sort by Price'),
              ),
              PopupMenuItem(
                value: 'quantity',
                child: Text(isId ? 'Urutkan Jumlah' : 'Sort by Quantity'),
              ),
              PopupMenuItem(
                value: 'category',
                child: Text(isId ? 'Urutkan Kategori' : 'Sort by Category'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: isId ? 'Cari produk...' : 'Search products...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: TextStyle(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _selectedCategory,
                      hint: Text(isId ? 'Semua Kategori' : 'All Categories', style: TextStyle(fontSize: 14)),
                      items: [
                        DropdownMenuItem(value: null, child: Text(isId ? 'Semua Kategori' : 'All Categories', style: TextStyle(fontSize: 14))),
                        ...categories.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category, style: TextStyle(fontSize: 14)),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _applyFilters();
                        });
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CategoryManagementScreen()),
                      ).then((_) => _loadData()); // Refresh data setelah kembali
                    },
                    child: Text(isId ? 'Kelola Kategori' : 'Manage Categories'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(child: Text(isId ? 'Tidak ada produk' : 'No products found', style: TextStyle(fontSize: 14)))
                : ListView.builder(
              padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final isLowStock = product.quantity < 5;
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Row(
                      children: [
                        if (_isSelectMode)
                          Checkbox(
                            value: _selectedProductIds.contains(product.id),
                            onChanged: (value) {
                              setState(() {
                                if (value!) {
                                  _selectedProductIds.add(product.id!);
                                } else {
                                  _selectedProductIds.remove(product.id);
                                }
                              });
                            },
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLowStock)
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Chip(
                                        label: Text(isId ? 'Stok Rendah' : 'Low Stock', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: Colors.red,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                isId
                                    ? 'Harga: ${currencyProvider.formatPrice(product.price)} | Jumlah: ${product.quantity} | Kategori: ${product.category}'
                                    : 'Price: ${currencyProvider.formatPrice(product.price)} | Quantity: ${product.quantity} | Category: ${product.category}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditProductDialog(product),
                              tooltip: isId ? 'Edit' : 'Edit',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 18),
                              onPressed: () => _deleteProduct(product.id!),
                              tooltip: isId ? 'Hapus' : 'Delete',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: Icon(Icons.add, size: 18),
        heroTag: 'addProduct',
        elevation: 2,
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}