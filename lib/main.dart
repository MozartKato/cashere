import 'package:Cashere/providers/printer_provider.dart';
import 'package:Cashere/providers/receipt_builder_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/product_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/analytic_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/currency_provider.dart';

void main() {
  runApp(CashierApp());
}

class CashierApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => ReceiptBuilderProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'Cashere App',
            theme: ThemeData.light().copyWith(
              primaryColor: Colors.blue,
              colorScheme: ColorScheme.light(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: Colors.blueGrey,
              colorScheme: ColorScheme.dark(
                primary: Colors.blueGrey,
                secondary: Colors.tealAccent,
              ),
            ),
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            supportedLocales: [
              Locale('id', ''),
              Locale('en', ''),
            ],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            home: MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    ProductListScreen(),
    TransactionScreen(),
    AnalyticsScreen(),
    TransactionHistoryScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: localeProvider.locale.languageCode == 'id' ? 'Produk' : 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: localeProvider.locale.languageCode == 'id' ? 'Transaksi' : 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: localeProvider.locale.languageCode == 'id' ? 'Analitik' : 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: localeProvider.locale.languageCode == 'id' ? 'Riwayat' : 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: localeProvider.locale.languageCode == 'id' ? 'Pengaturan' : 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: themeProvider.isDarkMode ? Colors.white : Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}