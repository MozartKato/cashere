import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as path;
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static sql.Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sql.Database> _initDatabase() async {
    String dbPath = path.join(await sql.getDatabasesPath(), 'cashere.db');
    return await sql.openDatabase(
      dbPath,
      version: 7,
      onCreate: (db, version) async {
        print('Creating database tables for version $version');
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price REAL,
            quantity INTEGER,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            transaction_id TEXT PRIMARY KEY,
            transaction_date TEXT,
            total_price REAL,
            payment_method TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE transaction_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id TEXT,
            product_id INTEGER,
            quantity INTEGER,
            price REAL,
            FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
            FOREIGN KEY (product_id) REFERENCES products(id)
          )
        ''');
        await db.insert('categories', {'name': 'Minuman'}, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
        await db.insert('categories', {'name': 'Makanan'}, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
        await db.insert('categories', {'name': 'Uncategorized'}, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Upgrading database from version $oldVersion to $newVersion');
        if (oldVersion < 2) {
          print('Adding transaction_id column');
          await db.execute('''
            ALTER TABLE transactions ADD COLUMN transaction_id TEXT
          ''');
          await db.execute('''
            UPDATE transactions SET transaction_id = id WHERE transaction_id IS NULL
          ''');
        }
        if (oldVersion < 3) {
          print('Adding category column to products');
          await db.execute('''
            ALTER TABLE products ADD COLUMN category TEXT
          ''');
          await db.execute('''
            UPDATE products SET category = 'Uncategorized' WHERE category IS NULL
          ''');
        }
        if (oldVersion < 4) {
          print('Adding payment_method column to transactions');
          await db.execute('''
            ALTER TABLE transactions ADD COLUMN payment_method TEXT
          ''');
          await db.execute('''
            UPDATE transactions SET payment_method = 'Unknown' WHERE payment_method IS NULL
          ''');
        }
        if (oldVersion < 5) {
          print('Ensuring payment_method column exists');
          await db.execute('''
            ALTER TABLE transactions ADD COLUMN payment_method TEXT
          ''').catchError((e) {
            print('payment_method column already exists: $e');
          });
          await db.execute('''
            UPDATE transactions SET payment_method = 'Unknown' WHERE payment_method IS NULL
          ''');
        }
        if (oldVersion < 6) {
          print('Creating categories table');
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE
            )
          ''');
          final products = await db.query('products', columns: ['category'], distinct: true);
          for (var product in products) {
            if (product['category'] != null) {
              await db.insert('categories', {'name': product['category']}, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
            }
          }
          await db.insert('categories', {'name': 'Uncategorized'}, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
        }
        if (oldVersion < 7) {
          print('Migrating to new transactions and transaction_items tables');
          await db.execute('''
            CREATE TABLE new_transactions (
              transaction_id TEXT PRIMARY KEY,
              transaction_date TEXT,
              total_price REAL,
              payment_method TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE transaction_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              transaction_id TEXT,
              product_id INTEGER,
              quantity INTEGER,
              price REAL,
              FOREIGN KEY (transaction_id) REFERENCES new_transactions(transaction_id),
              FOREIGN KEY (product_id) REFERENCES products(id)
            )
          ''');
          final oldTransactions = await db.query('transactions');
          for (var old in oldTransactions) {
            final transactionId = old['transaction_id'] as String;
            final totalPrice = old['total_price'] as double;
            final transactionDate = old['transaction_date'] as String;
            final paymentMethod = old['payment_method'] as String? ?? 'Unknown';
            final productId = old['product_id'] as int;
            final quantity = old['quantity'] as int;
            final price = totalPrice / quantity;

            await db.insert('new_transactions', {
              'transaction_id': transactionId,
              'transaction_date': transactionDate,
              'total_price': totalPrice,
              'payment_method': paymentMethod,
            });
            await db.insert('transaction_items', {
              'transaction_id': transactionId,
              'product_id': productId,
              'quantity': quantity,
              'price': price,
            });
          }
          await db.execute('DROP TABLE transactions');
          await db.execute('ALTER TABLE new_transactions RENAME TO transactions');
        }
      },
    );
  }

  // Product methods
  Future<void> insertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateProductQuantity(int productId, int newQuantity) async {
    final db = await database;
    await db.update(
      'products',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // Category methods
  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.ignore);
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<bool> canDeleteCategory(int id) async {
    final db = await database;
    final category = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (category.isEmpty) return false;
    final categoryName = category.first['name'];
    final products = await db.query('products', where: 'category = ?', whereArgs: [categoryName]);
    return products.isEmpty;
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Transaction methods
  Future<void> insertTransaction(Transaction transaction) async {
    final db = await database;
    await db.insert('transactions', transaction.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  // Transaction Item methods
  Future<void> insertTransactionItem(TransactionItem item) async {
    final db = await database;
    await db.insert('transaction_items', item.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  // Query untuk analytics: Penjualan per periode
  Future<List<Map<String, dynamic>>> getSalesByPeriod(String period, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String groupBy;
    String dateFormat;

    switch (period) {
      case 'daily':
        groupBy = "DATE(transaction_date)";
        dateFormat = '%Y-%m-%d';
        break;
      case 'weekly':
        groupBy = "STRFTIME('%Y-%W', transaction_date)";
        dateFormat = '%Y-%W';
        break;
      case 'monthly':
        groupBy = "STRFTIME('%Y-%m', transaction_date)";
        dateFormat = '%Y-%m';
        break;
      default:
        groupBy = "DATE(transaction_date)";
        dateFormat = '%Y-%m-%d';
    }

    String query = '''
      SELECT STRFTIME('$dateFormat', transaction_date) as period,
             SUM(total_price) as total_sales
      FROM transactions
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' GROUP BY $groupBy ORDER BY period DESC LIMIT 30';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  // Query untuk produk populer
  Future<List<Map<String, dynamic>>> getTopProducts(int limit, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT p.name, SUM(ti.quantity) as total_sold
      FROM transaction_items ti
      JOIN products p ON ti.product_id = p.id
      JOIN transactions t ON ti.transaction_id = t.transaction_id
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE t.transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' GROUP BY ti.product_id ORDER BY total_sold DESC LIMIT ?';
    args.add(limit);

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  // Query untuk kategori populer
  Future<List<Map<String, dynamic>>> getTopCategories({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT p.category, SUM(ti.quantity) as total_sold
      FROM transaction_items ti
      JOIN products p ON ti.product_id = p.id
      JOIN transactions t ON ti.transaction_id = t.transaction_id
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE t.transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' GROUP BY p.category ORDER BY total_sold DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  // Query untuk detail transaksi per produk
  Future<List<Map<String, dynamic>>> getTransactionsByProduct(String productName, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT t.transaction_id, ti.quantity, ti.price, t.transaction_date, t.payment_method
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.transaction_id
      JOIN products p ON ti.product_id = p.id
      WHERE p.name = ?
    ''';
    List<dynamic> args = [productName];

    if (startDate != null && endDate != null) {
      query += ' AND t.transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY t.transaction_date DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  // Query untuk detail transaksi per kategori
  Future<List<Map<String, dynamic>>> getTransactionsByCategory(String category, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT t.transaction_id, ti.quantity, ti.price, t.transaction_date, p.name, t.payment_method
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.transaction_id
      JOIN products p ON ti.product_id = p.id
      WHERE p.category = ?
    ''';
    List<dynamic> args = [category];

    if (startDate != null && endDate != null) {
      query += ' AND t.transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' ORDER BY t.transaction_date DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps;
  }

  // Query untuk statistik tambahan
  Future<Map<String, dynamic>> getSalesStats({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String query = '''
      SELECT SUM(total_price) as total_sales,
             AVG(total_price) as avg_transaction,
             COUNT(DISTINCT transaction_id) as transaction_count
      FROM transactions
    ''';
    List<dynamic> args = [];

    if (startDate != null && endDate != null) {
      query += ' WHERE transaction_date BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.isNotEmpty ? maps.first : {'total_sales': 0, 'avg_transaction': 0, 'transaction_count': 0};
  }
}