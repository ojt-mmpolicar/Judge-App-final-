import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // Use super parameter

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool isJudgeLogin = false;
  bool showAdminLogin = false; // New state variable

  void _loginAsHardcodedAdmin() {
    if (_usernameController.text == 'admin' && _passwordController.text == 'admin123') {
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
          const SnackBar(content: Text('Invalid username. Please contact the admin.')),
        );
      }
    } catch (e) {
      debugPrint('Error validating judge username: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!showAdminLogin && !isJudgeLogin) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  setState(() {
                    showAdminLogin = true; // Show admin login form
                  });
                },
                child: const Text('Admin Login'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () {
                  setState(() {
                    isJudgeLogin = true; // Show judge login form
                  });
                },
                child: const Text('Judge Login'),
              ),
            ] else if (showAdminLogin) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loginAsHardcodedAdmin,
                child: const Text('Login as Admin'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    showAdminLogin = false; // Back to main screen
                  });
                },
                child: const Text('Back'),
              ),
            ] else if (isJudgeLogin) ...[
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loginAsJudge,
                child: const Text('Login as Judge'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    isJudgeLogin = false; // Back to main screen
                  });
                },
                child: const Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
