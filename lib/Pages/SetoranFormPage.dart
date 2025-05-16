import 'dart:convert'; // untuk jsonEncode
import 'package:shared_preferences/shared_preferences.dart'; // untuk SharedPreferences
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:setorantif_dosen1/Services/Auth_service.dart';

class SetoranFormPage extends StatefulWidget {
  const SetoranFormPage({super.key});

  @override
  State<SetoranFormPage> createState() => _SetoranFormPageState();
}

class _SetoranFormPageState extends State<SetoranFormPage> {
  late String nim;

  final _formKey = GlobalKey<FormState>();
  final _tanggalController = TextEditingController();
  bool _isSubmitting = false;

  // Contoh daftar surah
  final List<Map<String, String>> _daftarSurah = [
    {"id": "9fc4e7c0-f23c-43a9-8b2a-5f4e9e94d9d1", "nama": "An-Naba'"},
    {"id": "cbe746c8-3ffb-4d44-b4ab-fc4e4c6d95ea", "nama": "An-Nazi'at"},
    {"id": "1955f5c1-4c70-4f0e-95b7-6bd50269f6f6", "nama": "Abasa"},
  ];

  String? _selectedSurahId;
  String? _selectedSurahNama;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    nim = ModalRoute.of(context)?.settings.arguments as String;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final authService = AuthService();

      final Map<String, dynamic> dataSetoran = {
        "data_setoran": [
          {
            "nama_komponen_setoran": _selectedSurahNama,
            "id_komponen_setoran": _selectedSurahId,
          }
        ]
      };

      // Tambahkan tgl_setoran jika ada, atau default ke hari ini
      final tglSetoran = _tanggalController.text.trim().isNotEmpty
          ? _tanggalController.text.trim()
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      dataSetoran["tgl_setoran"] = tglSetoran;

      debugPrint('Payload: $dataSetoran');

      final success = await authService.postSetoranMahasiswa(
        nim: nim,
        dataSetoran: dataSetoran,
      );

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Setoran berhasil dikirim' : 'Gagal mengirim setoran'),
        ),
      );

      if (success) {
        // Simpan ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final existing = prefs.getStringList('setoran_list') ?? [];

        final newSetoran = jsonEncode({
          'tgl_setoran': tglSetoran,
          'nama_komponen_setoran': _selectedSurahNama,
          'id_komponen_setoran': _selectedSurahId,
        });

        existing.add(newSetoran);
        await prefs.setStringList('setoran_list', existing);

        Navigator.pop(context, true); // Kembali dan beri sinyal untuk refresh
      }
    }
  }


  @override
  void dispose() {
    _tanggalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Setoran Mahasiswa'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'NIM: $nim',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Dropdown Surah
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Pilih Surah'),
                items: _daftarSurah.map((surah) {
                  return DropdownMenuItem<String>(
                    value: surah['id'],
                    child: Text(surah['nama']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSurahId = value;
                    _selectedSurahNama = _daftarSurah
                        .firstWhere((s) => s['id'] == value)['nama'];
                  });
                },
                validator: (value) =>
                value == null ? 'Pilih surah terlebih dahulu' : null,
              ),

              const SizedBox(height: 12),

              // Tanggal setoran
              TextFormField(
                controller: _tanggalController,
                decoration: const InputDecoration(labelText: 'Tanggal Setoran'),
                readOnly: true,
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _tanggalController.text =
                        DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),

              const SizedBox(height: 24),

              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Kirim Setoran'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
