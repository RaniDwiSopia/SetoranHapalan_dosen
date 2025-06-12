import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'setoran_detail_page.dart';
import 'log_page.dart';
import 'profile_page.dart';
import 'package:setorantif_dosen1/Services/Auth_service.dart';

class SetoranPage extends StatefulWidget {
  const SetoranPage({super.key});

  @override
  State<SetoranPage> createState() => _SetoranPageState();
}

class _SetoranPageState extends State<SetoranPage> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService authService = AuthService();

  List<dynamic> _mahasiswaPA = [];
  List<dynamic> _filteredMahasiswaPA = [];
  bool _isLoadingMahasiswa = false;

  int _selectedIndex = 0;
  final String apiBaseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  Timer? _tokenRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startTokenRefreshTimer();
    _fetchMahasiswaPA();
  }

  void _startTokenRefreshTimer() {
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 13), (_) async {
      try {
        await authService.refreshToken();
        debugPrint("[INFO] Token berhasil diperbarui otomatis.");
      } catch (e) {
        debugPrint("[ERROR] Gagal memperbarui token otomatis: $e");
      }
    });
  }

  Future<void> showSessionExpiredDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sesi Berakhir'),
        content: const Text('Sesi login Anda telah berakhir. Silakan login kembali.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchMahasiswaPA() async {
    setState(() => _isLoadingMahasiswa = true);
    try {
      String? token = await authService.getAccessToken();
      if (token == null) {
        debugPrint('[ERROR] Token tidak ditemukan');
        await showSessionExpiredDialog();
        return;
      }

      final url = Uri.parse('$apiBaseUrl/dosen/pa-saya');
      http.Response response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 401) {
        debugPrint('[INFO] Token expired, mencoba refresh...');
        bool refreshed = await authService.refreshToken();
        if (refreshed) {
          token = await authService.getAccessToken();
          if (token != null) {
            response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
          } else {
            await showSessionExpiredDialog();
            return;
          }
        } else {
          await showSessionExpiredDialog();
          return;
        }
      }

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final mahasiswaList = result['data']?['info_mahasiswa_pa']?['daftar_mahasiswa'];

        if (mahasiswaList != null && mahasiswaList is List) {
          setState(() {
            _mahasiswaPA = mahasiswaList;
            _filteredMahasiswaPA = mahasiswaList;
          });
        }
      } else {
        debugPrint('[ERROR] ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ERROR] $e');
    } finally {
      setState(() => _isLoadingMahasiswa = false);
    }
  }

  void _filterMahasiswa(String keyword) {
    if (keyword.isEmpty) {
      setState(() => _filteredMahasiswaPA = _mahasiswaPA);
      return;
    }

    setState(() {
      _filteredMahasiswaPA = _mahasiswaPA.where((mhs) {
        final nama = (mhs['nama'] ?? '').toLowerCase();
        final nim = (mhs['nim'] ?? '').toString();
        return nama.contains(keyword.toLowerCase()) || nim.contains(keyword);
      }).toList();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget buildMahasiswaList() {
    return Scaffold(
      backgroundColor: const Color(0xFF131D4F),
      appBar: AppBar(
        title: const Text('Daftar Mahasiswa PA'),
        backgroundColor: const Color(0xFF131D4F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
              if (confirm == true) await _logout();
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
                hintText: 'Cari',
                hintStyle: const TextStyle(color: Colors.black),
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(color: Colors.black),
              onSubmitted: (value) => _filterMahasiswa(value.trim()),
              onChanged: (value) => _filterMahasiswa(value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingMahasiswa
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMahasiswaPA.isEmpty
                  ? const Center(child: Text('Mahasiswa tidak ditemukan.', style: TextStyle(color: Colors.white)))
                  : ListView.builder(
                itemCount: _filteredMahasiswaPA.length,
                itemBuilder: (context, index) {
                  final mhs = _filteredMahasiswaPA[index];
                  return Card(
                    color: const Color(0xFFF5F5F5),
                    child: ListTile(
                      title: Text(mhs['nama'] ?? '-'),
                      subtitle: Text('NIM: ${mhs['nim'] ?? '-'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
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
                          IconButton(
                            icon: const Icon(Icons.history),
                            onPressed: () {
                              final nim = mhs['nim'];
                              if (nim != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LogPage(nim: nim.toString()),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
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

  @override
  void dispose() {
    _searchController.dispose();
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      buildMahasiswaList(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black,
        backgroundColor: const Color(0xFF131D4F),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Daftar Mahasiswa'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
