import 'package:flutter/material.dart';

enum ReceiptElementType { text, image, qr, barcode, line, transaction }

enum TextSize { small, medium, large }
enum TextAlign { left, center, right }
enum TextFont { normal, bold, monospace }

class ReceiptElement {
  ReceiptElementType type;
  dynamic value; // String buat text/qr/barcode/line, File buat image, Map buat transaction
  TextSize? textSize; // Ukuran teks
  TextAlign? textAlign; // Alignment
  TextFont? textFont; // Font style

  ReceiptElement({
    required this.type,
    required this.value,
    this.textSize = TextSize.medium,
    this.textAlign = TextAlign.center,
    this.textFont = TextFont.normal,
  });
}

class ReceiptBuilderProvider with ChangeNotifier {
  List<ReceiptElement> _elements = [];

  List<ReceiptElement> get elements => _elements;

  void addElement(ReceiptElement element) {
    if (element.type == ReceiptElementType.line && element.value.isNotEmpty) {
      element.value = '';
    }
    _elements.add(element);
    notifyListeners();
  }

  void updateElementStyle(int index, {TextSize? size, TextAlign? align, TextFont? font}) {
    if (index < 0 || index >= _elements.length) return;
    final element = _elements[index];
    if (element.type == ReceiptElementType.text || element.type == ReceiptElementType.transaction) {
      element.textSize = size ?? element.textSize;
      element.textAlign = align ?? element.textAlign;
      element.textFont = font ?? element.textFont;
      notifyListeners();
    }
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