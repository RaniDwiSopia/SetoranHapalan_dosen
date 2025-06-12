import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:setorantif_dosen1/Services/Auth_service.dart';


class SetoranFormPage extends StatefulWidget {
  final String nim;
  const SetoranFormPage({super.key, required this.nim});

  @override
  State<SetoranFormPage> createState() => _SetoranFormPageState();
}

class _SetoranFormPageState extends State<SetoranFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _tanggalController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingSurah = true;

  List<Map<String, String>> _daftarSurah = [];

  String? _selectedSurahId;
  String? _selectedSurahNama;

  @override
  void initState() {
    super.initState();
    _loadDaftarSurah();
  }

  Future<void> _loadDaftarSurah() async {
    setState(() => _isLoadingSurah = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final nim = widget.nim;
      final token = prefs.getString('access_token');

      if (nim.isEmpty || token == null) {
        throw Exception('NIM atau token tidak tersedia');
      }

      final response = await http.get(
        Uri.parse('https://api.tif.uin-suska.ac.id/setoran-dev/v1/mahasiswa/setoran/$nim'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List detailSurah = data['data']['setoran']['detail'] ?? [];

        setState(() {
          _daftarSurah = detailSurah
              .where((surah) => surah['sudah_setor'] == false)
              .map<Map<String, String>>((surah) {
            return {
              'id': surah['id'].toString(),
              'nama': surah['nama'].toString(),
            };
          }).toList();
          _isLoadingSurah = false;
        });
      } else {
        throw Exception('Gagal ambil data surah: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error load daftar surah: $e');
      setState(() => _isLoadingSurah = false);
      // Jika error, bisa juga isi _daftarSurah dengan list kosong agar dropdown tetap jalan
      setState(() => _daftarSurah = []);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSurahId == null || _selectedSurahNama == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surah harus dipilih')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authService = AuthService();
    final tglSetoran = _tanggalController.text.trim().isNotEmpty
        ? _tanggalController.text.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final Map<String, dynamic> dataSetoran = {
      "tgl_setoran": tglSetoran,
      "data_setoran": [
        {
          "nama_komponen_setoran": _selectedSurahNama,
          "id_komponen_setoran": _selectedSurahId,
        }
      ]
    };

    bool success = false;
    try {
      success = await authService.postSetoranMahasiswa(
        nim: widget.nim,
        dataSetoran: dataSetoran,
      );
    } catch (e) {
      debugPrint('Error saat kirim setoran: $e');
    }

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Setoran berhasil dikirim'
            : 'Gagal mengirim setoran. Cek koneksi atau data.'),
      ),
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('setoran_list') ?? [];

      final newSetoran = jsonEncode({
        'tgl_setoran': tglSetoran,
        'nama_komponen_setoran': _selectedSurahNama,
        'id_komponen_setoran': _selectedSurahId,
      });

      existing.add(newSetoran);
      await prefs.setStringList('setoran_list', existing);

      _formKey.currentState?.reset();
      _tanggalController.clear();
      setState(() {
        _selectedSurahId = null;
        _selectedSurahNama = null;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        Navigator.pop(context, true);
      });
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
      backgroundColor: const Color(0xFF131D4F),
      appBar: AppBar(
        title: const Text('Input Setoran Mahasiswa'),
        backgroundColor: const Color(0xFF131D4F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: const Color(0xFFF5F5F5), // Warna card
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'NIM: ${widget.nim}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLoadingSurah
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Pilih Surah'),
                    value: _selectedSurahId,
                    items: _daftarSurah.map((surah) {
                      return DropdownMenuItem<String>(
                        value: surah['id'],
                        child: Text(surah['nama']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSurahId = value;
                        _selectedSurahNama = _daftarSurah.firstWhere((s) => s['id'] == value)['nama'];
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Pilih surah terlebih dahulu' : null,
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _tanggalController,
                    decoration: const InputDecoration(labelText: 'Tanggal Setoran'),
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      try {
                        DateFormat('yyyy-MM-dd').parseStrict(value);
                      } catch (_) {
                        return 'Format tanggal tidak valid';
                      }
                      return null;
                    },
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
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
        ),
      ),

    );
  }
}