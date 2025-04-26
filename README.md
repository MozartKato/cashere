Cashere POS

A Flutter-based Point of Sale (POS) application for managing products and transactions. Features a modern, responsive UI with multi-language support, transaction history, and CSV export.
📋 Features

Product Management: Add, edit, and view products (name, price, quantity, category).
Transaction Handling: Create multi-product transactions, select payment methods (Cash, Card, QRIS), and manage cart.
Transaction History: View grouped transactions with search, filter (date, payment method, category), sort (date, total), and export to CSV.
Localization: Supports English and Indonesian via LocaleProvider.
Currency Formatting: Dynamic currency formatting with CurrencyProvider.
Database: SQLite for persistent storage using sqflite.
UI/UX: Clean, animated, responsive design with soft shadows, rounded corners, and smooth transitions.

🛠 Tech Stack

Framework: Flutter (Dart)
Database: SQLite (sqflite)
State Management: Provider
Key Dependencies:
provider: ^6.1.2
sqflite: ^2.3.3
path_provider: ^2.1.4
uuid: ^4.4.0
intl: ^0.18.1
csv: ^6.0.0
open_file: ^3.3.2



📁 Project Structure
cashere-pos/
├── lib/
│   ├── helper/
│   │   └── database_helper.dart       # SQLite database operations
│   ├── models/
│   │   ├── product.dart              # Product model
│   │   ├── transaction.dart          # Transaction model
│   │   └── category.dart             # Category model
│   ├── providers/
│   │   ├── locale_provider.dart      # Language management
│   │   └── currency_provider.dart    # Currency formatting
│   ├── screens/
│   │   ├── transaction_screen.dart   # Transaction creation UI
│   │   └── transaction_history_screen.dart # Transaction history UI
│   └── main.dart                     # App entry point
├── LICENSE                           # MIT License
├── README.md                         # Project documentation
└── pubspec.yaml                      # Dependencies and config

🚀 Getting Started
Prerequisites

Flutter SDK: Install
Git: Install
Android Studio or VS Code

Installation

Clone the Repository:
git clone https://github.com/<username>/cashere-pos.git
cd cashere-pos


Install Dependencies:
flutter pub get


Run the App:
flutter run


Build for Release:
flutter build apk --release



🗄 Database

Schema:
products: id, name, price, quantity, category
transactions: transaction_id, product_id, quantity, total_price, transaction_date, payment_method
categories: name


Location: /data/data/com.twohead.cashere/databases/cashere.db
Debugging:adb pull /data/data/com.twohead.cashere/databases/cashere.db



🎮 Usage
Transaction Screen

Add products to cart, adjust quantities, and select payment method (Cash, Card, QRIS).
View real-time cart total and checkout.
Supports multiple products per transaction.

Transaction History Screen

View grouped transactions with details (ID, date, payment method, products, total).
Search: By transaction ID, product name, or category.
Filter: By date range, payment method, or product category.
Sort: By date (newest/oldest) or total (high/low).
Export: Save history as CSV to /Download.

🧪 Testing

UI: Verify animations, responsiveness, and font consistency (Roboto, 14sp/12sp).
Functionality:
Test cart operations and checkout with different payment methods.
Validate search, filter, sort, and CSV export in transaction history.


Performance:
Test with 100+ transactions for smooth scrolling.
Monitor memory: flutter run --release --profile.


Compatibility: Tested on Android 14 with Scoped Storage.

📈 Optimization

Database: Add index for large datasets:CREATE INDEX idx_transactions_transaction_id ON transactions(transaction_id);


Pagination: Implement for transaction lists >1000.
Caching: Cache products in memory to reduce database queries.

🤝 Contributing

Fork the repository.
Create a feature branch:git checkout -b feature/<feature-name>


Commit changes:git commit -m "Add <feature-name>"


Push to branch:git push origin feature/<feature-name>


Open a pull request.

📜 License
This project is licensed under the MIT License. See LICENSE for details.
🙌 Acknowledgments

Flutter community for awesome packages.
SQLite for reliable local storage.
GitHub for hosting and collaboration.


⭐ Star this repo if you find it useful! Feel free to open issues or submit PRs for improvements.
