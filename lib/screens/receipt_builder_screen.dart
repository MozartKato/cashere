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

    Future<void> _testPrint() async {
      if (printerProvider.selectedPrinter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih printer dulu, goblok!')),
        );
        return;
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
                  bold: el.textFont == TextFont.bold || el.textSize == TextSize.large, // Bold otomatis buat large
                  height: _mapTextSize(el.textSize),
                  width: _mapTextSize(el.textSize),
                  align: _mapTextAlign(el.textAlign),
                ),
              );
              break;
            case ReceiptElementType.qr:
              bytes += generator.qrcode(el.value);
              break;
            case ReceiptElementType.barcode:
              if (el.value.length == 12 && int.tryParse(el.value) == null) {
                throw 'Barcode UPC-A harus 12 digit angka, anjir!';
              }
              bytes += generator.barcode(Barcode.upcA(el.value.split('').map(int.parse).toList()));
              break;
            case ReceiptElementType.line:
              bytes += generator.hr();
              break;
            case ReceiptElementType.image:
              final file = el.value as File;
              if (!file.existsSync()) throw 'Gambar gak ada, bro!';
              final image = img.decodeImage(await file.readAsBytes());
              if (image == null) throw 'Gagal decode gambar, anjir!';
              // Resize ke lebar 384px (kertas 58mm, 8px/mm)
              final resized = img.copyResize(image, width: 384);
              // Convert ke monochrome
              final mono = img.grayscale(resized);
              final pixels = mono.getBytes();
              final bitmap = img.Image.fromBytes(width: mono.width, height: mono.height, bytes: pixels.buffer);
              bytes += generator.image(bitmap);
              break;
            default:
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
        await printerProvider.printData(bytes);
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

      final controller = TextEditingController();
      ReceiptTextAlign align = ReceiptTextAlign.center;
      TextFont font = TextFont.normal;
      TextSize size = TextSize.medium;
      showDialog(
        context: ctx,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Masukkan ${type.name.toUpperCase()}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  CheckboxListTile(
                    title: const Text('Bold'),
                    value: font == TextFont.bold,
                    onChanged: (value) => setState(() => font = value! ? TextFont.bold : TextFont.normal),
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
                        value: controller.text,
                        textAlign: type == ReceiptElementType.text ? align : ReceiptTextAlign.center,
                        textFont: type == ReceiptElementType.text ? font : TextFont.normal,
                        textSize: type == ReceiptElementType.text ? size : TextSize.medium,
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
      if (element.type != ReceiptElementType.text) return;
      ReceiptTextAlign align = element.textAlign ?? ReceiptTextAlign.center;
      TextFont font = element.textFont ?? TextFont.normal;
      TextSize size = element.textSize ?? TextSize.medium;
      showDialog(
        context: ctx,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Style Teks'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                CheckboxListTile(
                  title: const Text('Bold'),
                  value: font == TextFont.bold,
                  onChanged: (value) => setState(() => font = value! ? TextFont.bold : TextFont.normal),
                ),
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
                    align: align,
                    font: font,
                    size: size,
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
                builderProvider.addElement(
                  ReceiptElement(type: ReceiptElementType.line, value: ''),
                );
                Navigator.pop(context);
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
                : Text(
              '${el.type.name.toUpperCase()}: ${el.value.isEmpty ? '---' : el.value}',
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
                if (el.type == ReceiptElementType.text)
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
        return PosTextSize.size1; // 1x width, 1x height
      case TextSize.medium:
        return PosTextSize.size2; // 2x width, 2x height
      case TextSize.large:
        return PosTextSize.size2; // 2x width, 2x height (pake bold buat bedain)
      default:
        return PosTextSize.size2;
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
        return 12.0;
      case TextSize.large:
        return 18.0;
      case TextSize.medium:
      default:
        return 14.0;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}