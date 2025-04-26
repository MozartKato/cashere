class Transaction {
  final String transactionId;
  final int productId;
  final int quantity;
  final double totalPrice;
  final String transactionDate;
  final String paymentMethod;

  Transaction({
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.totalPrice,
    required this.transactionDate,
    required this.paymentMethod,
  });

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'product_id': productId,
      'quantity': quantity,
      'total_price': totalPrice,
      'transaction_date': transactionDate,
      'payment_method': paymentMethod,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      totalPrice: map['total_price'],
      transactionDate: map['transaction_date'],
      paymentMethod: map['payment_method'] ?? 'Unknown',
    );
  }
}