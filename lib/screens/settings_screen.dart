import 'package:Cashere/screens/receipt_builder_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/printer_provider.dart';
import 'printer_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);

    void _showLanguageDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Pilih Bahasa' : 'Select Language'),
            children: [
              SimpleDialogOption(
                onPressed: () {
                  localeProvider.setLocale('id');
                  Navigator.pop(context);
                },
                child: Text('Indonesia'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  localeProvider.setLocale('en');
                  Navigator.pop(context);
                },
                child: Text('English'),
              ),
            ],
          );
        },
      );
    }

    void _showCurrencyDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Pilih Mata Uang' : 'Select Currency'),
            children: [
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setCurrency('Rp');
                  Navigator.pop(context);
                },
                child: Text('Rupiah (Rp)'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setCurrency('\$');
                  Navigator.pop(context);
                },
                child: Text('Dollar (\$)'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setCurrency('€');
                  Navigator.pop(context);
                },
                child: Text('Euro (€)'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setCurrency('£');
                  Navigator.pop(context);
                },
                child: Text('Pound (£)'),
              ),
            ],
          );
        },
      );
    }

    void _showSeparatorDialog() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Pilih Pemisah Ribuan' : 'Select Thousands Separator'),
            children: [
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setThousandsSeparator('.');
                  Navigator.pop(context);
                },
                child: Text('. (1.000)'),
              ),
              SimpleDialogOption(
                onPressed: () {
                  currencyProvider.setThousandsSeparator(',');
                  Navigator.pop(context);
                },
                child: Text(', (1,000)'),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localeProvider.locale.languageCode == 'id' ? 'Pengaturan' : 'Settings'),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Pengaturan Tema
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Tema' : 'Theme'),
            subtitle: Text(themeProvider.isDarkMode
                ? (localeProvider.locale.languageCode == 'id' ? 'Gelap' : 'Dark')
                : (localeProvider.locale.languageCode == 'id' ? 'Terang' : 'Light')),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          // Pengaturan Bahasa
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Bahasa' : 'Language'),
            subtitle: Text(localeProvider.locale.languageCode == 'id' ? 'Indonesia' : 'English'),
            onTap: _showLanguageDialog,
          ),
          // Pengaturan Mata Uang
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Mata Uang' : 'Currency'),
            subtitle: Text(currencyProvider.currencySymbol),
            onTap: _showCurrencyDialog,
          ),
          // Pengaturan Pemisah Ribuan
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Pemisah Ribuan' : 'Thousands Separator'),
            subtitle: Text(currencyProvider.thousandsSeparator == '.' ? '.' : ','),
            onTap: _showSeparatorDialog,
          ),
          // Pengaturan Printer
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id' ? 'Printer' : 'Printer'),
            subtitle: Text(printerProvider.selectedPrinter?.name ??
                (localeProvider.locale.languageCode == 'id' ? 'Belum dipilih' : 'Not selected')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrinterScreen()),
              );
            },
          ),
          // Builder Struk
          ListTile(
            title: Text(localeProvider.locale.languageCode == 'id'
                ? 'Struktur Struk'
                : 'Receipt Structure'),
            subtitle: Text(localeProvider.locale.languageCode == 'id'
                ? 'Edit tampilan struk'
                : 'Customize receipt layout'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptBuilderScreen(),
                ),
              );
            },
          ),

        ],
      ),
    );
  }
}