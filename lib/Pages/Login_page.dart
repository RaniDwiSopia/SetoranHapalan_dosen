import 'package:flutter/material.dart';
import 'package:setorantif_dosen1/Services/Auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password wajib diisi')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = AuthService();

    // Jangan panggil logout di sini, biar token tetap konsisten

    bool loginSuccess = await authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (loginSuccess) {
      final token = await authService.getAccessToken();
      print('Token setelah login: $token');

      await Future.delayed(const Duration(milliseconds: 100)); // biar simpan token selesai

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/setoran');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login gagal, periksa email dan password')),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131D4F),
      appBar: AppBar(
        title: null,
        backgroundColor: const Color(0xFF131D4F),
        elevation: 0, // hilangkan shadow supaya terlihat menyatu
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: const Color(0xFFF5F5F5), // warna putih untuk card
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // supaya card sesuai isi konten
                children: [
                  Image.asset(
                    'assets/images/Logo hima.jpeg',
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF5F5F5), // warna tulisan 'Login' agar serasi
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login', style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 30.0),
                      backgroundColor: const Color(0xFF131D4F),
                    ),
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
