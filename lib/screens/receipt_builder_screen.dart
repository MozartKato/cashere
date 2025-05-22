import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_builder_provider.dart';
import '../providers/printer_provider.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class ReceiptBuilderScreen extends StatelessWidget {
  const ReceiptBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final builderProvider = Provider.of<ReceiptBuilderProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);

    // Dummy data buat contoh transaksi
    final dummyTransaction = {
      'transactionId': 'TRX12345',
      'transactionDate': '2025-05-21 14:00:00',
      'totalPrice': 26000.0,
      'paymentMethod': 'Cash',
      'items': [
        {'productName': 'Ayam Goreng', 'quantity': 1, 'unitPrice': 12000.0, 'totalPrice': 12000.0},
        {'productName': 'Ayam Bakar', 'quantity': 1, 'unitPrice': 14000.0, 'totalPrice': 14000.0},
      ],
    };

    Future<void> _testPrint() async {
      if (printerProvider.selectedPrinter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih printer dulu, goblok!')),
        );
        return;
      }

      // Cek koneksi biar gak reconnect berulang
      if (printerProvider.isConnected) {
        print('Already connected, skipping reconnect');
      } else {
        try {
          await printerProvider.connect().timeout(const Duration(seconds: 5));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal connect printer: $e')),
          );
          return;
        }
      }

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      for (var el in builderProvider.elements) {
        try {
          switch (el.type) {
            case ReceiptElementType.text:
              bytes += generator.text(
                el.value,
                styles: PosStyles(
                  bold: el.textFont == TextFont.bold,
                  height: _mapTextSize(el.textSize),
                  width: _mapTextSize(el.textSize),
                  align: _mapTextAlign(el.textAlign),
                  codeTable: 'CP437', // Font kecil
                ),
              );
              break;
            case ReceiptElementType.qr:
              bytes += generator.qrcode(el.value);
              break;
            case ReceiptElementType.barcode:
              if (el.value.length != 12 || int.tryParse(el.value) == null) {
                throw 'Barcode UPC-A harus 12 digit angka, anjir!';
              }
              bytes += generator.barcode(Barcode.upcA(el.value.split('').map(int.parse).toList()));
              break;
            case ReceiptElementType.line:
              final style = el.lineStyle ?? LineStyle.solid;
              switch (style) {
                case LineStyle.solid:
                  bytes += generator.hr();
                  break;
                case LineStyle.dashed:
                  bytes += generator.text('- ' * 16, styles: const PosStyles(align: PosAlign.center));
                  break;
                case LineStyle.double:
                  bytes += generator.text('=' * 32, styles: const PosStyles(align: PosAlign.center, bold: true));
                  break;
                case LineStyle.patterned:
                  bytes += generator.text('-*-' * 8, styles: const PosStyles(align: PosAlign.center));
                  break;
                case LineStyle.short:
                  bytes += generator.text('-' * 20, styles: const PosStyles(align: PosAlign.center));
                  break;
                case LineStyle.decorative:
                  bytes += generator.text('~' * 32, styles: const PosStyles(align: PosAlign.center));
                  break;
              }
              break;
            case ReceiptElementType.image:
              final file = el.value as File;
              if (!file.existsSync()) throw 'Gambar gak ada, bro!';
              final image = img.decodeImage(await file.readAsBytes());
              if (image == null) throw 'Gagal decode gambar, anjir!';
              final resized = img.copyResize(image, width: 384);
              final mono = img.grayscale(resized);
              final pixels = mono.getBytes();
              final bitmap = img.Image.fromBytes(width: mono.width, height: mono.height, bytes: pixels.buffer);
              bytes += generator.image(bitmap);
              break;
            case ReceiptElementType.transaction:
              final trans = el.value as Map<String, dynamic>;
              for (var item in trans['items']) {
                // Format tabel: nama (18 char), qty (4 char), harga (10 char)
                final name = item['productName'].toString().padRight(18).substring(0, 18);
                final qty = item['quantity'].toString().padLeft(4);
                final price = item['unitPrice'].toStringAsFixed(0).padLeft(10);
                bytes += generator.text(
                  '$name$qty$price',
                  styles: PosStyles(
                    bold: false, // Non-bold biar kecil
                    height: _mapTextSize(TextSize.small),
                    width: _mapTextSize(TextSize.small),
                    align: _mapTextAlign(el.textAlign),
                    codeTable: 'CP437', // Font kecil
                  ),
                );
              }
              bytes += generator.text(
                'Total: ${trans['totalPrice'].toStringAsFixed(0)}'.padLeft(32),
                styles: PosStyles(
                  bold: true,
                  height: _mapTextSize(TextSize.small),
                  width: _mapTextSize(TextSize.small),
                  align: PosAlign.right,
                  codeTable: 'CP437',
                ),
              );
              break;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error elemen ${el.type.name}: $e')),
          );
          return;
        }
      }

      bytes += generator.cut();

      try {
        await printerProvider.printData(bytes).timeout(const Duration(seconds: 10));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print sukses, bro! 🎉')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal print: $e')),
        );
      }
    }

    Future<void> _showInputDialog(BuildContext ctx, ReceiptElementType type) async {
      if (type == ReceiptElementType.image) {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gambar gak dipilih, bro!')),
          );
          return;
        }
        final file = File(pickedFile.path);
        try {
          builderProvider.addElement(
            ReceiptElement(type: ReceiptElementType.image, value: file),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal tambah gambar: $e')),
          );
        }
        return;
      }

      if (type == ReceiptElementType.transaction) {
        try {
          builderProvider.addElement(
            ReceiptElement(
              type: ReceiptElementType.transaction,
              value: dummyTransaction,
              textAlign: ReceiptTextAlign.left,
              textFont: TextFont.normal,
              textSize: TextSize.small, // Default kecil
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal tambah transaksi: $e')),
          );
        }
        return;
      }

      final controller = TextEditingController();
      ReceiptTextAlign align = ReceiptTextAlign.center;
      TextFont font = TextFont.normal;
      TextSize size = TextSize.small; // Default kecil
      LineStyle lineStyle = LineStyle.solid;

      showDialog(
        context: ctx,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Masukkan ${type.name.toUpperCase()}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == ReceiptElementType.line)
                  DropdownButton<LineStyle>(
                    value: lineStyle,
                    items: LineStyle.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => lineStyle = value!),
                  ),
                if (type != ReceiptElementType.line)
                  TextField(
                    controller: controller,
                    keyboardType: type == ReceiptElementType.barcode ? TextInputType.number : TextInputType.text,
                    decoration: InputDecoration(labelText: 'Isi ${type.name}'),
                  ),
                if (type == ReceiptElementType.text) ...[
                  DropdownButton<ReceiptTextAlign>(
                    value: align,
                    items: ReceiptTextAlign.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => align = value!),
                  ),
                  DropdownButton<TextSize>(
                    value: size,
                    items: TextSize.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => size = value!),
                  ),
                  DropdownButton<TextFont>(
                    value: font,
                    items: TextFont.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => font = value!),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.isEmpty && type != ReceiptElementType.line) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Isi dulu, bro!')),
                    );
                    return;
                  }
                  try {
                    builderProvider.addElement(
                      ReceiptElement(
                        type: type,
                        value: type == ReceiptElementType.line ? '' : controller.text,
                        textAlign: type == ReceiptElementType.text ? align : null,
                        textFont: type == ReceiptElementType.text ? font : null,
                        textSize: type == ReceiptElementType.text ? size : null,
                        lineStyle: type == ReceiptElementType.line ? lineStyle : null,
                      ),
                    );
                    Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal tambah: $e')),
                    );
                  }
                },
                child: const Text('Tambah'),
              ),
            ],
          ),
        ),
      );
    }

    void _showEditStyleDialog(BuildContext ctx, int index) {
      final element = builderProvider.elements[index];
      if (element.type != ReceiptElementType.text && element.type != ReceiptElementType.transaction && element.type != ReceiptElementType.line) return;
      ReceiptTextAlign align = element.textAlign ?? ReceiptTextAlign.center;
      TextFont font = element.textFont ?? TextFont.normal;
      TextSize size = element.textSize ?? TextSize.small;
      LineStyle lineStyle = element.lineStyle ?? LineStyle.solid;

      showDialog(
        context: ctx,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Edit Style ${element.type.name.capitalize()}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (element.type == ReceiptElementType.line)
                  DropdownButton<LineStyle>(
                    value: lineStyle,
                    items: LineStyle.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => lineStyle = value!),
                  ),
                if (element.type == ReceiptElementType.text || element.type != ReceiptElementType.transaction) ...[
                  DropdownButton<ReceiptTextAlign>(
                    value: align,
                    items: ReceiptTextAlign.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => align = value!),
                  ),
                  DropdownButton<TextSize>(
                    value: size,
                    items: TextSize.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => size = value!),
                  ),
                  DropdownButton<TextFont>(
                    value: font,
                    items: TextFont.values
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name.capitalize())))
                        .toList(),
                    onChanged: (value) => setState(() => font = value!),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  builderProvider.updateElementStyle(
                    index,
                    align: element.type != ReceiptElementType.line ? align : null,
                    font: element.type != ReceiptElementType.line ? font : null,
                    size: element.type != ReceiptElementType.line ? size : null,
                    lineStyle: element.type == ReceiptElementType.line ? lineStyle : null,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      );
    }

    void _addElementDialog() {
      showModalBottomSheet(
        context: context,
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Teks'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.text);
              },
            ),
            ListTile(
              title: const Text('Gambar'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.image);
              },
            ),
            ListTile(
              title: const Text('QR Code'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.qr);
              },
            ),
            ListTile(
              title: const Text('Barcode'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.barcode);
              },
            ),
            ListTile(
              title: const Text('Garis Pemisah'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.line);
              },
            ),
            ListTile(
              title: const Text('Transaksi'),
              onTap: () {
                Navigator.pop(context);
                _showInputDialog(context, ReceiptElementType.transaction);
              },
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struktur Struk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _testPrint,
          ),
        ],
      ),
      body: builderProvider.elements.isEmpty
          ? const Center(child: Text('Struk kosong, tambah elemen dulu!'))
          : ReorderableListView.builder(
        itemCount: builderProvider.elements.length,
        onReorder: builderProvider.moveElement,
        itemBuilder: (context, index) {
          final el = builderProvider.elements[index];
          return ListTile(
            key: ValueKey(index),
            title: el.type == ReceiptElementType.image
                ? Image.file(
              el.value as File,
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text('Gagal load gambar'),
            )
                : el.type == ReceiptElementType.transaction
                ? Container(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var item in (el.value as Map<String, dynamic>)['items'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              item['productName'],
                              style: TextStyle(
                                fontWeight: el.textFont == TextFont.bold ? FontWeight.bold : FontWeight.normal,
                                fontSize: _mapTextSizeToFontSize(el.textSize),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${item['quantity']}x',
                              style: TextStyle(
                                fontWeight: el.textFont == TextFont.bold ? FontWeight.bold : FontWeight.normal,
                                fontSize: _mapTextSizeToFontSize(el.textSize),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item['unitPrice'].toStringAsFixed(0),
                              style: TextStyle(
                                fontWeight: el.textFont == TextFont.bold ? FontWeight.bold : FontWeight.normal,
                                fontSize: _mapTextSizeToFontSize(el.textSize),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 140),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Text(
                            'Total: ${(el.value as Map<String, dynamic>)['totalPrice'].toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: _mapTextSizeToFontSize(el.textSize),
                              color: Theme.of(context).primaryColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                : Text(
              '${el.type.name.toUpperCase()}: ${el.value.isEmpty ? (el.lineStyle?.name.toUpperCase() ?? '---') : el.value}',
              style: TextStyle(
                fontWeight: el.textFont == TextFont.bold || el.textSize == TextSize.large
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: _mapTextSizeToFontSize(el.textSize),
              ),
              textAlign: _mapReceiptTextAlignToFlutter(el.textAlign),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (el.type == ReceiptElementType.text || el.type == ReceiptElementType.transaction || el.type == ReceiptElementType.line)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditStyleDialog(context, index),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => builderProvider.removeElement(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addElementDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  PosTextSize _mapTextSize(TextSize? size) {
    switch (size) {
      case TextSize.small:
        return PosTextSize.size1; // Kecil beneran
      case TextSize.medium:
        return PosTextSize.size1; // Medium juga kecil biar konsisten
      case TextSize.large:
        return PosTextSize.size2; // Hanya large yang gede
      default:
        return PosTextSize.size1;
    }
  }

  PosAlign _mapTextAlign(ReceiptTextAlign? align) {
    switch (align) {
      case ReceiptTextAlign.left:
        return PosAlign.left;
      case ReceiptTextAlign.right:
        return PosAlign.right;
      case ReceiptTextAlign.center:
      default:
        return PosAlign.center;
    }
  }

  TextAlign _mapReceiptTextAlignToFlutter(ReceiptTextAlign? align) {
    switch (align) {
      case ReceiptTextAlign.left:
        return TextAlign.left;
      case ReceiptTextAlign.right:
        return TextAlign.right;
      case ReceiptTextAlign.center:
      default:
        return TextAlign.center;
    }
  }

  double _mapTextSizeToFontSize(TextSize? size) {
    switch (size) {
      case TextSize.small:
        return 10.0; // Kecil di UI
      case TextSize.medium:
        return 12.0;
      case TextSize.large:
        return 14.0;
      default:
        return 10.0;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}