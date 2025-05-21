import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PrinterProvider with ChangeNotifier {
  Printer? _selectedPrinter;
  bool _isConnected = false;
  String? _errorMessage;
  final FlutterThermalPrinter _thermalPrinter = FlutterThermalPrinter.instance;

  Printer? get selectedPrinter => _selectedPrinter;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;

  static const String _printerKey = 'selected_printer';

  PrinterProvider() {
    _loadPrinterFromPrefs();
  }

  void setPrinter(Printer? printer) async {
    _selectedPrinter = printer;
    _isConnected = false; // Reset koneksi pas ganti printer
    notifyListeners();
    await _savePrinterToPrefs();
    if (printer != null) {
      await _tryReconnect();
    }
  }

  Future<void> connect() async {
    if (_selectedPrinter == null) {
      _errorMessage = 'Pilih printer dulu, goblok!';
      notifyListeners();
      return;
    }
    try {
      if (!_isConnected) {
        await _thermalPrinter
            .connect(_selectedPrinter!)
            .timeout(const Duration(seconds: 5), onTimeout: () => throw 'Koneksi timeout, anjir!');
        _isConnected = true;
        _errorMessage = null;
      }
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Gagal connect: $e';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_selectedPrinter == null || !_isConnected) return;
    try {
      await _thermalPrinter.disconnect(_selectedPrinter!);
      _isConnected = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal disconnect: $e';
      notifyListeners();
    }
  }

  Future<void> printData(List<int> data) async {
    if (_selectedPrinter == null) {
      _errorMessage = 'Pilih printer dulu, goblok!';
      notifyListeners();
      throw Exception(_errorMessage);
    }
    if (!_isConnected) {
      await connect();
      if (!_isConnected) {
        throw Exception(_errorMessage ?? 'Gagal connect ke printer!');
      }
    }
    try {
      // Chunk data (max 237 bytes) buat hindari MTU error
      const chunkSize = 237; // Ganti dari 512 ke 237 berdasarkan log
      for (var i = 0; i < data.length; i += chunkSize) {
        final chunk = data.sublist(i, i + chunkSize < data.length ? i + chunkSize : data.length);
        await _thermalPrinter.printData(_selectedPrinter!, chunk);
        // Delay kecil biar printer gak choke
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await disconnect(); // Disconnect setelah print
    } catch (e) {
      _errorMessage = 'Gagal ngeprint: $e';
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  Future<void> _tryReconnect() async {
    if (_selectedPrinter == null || _isConnected) return;
    try {
      await _thermalPrinter
          .connect(_selectedPrinter!)
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      _isConnected = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Gagal reconnect: $e';
      notifyListeners();
    }
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
        'isConnected': _isConnected,
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
      _isConnected = data['isConnected'] ?? false;
      notifyListeners();
      if (_isConnected) {
        await _tryReconnect();
      }
    } catch (e) {
      debugPrint('Gagal load printer: $e');
      await prefs.remove(_printerKey);
    }
  }

  Future<void> clearPrinter() async {
    await disconnect();
    _selectedPrinter = null;
    _isConnected = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_printerKey);
  }
}