# Cashere POS

A modern Flutter-based Point of Sale (POS) application for managing products and transactions with a responsive UI, multi-language support, and advanced transaction history features.

---

## ✨ Features

### Product Management
- Add, edit, and delete products.
- Track name, price, quantity, and category.

### Transaction Handling
- Create transactions with multiple products.
- Choose payment methods: Cash, Card, QRIS.
- Real-time cart with total price calculation.

### Transaction History
- View grouped transactions with details.
- Search by transaction ID, product, or category.
- Filter by date range, payment method, or category.
- Sort by date (newest/oldest) or total (high/low).
- Export to CSV in `/Download`.

### Localization
- Supports English and Indonesian.
- Dynamic UI based on `LocaleProvider`.

### Currency Formatting
- Customizable formatting via `CurrencyProvider`.

### UI/UX
- Clean, animated, and responsive design.
- Soft shadows, rounded corners, and smooth transitions.

---

## 🛠 Tech Stack

| Component | Technology |
|:---------|:-----------|
| Framework | Flutter (Dart) |
| Database | SQLite (sqflite) |
| State Management | Provider |
| Dependencies | See table below |

### Key Dependencies

| Package | Version | Purpose |
|:--------|:--------|:--------|
| provider | ^6.1.2 | State management |
| sqflite | ^2.3.3 | SQLite database |
| path_provider | ^2.1.4 | File system access |
| uuid | ^4.4.0 | Unique ID generation |
| intl | ^0.18.1 | Date and currency formatting |
| csv | ^6.0.0 | CSV export |
| open_file | ^3.3.2 | Open exported files |

---

## 📁 Project Structure

```
cashere-pos/
├── lib/
│   ├── helper/
│   │   └── database_helper.dart       # SQLite database operations
│   ├── models/
│   │   ├── product.dart               # Product model
│   │   ├── transaction.dart           # Transaction model
│   │   └── category.dart              # Category model
│   ├── providers/
│   │   ├── locale_provider.dart       # Language management
│   │   └── currency_provider.dart     # Currency formatting
│   ├── screens/
│   │   ├── transaction_screen.dart    # Transaction creation UI
│   │   └── transaction_history_screen.dart # Transaction history UI
│   └── main.dart                      # App entry point
├── LICENSE                             # MIT License
├── README.md                           # Project documentation
└── pubspec.yaml                        # Dependencies and config
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.16+)
- Git
- Android Studio or VS Code

### Installation

Clone the Repository:
```bash
git clone https://github.com/MozartKato/cashere-pos.git
cd cashere-pos
```

Install Dependencies:
```bash
flutter pub get
```

Run the App:
```bash
flutter run
```

Build for Release:
```bash
flutter build apk --release
```

---

## 🗄 Database

**Schema:**
- `products`: id, name, price, quantity, category
- `transactions`: transaction_id, product_id, quantity, total_price, transaction_date, payment_method
- `categories`: name

**Location:**  
`/data/data/com.twohead.cashere/databases/cashere.db`

**Debugging:**  
```bash
adb pull /data/data/com.twohead.cashere/databases/cashere.db
```

---

## 🎮 Usage

### Transaction Screen
- Add products to cart and adjust quantities.
- Select payment method (Cash, Card, QRIS).
- View real-time cart total and checkout.

### Transaction History Screen
- View grouped transactions with full details.
- **Search:** Filter by transaction ID, product, or category.
- **Filter:** By date range, payment method, or category.
- **Sort:** By date or total.
- **Export:** Save history as CSV to `/Download`.

---

## 🧪 Testing

- **UI:** Verify animations, responsiveness, and fonts (Roboto, 14sp/12sp).
- **Functionality:** Test cart operations and checkout with various payment methods. Validate search, filter, sort, and CSV export.
- **Performance:** Test with 100+ transactions for smooth scrolling. Monitor memory with:
  ```bash
  flutter run --release --profile
  ```
- **Compatibility:** Tested on Android 14 with Scoped Storage.

---

## 📈 Optimization

- **Database:**
  ```sql
  CREATE INDEX idx_transactions_transaction_id ON transactions(transaction_id);
  ```
- **Pagination:** For transaction lists >1000 entries.
- **Caching:** Cache products in memory.

---

## 🤝 Contributing

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/<feature-name>
   ```
3. Commit your changes:
   ```bash
   git commit -m "Add <feature-name>"
   ```
4. Push to your branch:
   ```bash
   git push origin feature/<feature-name>
   ```
5. Open a pull request.

---

## 📜 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 🙌 Acknowledgments

- Flutter for an awesome framework.
- SQLite for reliable storage.
- GitHub for hosting.

---

⭐ **Star this repo if you find it useful!**  
💬 **Open issues or submit PRs for improvements!**