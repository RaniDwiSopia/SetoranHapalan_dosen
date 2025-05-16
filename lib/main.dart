import 'package:flutter/material.dart';
import 'Pages/Login_Page.dart';
import 'Pages/Setoran_Page.dart'; // import halaman SetoranPage
import 'package:setorantif_dosen1/Pages/SetoranFormPage.dart';


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
      routes: {
        '/': (context) => LoginPage(),
        '/setoran': (context) => SetoranPage(), // menambahkan route ke SetoranPage
        '/form-setoran': (context) => SetoranFormPage(),
      },
    );
  }
}
