import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:setorantif_dosen1/Services/Auth_service.dart';

class LogPage extends StatefulWidget {
  final String nim;
  const LogPage({super.key, required this.nim});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<dynamic> logs = [];
  bool isLoading = true;

  final AuthService authService = AuthService();
  final String apiBaseUrl = 'https://api.tif.uin-suska.ac.id/setoran-dev/v1';

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  String formatTanggal(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  String formatTanggalDanWaktu(String isoDateTime) {
    try {
      final dateTime = DateTime.parse(isoDateTime).toLocal(); // ubah ke waktu lokal
      final tanggal = '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year}';
      final waktu = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return '$tanggal pukul $waktu';
    } catch (e) {
      return isoDateTime;
    }
  }

  Future<void> fetchLogs() async {
    setState(() => isLoading = true);

    try {
      final token = await authService.getAccessToken();
      if (token == null) {
        debugPrint('[ERROR] Token tidak ditemukan.');
        setState(() => isLoading = false);
        return;
      }

      final url = Uri.parse('$apiBaseUrl/mahasiswa/setoran/${widget.nim}');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedLogs = data['data']?['setoran']?['log'] ?? [];

        setState(() {
          logs = fetchedLogs;
          isLoading = false;
        });
      } else {
        debugPrint('Gagal memuat log: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error saat ambil log: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131D4F),
      appBar: AppBar(
        title: const Text('Log Setoran Mahasiswa'),
        backgroundColor: const Color(0xFF131D4F),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : logs.isEmpty
          ? const Center(child: Text('Log Tidak Tersedia'))
          : ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final keterangan = log['keterangan']?.split(',').first ?? '(Tidak tersedia)';
          final waktuValidasi = formatTanggalDanWaktu(log['timestamp'] ?? '-');

          return Card(
            color: const Color(0xFFF5F5F5),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                log['aksi'] ?? 'Aksi tidak diketahui',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Surah: $keterangan'),
                  Text('Waktu: $waktuValidasi'),
                ],
              ),
              trailing: Text(
                log['dosen_yang_mengesahkan']?['nama'] ?? '-',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}
