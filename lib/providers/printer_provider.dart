import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PrinterProvider with ChangeNotifier {
  Printer? _selectedPrinter;

  Printer? get selectedPrinter => _selectedPrinter;

  static const String _printerKey = 'selected_printer'; // Definisikan _printerKey

  PrinterProvider() {
    _loadPrinterFromPrefs();
  }

  void setPrinter(Printer? printer) async {
    _selectedPrinter = printer;
    notifyListeners();
    await _savePrinterToPrefs();
  }

  Future<void> _savePrinterToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedPrinter == null) {
      await prefs.remove(_printerKey);
      return;
    }

    try {
      final printerJson = jsonEncode({
        'name': _selectedPrinter!.name,
        'address': _selectedPrinter!.address,
        'vendorId': _selectedPrinter!.vendorId,
        'productId': _selectedPrinter!.productId,
        'connectionType': _selectedPrinter!.connectionType?.index ?? 0,
      });
      await prefs.setString(_printerKey, printerJson);
    } catch (e) {
      debugPrint('Gagal simpan printer: $e');
    }
  }

  Future<void> _loadPrinterFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final printerJson = prefs.getString(_printerKey);

    if (printerJson == null) return;

    try {
      final data = jsonDecode(printerJson);
      _selectedPrinter = Printer(
        name: data['name'] ?? 'Unknown',
        address: data['address'] ?? '',
        vendorId: data['vendorId'],
        productId: data['productId'],
        connectionType: ConnectionType.values[data['connectionType'] ?? 0],
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal load printer: $e');
      await prefs.remove(_printerKey); // Bersihin kalau data corrupt
    }
  }

  Future<void> clearPrinter() async {
    _selectedPrinter = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerKey);
  }
}