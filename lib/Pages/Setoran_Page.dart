import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'setoran_detail_page.dart';

class SetoranPage extends StatefulWidget {
  const SetoranPage({super.key});

  @override
  State<SetoranPage> createState() => _SetoranPageState();
}

class _SetoranPageState extends State<SetoranPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _mahasiswaPA = [];
  List<dynamic> _filteredMahasiswaPA = [];
  bool _isLoadingMahasiswa = false;

  final String apiBaseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  @override
  void initState() {
    super.initState();
    _fetchMahasiswaPA();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchMahasiswaPA() async {
    setState(() {
      _isLoadingMahasiswa = true;
    });

    final token = await _getToken();
    if (token == null) {
      debugPrint('[ERROR] Token null');
      setState(() => _isLoadingMahasiswa = false);
      return;
    }

    try {
      final url = Uri.parse('$apiBaseUrl/dosen/pa-saya');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        debugPrint('[INFO] Respon mahasiswa PA: $result');

        final mahasiswaList = result['data']?['info_mahasiswa_pa']?['daftar_mahasiswa'];
        if (mahasiswaList != null && mahasiswaList is List) {
          setState(() {
            _mahasiswaPA = mahasiswaList;
            _filteredMahasiswaPA = _mahasiswaPA;
          });
        } else {
          debugPrint('[WARNING] daftar_mahasiswa tidak ditemukan atau bukan List');
        }
      } else {
        debugPrint('[ERROR] Gagal load mahasiswa PA: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ERROR] fetchMahasiswaPA: $e');
    } finally {
      setState(() => _isLoadingMahasiswa = false);
    }
  }

  void _filterMahasiswa(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _filteredMahasiswaPA = _mahasiswaPA;
      });
      return;
    }

    setState(() {
      _filteredMahasiswaPA = _mahasiswaPA.where((mhs) {
        final nama = (mhs['nama'] ?? '').toString().toLowerCase();
        final nim = (mhs['nim'] ?? '').toString();
        return nama.contains(keyword.toLowerCase()) || nim.contains(keyword);
      }).toList();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF547792),  // Warna background halaman (#547792)
      appBar: AppBar(
        title: const Text('Daftar Mahasiswa PA'),
        backgroundColor: const Color(0xFF547792),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Yakin ingin logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
                  ],
                ),
              );

              if (confirm == true) {
                await _logout();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Nama/NIM Mahasiswa',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 2.0),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _filterMahasiswa(_searchController.text.trim()),
                  color: Colors.white,
                ),
                labelStyle: const TextStyle(color: Colors.white),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (value) => _filterMahasiswa(value.trim()),
            ),

            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingMahasiswa
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMahasiswaPA.isEmpty
                  ? const Center(child: Text('Mahasiswa tidak ditemukan.'))
                  : ListView.builder(
                itemCount: _filteredMahasiswaPA.length,
                itemBuilder: (context, index) {
                  final mhs = _filteredMahasiswaPA[index];
                  return Card(
                    color: const Color(0xFFECEFCA), // Warna card (#ECEFCA)
                    child: ListTile(
                      title: Text(mhs['nama'] ?? '-'),
                      subtitle: Text('NIM: ${mhs['nim'] ?? '-'}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        final nim = mhs['nim'];
                        if (nim != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SetoranDetailPage(nim: nim.toString()),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
