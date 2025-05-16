import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_builder_provider.dart';
import '../providers/printer_provider.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';

class ReceiptBuilderScreen extends StatelessWidget {
  const ReceiptBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final builderProvider = Provider.of<ReceiptBuilderProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);
    final printer = printerProvider.selectedPrinter;

    void _testPrint() async {
      if (printer == null) {
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
              bytes += generator.text(el.value, styles: const PosStyles(bold: true, height: PosTextSize.size3, width: PosTextSize.size3, align: PosAlign.right));
              break;
            case ReceiptElementType.qr:
              bytes += generator.qrcode(el.value);
              break;
            case ReceiptElementType.barcode:
            // Validasi dan parse string ke format barcode (contoh UPC-A butuh 12 digit)
              if (el.value.length == 12 && int.tryParse(el.value) != null) {
                bytes += generator.barcode(Barcode.upcA(el.value.split('').map(int.parse).toList()));
              } else {
                throw 'Barcode UPC-A harus 12 digit angka, anjir!';
              }
              break;
            case ReceiptElementType.line:
              bytes += generator.hr();
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
      final printerInstance = FlutterThermalPrinter.instance;

      try {
        if (!(printer.isConnected ?? false)) {
          await printerInstance.connect(printer).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw 'Koneksi printer timeout!',
          );
        }
        await printerInstance.printData(printer, bytes);
        await printerInstance.disconnect(printer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print sukses, bro! 🎉')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal print: $e')),
        );
      }
    }

    void _showInputDialog(BuildContext ctx, ReceiptElementType type) {
      final controller = TextEditingController();
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: Text('Masukkan ${type.name.toUpperCase()}'),
          content: TextField(
            controller: controller,
            keyboardType: type == ReceiptElementType.barcode ? TextInputType.number : TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Isi dulu')),
                  );
                  return;
                }
                builderProvider.addElement(
                  ReceiptElement(type: type, value: controller.text),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Tambah'),
            ),
          ],
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
            title: Text('${el.type.name.toUpperCase()}: ${el.value.isEmpty ? '---' : el.value}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => builderProvider.removeElement(index),
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
}