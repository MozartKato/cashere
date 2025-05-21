import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/printer_provider.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  _PrinterScreenState createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final _thermalPrinter = FlutterThermalPrinter.instance;
  List<Printer> _devices = [];
  bool _isScanning = false;
  StreamSubscription<List<Printer>>? _devicesStreamSubscription;
  Timer? _scanTimeout;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.locationWhenInUse]!.isGranted;

    if (allGranted) {
      await _scanPrinters(); // Panggil tanpa expect return
    } else {
      _showSnackBar('Izin Bluetooth atau lokasi ditolak, goblok!');
    }
  }

  Future<void> _scanPrinters() async {
    if (!mounted) return;
    await Future.delayed(Duration.zero);
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _scanTimeout = Timer(const Duration(seconds: 10), () {
      if (_isScanning && mounted) {
        _stopScan();
        _showSnackBar('Scan timeout, coba lagi bro!');
      }
    });

    try {
      _devicesStreamSubscription?.cancel();
      await _thermalPrinter.getPrinters(
        refreshDuration: const Duration(seconds: 4),
        connectionTypes: [ConnectionType.BLE],
      );

      _devicesStreamSubscription = _thermalPrinter.devicesStream.listen(
            (devices) {
          if (!mounted) return;
          setState(() {
            _devices = devices.where((p) => p.name?.isNotEmpty ?? false).toList();
            _isScanning = false;
          });
          _scanTimeout?.cancel();
        },
        onError: (e) {
          if (mounted) {
            _stopScan();
            _showSnackBar('Error scan: $e');
          }
        },
        onDone: () {
          if (mounted) {
            _stopScan();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _stopScan();
        _showSnackBar('Gagal scan: $e');
      }
    }
  }

  void _stopScan() {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
    });
    _devicesStreamSubscription?.cancel();
    _thermalPrinter.stopScan();
    _scanTimeout?.cancel();
  }

  Future<void> _printTest(Printer printer) async {
    final provider = Provider.of<PrinterProvider>(context, listen: false);
    try {
      provider.setPrinter(printer); // Panggil tanpa await, karena void
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.text('Tes Print', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.cut();

      await provider.printData(bytes);
      _showSnackBar('Print berhasil, bro!');
    } catch (e) {
      _showSnackBar('Gagal print: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildPrinterTile(Printer printer, PrinterProvider printerProvider) {
    final isSelected = printerProvider.selectedPrinter?.address == printer.address;

    return ListTile(
      title: Text(printer.name ?? 'Unknown'),
      subtitle: Text('${printer.address ?? 'No address'} • ${printerProvider.isConnected && isSelected ? 'Connected' : 'Disconnected'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printTest(printer),
          ),
          IconButton(
            icon: Icon(
              printerProvider.isConnected && isSelected ? Icons.link_off : Icons.link,
              color: printerProvider.isConnected && isSelected ? Colors.red : Colors.blue,
            ),
            onPressed: () async {
              try {
                if (printerProvider.isConnected && isSelected) {
                  await printerProvider.disconnect();
                } else {
                   printerProvider.setPrinter(printer);
                  await printerProvider.connect();
                }
                if (mounted) setState(() {});
              } catch (e) {
                _showSnackBar('Gagal ubah koneksi: $e');
              }
            },
          ),
        ],
      ),
      selected: isSelected,
      onTap: () {
        printerProvider.setPrinter(printer);
        _showSnackBar('Printer dipilih: ${printer.name ?? 'Unknown'}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Printer'),
        centerTitle: true,
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(child: Text('Gak ada printer, coba scan dulu!'))
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final printer = _devices[index];
          return buildPrinterTile(printer, printerProvider);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanPrinters,
        child: const Icon(Icons.search),
      ),
    );
  }

  @override
  void dispose() {
    _devicesStreamSubscription?.cancel();
    _thermalPrinter.stopScan();
    _scanTimeout?.cancel();
    super.dispose();
  }
}