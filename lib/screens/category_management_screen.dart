import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helper/database_helper.dart';
import '../models/category.dart';
import '../providers/locale_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  @override
  _CategoryManagementScreenState createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    List<Category> categories = await _databaseHelper.getAllCategories();
    setState(() {
      _categories = categories;
    });
  }

  void _showAddCategoryDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
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
                    _loadCategories();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isId ? 'Kategori ditambahkan' : 'Category added')),
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

  void _showEditCategoryDialog(Category category) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category.name);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Edit Kategori' : 'Edit Category'),
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
                  final updatedCategory = Category(id: category.id, name: nameController.text);
                  _databaseHelper.updateCategory(updatedCategory).then((_) {
                    _loadCategories();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isId ? 'Kategori diperbarui' : 'Category updated')),
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

  void _deleteCategory(int id) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isId = localeProvider.locale.languageCode == 'id';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isId ? 'Hapus Kategori' : 'Delete Category'),
          content: Text(isId ? 'Yakin ingin menghapus kategori ini?' : 'Are you sure you want to delete this category?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final canDelete = await _databaseHelper.canDeleteCategory(id);
                if (!canDelete) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isId
                          ? 'Kategori tidak bisa dihapus karena masih digunakan oleh produk'
                          : 'Category cannot be deleted because it is still used by products'),
                    ),
                  );
                  return;
                }
                _databaseHelper.deleteCategory(id).then((_) {
                  _loadCategories();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isId ? 'Kategori dihapus' : 'Category deleted')),
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

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isId = localeProvider.locale.languageCode == 'id';
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isId ? 'Kelola Kategori' : 'Manage Categories'),
      ),
      body: _categories.isEmpty
          ? Center(child: Text(isId ? 'Tidak ada kategori' : 'No categories found', style: TextStyle(fontSize: 14)))
          : ListView.builder(
        padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(category.name, style: TextStyle(fontSize: 14)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditCategoryDialog(category),
                    tooltip: isId ? 'Edit' : 'Edit',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 18),
                    onPressed: () => _deleteCategory(category.id!),
                    tooltip: isId ? 'Hapus' : 'Delete',
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: Icon(Icons.add, size: 18),
        heroTag: 'addCategory',
        elevation: 2,
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}