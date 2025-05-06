import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool isJudgeLogin = false;
  bool showAdminLogin = false;

  void _loginAsHardcodedAdmin() {
    if (_usernameController.text == 'admin' &&
        _passwordController.text == 'admin123') {
      Navigator.pushReplacementNamed(context, '/admin_home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin credentials')),
      );
    }
  }

  void _loginAsJudge() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    try {
      final snapshot = await _database.child('judges/$username').get();
      if (!mounted) return;
      if (snapshot.exists) {
        Navigator.pushNamed(context, '/judge_home', arguments: username);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid username. Please contact the admin.')),
        );
      }
    } catch (e) {
      debugPrint('Error validating judge username: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F0F), Color(0xFF08D9D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFF08D9D6), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF08D9D6).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.lock,
                      size: 100,
                      color: Color(0xFFEAEAEA),
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 20,
                          color: Color(0xFF08D9D6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Judging App',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEAEAEA),
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 10,
                          color: Color(0xFF08D9D6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!showAdminLogin && !isJudgeLogin) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: const Color(0xFFEAEAEA),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 20),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: const Color(0xFF08D9D6),
                        elevation: 10,
                      ),
                      onPressed: () {
                        setState(() {
                          showAdminLogin = true;
                        });
                      },
                      child: const Text('Admin Login'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: const Color(0xFFEAEAEA),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 20),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: const Color(0xFF08D9D6),
                        elevation: 10,
                      ),
                      onPressed: () {
                        setState(() {
                          isJudgeLogin = true;
                        });
                      },
                      child: const Text('Judge Login'),
                    ),
                  ] else if (showAdminLogin) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Color(0xFFEAEAEA)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: Color(0xFF08D9D6)),
                        ),
                      ),
                      style: const TextStyle(color: Color(0xFFEAEAEA)),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Color(0xFFEAEAEA)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: Color(0xFF08D9D6)),
                        ),
                      ),
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFFEAEAEA)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: const Color(0xFFEAEAEA),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: const Color(0xFF08D9D6),
                        elevation: 10,
                      ),
                      onPressed: _loginAsHardcodedAdmin,
                      child: const Text('Login as Admin'),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          showAdminLogin = false;
                        });
                      },
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Color(0xFFEAEAEA)),
                      ),
                    ),
                  ] else if (isJudgeLogin) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: Color(0xFF08D9D6)),
                        ),
                        labelStyle: const TextStyle(color: Color(0xFFEAEAEA)),
                      ),
                      style: const TextStyle(color: Color(0xFFEAEAEA)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: const Color(0xFFEAEAEA),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: const Color(0xFF08D9D6),
                        elevation: 10,
                      ),
                      onPressed: _loginAsJudge,
                      child: const Text('Login as Judge'),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isJudgeLogin = false;
                        });
                      },
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Color(0xFFEAEAEA)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
