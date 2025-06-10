import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SetoranFormPage.dart';

class SetoranDetailPage extends StatefulWidget {
  final String nim;
  const SetoranDetailPage({required this.nim, super.key});

  @override
  State<SetoranDetailPage> createState() => _SetoranDetailPageState();
}

class _SetoranDetailPageState extends State<SetoranDetailPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _detailSetoran;

  final String apiBaseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  @override
  void initState() {
    super.initState();
    _fetchSetoranByNIM(widget.nim);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchSetoranByNIM(String nim) async {
    setState(() {
      _isLoading = true;
      _detailSetoran = null;
    });

    final token = await _getToken();
    if (token == null) {
      debugPrint('[ERROR] Token null saat fetch setoran');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse('$apiBaseUrl/mahasiswa/setoran/$nim');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('[INFO] Setoran data: $result');

        final detail = result['data'];
        if (detail != null) {
          setState(() {
            _detailSetoran = detail;
          });
        } else {
          debugPrint('[WARNING] Data setoran kosong atau null');
        }
      } else {
        debugPrint('[ERROR] Gagal load setoran: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ERROR] fetchSetoranByNIM: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSetoranById(String setoranId, String idKomponen, String namaKomponen) async {
    final token = await _getToken();
    if (token == null) {
      debugPrint('[ERROR] Token null saat delete setoran');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin menghapus setoran ini?'),
        actions: [
          TextButton(
            child: const Text('Batal'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Hapus'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final url = Uri.parse('$apiBaseUrl/mahasiswa/setoran/${widget.nim}');

      // Buat request manual agar bisa menyisipkan body pada DELETE
      final request = http.Request("DELETE", url)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          "data_setoran": [
            {
              "id": setoranId,
              "id_komponen_setoran": idKomponen,
              "nama_komponen_setoran": namaKomponen,
            }
          ]
        });

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setoran berhasil dihapus')),
        );
        _fetchSetoranByNIM(widget.nim);
      } else {
        debugPrint('[ERROR] Gagal hapus setoran: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus setoran')),
        );
      }
    } catch (e) {
      debugPrint('[ERROR] deleteSetoranById: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat menghapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _detailSetoran?['info'] ?? {};

    // Gunakan list data_setoran dari response
    final List<dynamic> daftarSetoranSurah = (_detailSetoran?['setoran']?['detail'] as List<dynamic>?)
        ?.where((item) => item['sudah_setor'] == true)
        .toList() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF213448),
      appBar: AppBar(
        title: Text('Detail Setoran - NIM: ${widget.nim}'),
        backgroundColor: const Color(0xFF213448),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detailSetoran == null
          ? const Center(child: Text('Tidak ada data setoran.'))
          : Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.blue[800],
                  child: Text(
                    info['nama'] != null && info['nama'].isNotEmpty
                        ? info['nama'][0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  info['nama'] ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'NIM: ${info['nim'] ?? '-'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Angkatan: ${info['angkatan'] ?? '-'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Center(
                child: Text(
                  'Semester: ${info['semester'] ?? '-'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),

              const SizedBox(height: 20),
                  const Text(
                'Daftar Setoran Surah:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (daftarSetoranSurah.isEmpty)
                const Text('Belum ada setoran surah yang disetor.'),
              if (daftarSetoranSurah.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: daftarSetoranSurah.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final surah = daftarSetoranSurah[index];
                    final infoSetoran = surah['info_setoran'] ?? {};
                    final dosen = infoSetoran['dosen_yang_mengesahkan'] ?? {};
                    final idSetoran = infoSetoran['id'] ?? '';

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(
                          surah['nama'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                'Setoran: ${infoSetoran['tgl_setoran'] ?? '-'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.teal.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                'Dosen: ${dosen['nama'] ?? 'Belum disahkan'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.teal.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              visualDensity: VisualDensity.compact,
                            ),

                          ],
                        ),

                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Hapus Setoran',
                          onPressed: idSetoran.isEmpty
                              ? null
                              : () {
                            final idKomponen = surah['id_komponen_setoran'] ?? '';
                            final namaKomponen = surah['nama_komponen_setoran'] ?? '';
                            _deleteSetoranById(idSetoran, idKomponen, namaKomponen);
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SetoranFormPage(nim: widget.nim),
            ),
          ).then((_) {
            _fetchSetoranByNIM(widget.nim);
          });
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.green[700],
        tooltip: 'Tambah Setoran',
      ),
    );

  }
}
