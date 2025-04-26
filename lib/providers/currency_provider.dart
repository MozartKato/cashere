import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currencySymbol = '\$'; // Default: Rupiah
  String _thousandsSeparator = ','; // Default: Titik
  static const String _currencyKey = 'currency_symbol';
  static const String _separatorKey = 'thousands_separator';

  CurrencyProvider() {
    _loadSettings();
  }

  String get currencySymbol => _currencySymbol;
  String get thousandsSeparator => _thousandsSeparator;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_currencyKey) ?? '\$';
    _thousandsSeparator = prefs.getString(_separatorKey) ?? ',';
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
    notifyListeners();
  }

  Future<void> setThousandsSeparator(String separator) async {
    _thousandsSeparator = separator;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_separatorKey, separator);
    notifyListeners();
  }

  String formatPrice(double price) {
    final intPrice = price.toInt();
    final String priceStr = intPrice.toString();
    String formatted = '';
    int count = 0;

    for (int i = priceStr.length - 1; i >= 0; i--) {
      count++;
      formatted = priceStr[i] + formatted;
      if (count % 3 == 0 && i != 0) {
        formatted = _thousandsSeparator + formatted;
      }
    }

    return '$_currencySymbol $formatted';
  }
}