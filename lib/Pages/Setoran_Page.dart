import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SetoranFormPage.dart';

class SetoranPage extends StatefulWidget {
  const SetoranPage({Key? key}) : super(key: key);

  @override
  State<SetoranPage> createState() => _SetoranPageState();
}

class _SetoranPageState extends State<SetoranPage> {
  final TextEditingController _nimController = TextEditingController();
  Map<String, dynamic>? _info;
  List<dynamic> _setoranSurah = [];
  List<Map<String, dynamic>> _setoranList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedNIMAndFetch();
    _loadSetoranListFromPrefs();
  }

  Future<void> _loadSavedNIMAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNIM = prefs.getString('nim');
    if (savedNIM != null) {
      _nimController.text = savedNIM;
      fetchSetoranByNIM(savedNIM);
    }
  }

  Future<void> _loadSetoranListFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('setoran_list');
    if (jsonString != null) {
      final List decoded = json.decode(jsonString);
      setState(() {
        _setoranList = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> fetchSetoranByNIM(String nim) async {
    setState(() {
      _isLoading = true;
      _info = null;
      _setoranSurah = [];
    });

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token akses tidak ditemukan')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final url = Uri.parse(
      'https://api.tif.uin-suska.ac.id/setoran-dev/v1/mahasiswa/setoran/$nim',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final info = data['data']['info'];
        final surah = data['data']['setoran']['surah'];

        setState(() {
          _info = info;
          _setoranSurah = surah ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInfoMahasiswa() {
    if (_info == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Mahasiswa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Angkatan: ${_info!['angkatan'] ?? '-'}'),
            Text('Semester: ${_info!['semester'] ?? '-'}'),
            Text('Dosen PA: ${_info!['dosen_pa']?['nama'] ?? 'Tidak ada'}'),
            Text('Email: ${_info!['email'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmitSetoran() async {
    final nim = _nimController.text.trim();
    if (nim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan isi NIM terlebih dahulu')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SetoranFormPage(),
        settings: RouteSettings(arguments: nim),
      ),
    );

    if (result == true) {
      await Future.delayed(const Duration(seconds: 1));
      fetchSetoranByNIM(nim);
      _loadSetoranListFromPrefs(); // muat ulang dari prefs
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setoran Saya'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nimController,
              decoration: InputDecoration(
                labelText: 'Masukkan NIM',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    final nim = _nimController.text.trim();
                    if (nim.isNotEmpty) {
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString('nim', nim);
                      });
                      fetchSetoranByNIM(nim);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_info != null)
              GestureDetector(
                onTap: _showInfoMahasiswa,
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _info!['nama'] ?? 'Nama Mahasiswa',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('NIM: ${_info!['nim'] ?? '-'}'),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_setoranSurah.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _setoranSurah.length,
                  itemBuilder: (_, index) {
                    final surah = _setoranSurah[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: Icon(
                          surah['sudah_setor'] ? Icons.check_circle : Icons.pending,
                          color: surah['sudah_setor'] ? Colors.green : Colors.orange,
                        ),
                        title: Text('${surah['nama']} (${surah['nama_arab']})'),
                        subtitle: Text('Label: ${surah['label']}'),
                      ),
                    );
                  },
                ),
              )
            else
              const Text('Belum ada data setoran untuk Juz 30.'),

            // Tambahan untuk menampilkan setoran yang baru disimpan
            if (_setoranList.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Setoran yang Baru Disimpan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._setoranList.map((item) => Card(
                child: ListTile(
                  title: Text(item['nama_komponen_setoran'] ?? '-'),
                  subtitle: Text('ID: ${item['id_komponen_setoran'] ?? '-'}'),
                ),
              )),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSubmitSetoran,
        backgroundColor: Colors.blue[100],
        child: const Icon(Icons.add),
      ),
    );
  }
}
