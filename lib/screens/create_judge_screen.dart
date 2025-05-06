import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateJudgeScreen extends StatefulWidget {
  const CreateJudgeScreen({super.key});

  @override
  State<CreateJudgeScreen> createState() => _CreateJudgeScreenState();
}

class _CreateJudgeScreenState extends State<CreateJudgeScreen> {
  final _judgeUsernameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  void _createJudgeAccount() async {
    final judgeUsername = _judgeUsernameController.text.trim();
    if (judgeUsername.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a judge username')),
      );
      return;
    }

    try {
      final snapshot = await _database.child('judges/$judgeUsername').get();
      if (snapshot.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judge username already exists')),
        );
        return;
      }

      await _database.child('judges/$judgeUsername').set({'active': true});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judge account created successfully')),
      );
      _judgeUsernameController.clear();
    } catch (e) {
      debugPrint('Error creating judge account: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create judge account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Judge Account',
          style:
              TextStyle(color: Color(0xFF1C1C1C), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1C1C1C)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Judge Account',
                style: TextStyle(
                  fontSize: 24,
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
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
                ),
                color: Colors.white.withOpacity(0.1),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Judge Username',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _judgeUsernameController,
                        decoration: InputDecoration(
                          labelText: 'Enter Judge Username',
                          labelStyle: const TextStyle(color: Color(0xFF8C8C8C)),
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF08D9D6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(color: Color(0xFF08D9D6)),
                            ),
                            elevation: 10,
                            shadowColor:
                                const Color(0xFF08D9D6).withOpacity(0.5),
                          ),
                          onPressed: _createJudgeAccount,
                          child: const Text('Create Judge'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
