class Product {
  final int? id;
  final String name;
  final double price;
  final int quantity;
  final String category; // Tambah category

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'category': category,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      quantity: map['quantity'],
      category: map['category'] ?? 'Uncategorized', // Default jika null
    );
  }
}