import 'dart:io';

import 'package:flutter/material.dart';

enum ReceiptElementType { text, image, qr, barcode, line, transaction }
enum TextSize { small, medium, large }
enum ReceiptTextAlign { left, center, right }
enum TextFont { normal, bold, monospace }
enum LineStyle { solid, dashed, double, patterned, short, decorative } // Tambah ini

class ReceiptElement {
  ReceiptElementType type;
  dynamic value; // String buat text/qr/barcode/line, File buat image, Map buat transaction
  TextSize? textSize;
  ReceiptTextAlign? textAlign;
  TextFont? textFont;
  LineStyle? lineStyle; // Tambah ini

  ReceiptElement({
    required this.type,
    required this.value,
    this.textSize = TextSize.medium,
    this.textAlign = ReceiptTextAlign.center,
    this.textFont = TextFont.normal,
    this.lineStyle, // Tambah ini
  });
}

class ReceiptBuilderProvider with ChangeNotifier {
  List<ReceiptElement> _elements = [];

  List<ReceiptElement> get elements => _elements;

  void addElement(ReceiptElement element) {
    if (element.type == ReceiptElementType.line && element.value.isNotEmpty) {
      element.value = '';
    }
    if (element.type == ReceiptElementType.text && element.value.isEmpty) {
      throw 'Text gak boleh kosong, bro!';
    }
    if (element.type == ReceiptElementType.qr && element.value.isEmpty) {
      throw 'QR code gak boleh kosong, bro!';
    }
    if (element.type == ReceiptElementType.barcode && (element.value.length != 12 || int.tryParse(element.value) == null)) {
      throw 'Barcode UPC-A harus 12 digit angka, anjir!';
    }
    if (element.type == ReceiptElementType.image && (element.value is! File || !element.value.existsSync())) {
      throw 'Gambar gak valid, bro!';
    }
    _elements.add(element);
    notifyListeners();
  }

  void updateElementStyle(int index, {TextSize? size, ReceiptTextAlign? align, TextFont? font, LineStyle? lineStyle}) {
    if (index < 0 || index >= _elements.length) return;
    final element = _elements[index];
    if (element.type == ReceiptElementType.text || element.type == ReceiptElementType.transaction) {
      _elements[index] = ReceiptElement(
        type: element.type,
        value: element.value,
        textSize: size ?? element.textSize,
        textAlign: align ?? element.textAlign,
        textFont: font ?? element.textFont,
        lineStyle: element.lineStyle, // Preserve lineStyle
      );
    } else if (element.type == ReceiptElementType.line && lineStyle != null) {
      _elements[index] = ReceiptElement(
        type: element.type,
        value: element.value,
        textSize: element.textSize,
        textAlign: element.textAlign,
        textFont: element.textFont,
        lineStyle: lineStyle,
      );
    }
    notifyListeners();
  }

  void removeElement(int index) {
    if (index >= 0 && index < _elements.length) {
      _elements.removeAt(index);
      notifyListeners();
    }
  }

  void moveElement(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _elements.length || newIndex < 0 || newIndex > _elements.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _elements.removeAt(oldIndex);
    _elements.insert(newIndex, item);
    notifyListeners();
  }

  void clear() {
    _elements.clear();
    notifyListeners();
  }
}