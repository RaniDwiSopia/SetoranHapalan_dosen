import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:setorantif_dosen1/Services/Auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService authService = AuthService();
  final String apiBaseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  Map<String, dynamic>? dosenData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDosenProfile();
  }

  Future<void> fetchDosenProfile() async {
    setState(() => isLoading = true);
    try {
      final token = await authService.getAccessToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/dosen/pa-saya'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          dosenData = jsonResponse['data'];
          isLoading = false;
        });
      } else {
        debugPrint("Gagal mengambil data dosen: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error mengambil data dosen: $e");
      setState(() => isLoading = false);
    }
  }

  String getInisial(String? nama) {
    if (nama == null || nama.isEmpty) return '?';
    return nama.trim().substring(0, 1).toUpperCase();
  }

  Color generateColorFromEmail(String? email) {
    if (email == null) return const Color(0xFFCCCCCC);
    final hash = email.codeUnits.fold(0, (prev, element) => prev + element);
    final r = (hash * 123) % 256;
    final g = (hash * 321) % 256;
    final b = (hash * 231) % 256;
    return Color.fromARGB(255, r, g, b);
  }

  Widget buildProfileHeader(String? nama, String? nip, String? email) {
    final inisial = getInisial(nama);
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: generateColorFromEmail(email),
          child: Text(
            inisial,
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          nama ?? '-',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          nip ?? '-',
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          email ?? '-',
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget buildRingkasanCard(List<dynamic> ringkasan) {
    return Card(
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Mahasiswa PA per Tahun',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),
            ...ringkasan.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tahun ${item['tahun']}'),
                    Text('${item['total']} mahasiswa'),
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFB7AC),
      appBar: AppBar(
        title: const Text('Profil Dosen PA'),
        backgroundColor: const Color(0xFFAFB7AC),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : dosenData == null
          ? const Center(child: Text('Data tidak tersedia'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildProfileHeader(
                dosenData?['nama'],
                dosenData?['nip'],
                dosenData?['email'],
              ),
              if (dosenData?['info_mahasiswa_pa'] != null &&
                  dosenData!['info_mahasiswa_pa']['ringkasan'] != null)
                buildRingkasanCard(
                  dosenData!['info_mahasiswa_pa']['ringkasan'],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
