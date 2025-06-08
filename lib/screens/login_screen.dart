import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
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

  static const indigo = Color(0xFF232B6B); // much darker indigo
  static const softBlue = Color(0xFF3A4A7A); // deeper blue
  static const coral = Color(0xFFB83232); // darker coral/red
  static const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
  static const charcoalGray = Color(0xFF181A20); // almost black

  Widget _buildLoginForm({required bool isAdmin}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Username',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: charcoalGray,
              fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person, color: softBlue),
            hintText: 'Enter Username',
            hintStyle: const TextStyle(fontFamily: 'Poppins'),
            filled: true,
            fillColor: offWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: softBlue, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: softBlue, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: indigo, width: 2),
            ),
          ),
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: charcoalGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        if (isAdmin)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: charcoalGray,
                    fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock, color: softBlue),
                  hintText: 'Enter Password',
                  hintStyle: const TextStyle(fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: offWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: softBlue, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: softBlue, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: indigo, width: 2),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: charcoalGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isAdmin ? _loginAsHardcodedAdmin : _loginAsJudge,
            icon: const Icon(Icons.login),
            label: Text(isAdmin ? 'Login as Admin' : 'Login as Judge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: softBlue, width: 2),
              ),
              elevation: 8,
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              showAdminLogin = false;
              isJudgeLogin = false;
            });
          },
          child: const Text(
            'Back',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: indigo,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400, // Set your desired max width
            ),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: softBlue, width: 2),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 80, color: indigo),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome to Judging App',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (!showAdminLogin && !isJudgeLogin)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('Admin Login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: indigo,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: softBlue, width: 2),
                                ),
                                elevation: 8,
                                textStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => showAdminLogin = true),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.person),
                              label: const Text('Judge Login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: coral,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: softBlue, width: 2),
                                ),
                                elevation: 8,
                                textStyle: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => isJudgeLogin = true),
                            ),
                          ),
                        ],
                      )
                    else if (showAdminLogin)
                      _buildLoginForm(isAdmin: true)
                    else if (isJudgeLogin)
                      _buildLoginForm(isAdmin: false),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
