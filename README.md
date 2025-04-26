Cashere POS
A Flutter-based Point of Sale (POS) application for managing products and transactions with a modern, responsive UI and multi-language support.
Features

Product Management: Add, update, and view products with name, price, quantity, and category.
Transaction Handling: Create transactions with multiple products, select payment methods (Cash, Card, QRIS), and view cart.
Transaction History: View grouped transaction history with search, filter (date, payment method, category), sort (date, total), and export to CSV.
Multi-Language: Supports English and Indonesian via LocaleProvider.
Currency Formatting: Dynamic currency formatting via CurrencyProvider.
Database: SQLite with sqflite for persistent storage.
Modern UI: Clean, animated, and responsive design with shadow effects, rounded corners, and subtle transitions.

Tech Stack

Framework: Flutter (Dart)
Database: SQLite (sqflite)
State Management: Provider
Dependencies:
provider: ^6.1.2
sqflite: ^2.3.3
path_provider: ^2.1.4
path: ^1.8.3
uuid: ^4.4.0
intl: ^0.18.1
csv: ^6.0.0
open_file: ^3.3.2



Project Structure
lib/
├── helper/
│   └── database_helper.dart       # SQLite database operations
├── models/
│   ├── product.dart              # Product model
│   ├── transaction.dart          # Transaction model
│   └── category.dart             # Category model
├── providers/
│   ├── locale_provider.dart      # Language management
│   └── currency_provider.dart    # Currency formatting
├── screens/
│   ├── transaction_screen.dart   # Transaction creation UI
│   └── transaction_history_screen.dart # Transaction history UI
└── main.dart                     # App entry point

Setup

Clone Repository:
git clone <repository-url>
cd cashere-pos


Install Dependencies:
flutter pub get


Run the App:
flutter run


Build for Release:
flutter build apk --release



Database

Schema:
products: id, name, price, quantity, category
transactions: transaction_id, product_id, quantity, total_price, transaction_date, payment_method
categories: name


Location: /data/data/com.twohead.cashere/databases/cashere.db
Pull Database (for debugging):adb pull /data/data/com.twohead.cashere/databases/cashere.db



Usage

Transaction Screen:
Add products to cart, adjust quantities, and select payment method.
View cart with total price and checkout.
Supports multi-product transactions.


Transaction History Screen:
View grouped transactions with details (ID, date, payment method, products, total).
Search by transaction ID or product name.
Filter by date range, payment method, or category.
Sort by date or total (ascending/descending).
Export history to CSV in /Download.



Testing

UI: Verify animations, responsiveness, and font consistency (Roboto, 14sp/12sp).
Functionality:
Add/remove products in cart, checkout with different payment methods.
Search, filter, and sort transaction history.
Export CSV and verify file contents.


Performance:
Test with 100+ transactions for smooth scrolling.
Check memory usage: flutter run --release --profile.


Compatibility: Tested on Android 14 with Scoped Storage.

Optimization

Database: Add index for transactions.transaction_id if performance is slow:CREATE INDEX idx_transactions_transaction_id ON transactions(transaction_id);


Pagination: Implement for large transaction lists (>1000).
Caching: Cache products in memory to reduce database queries.

Contributing

Fork the repository.
Create a feature branch: git checkout -b feature-name.
Commit changes: git commit -m "Add feature".
Push to branch: git push origin feature-name.
Open a pull request.

License
MIT License. See LICENSE for details.
