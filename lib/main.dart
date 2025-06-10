import 'package:flutter/material.dart';
import 'Pages/Login_Page.dart';
import 'Pages/Setoran_Page.dart';
import 'Pages/SetoranFormPage.dart';
import 'Pages/InitialPage.dart';

void main() {
  runApp(const SetoranDosenApp());
}

class SetoranDosenApp extends StatelessWidget {
  const SetoranDosenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Setoran Hafalan Mahasiswa Teknik Informatika',
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => InitialPage());
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginPage());
          case '/setoran':
            return MaterialPageRoute(builder: (_) => SetoranPage());
          case '/form-setoran':
            final nim = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => SetoranFormPage(nim: nim),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('Halaman tidak ditemukan')),
              ),
            );
        }
      },
    );
  }
}
