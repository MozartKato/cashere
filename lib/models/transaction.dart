class Transaction {
  final String transactionId;
  final String transactionDate;
  final double totalPrice;
  final String paymentMethod;

  Transaction({
    required this.transactionId,
    required this.transactionDate,
    required this.totalPrice,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'transaction_date': transactionDate,
      'total_price': totalPrice,
      'payment_method': paymentMethod,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      transactionId: map['transaction_id'],
      transactionDate: map['transaction_date'],
      totalPrice: map['total_price'],
      paymentMethod: map['payment_method'] ?? 'Unknown',
    );
  }
}

class TransactionItem {
  final int? id;
  final String transactionId;
  final int productId;
  final int quantity;
  final double price;

  TransactionItem({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}