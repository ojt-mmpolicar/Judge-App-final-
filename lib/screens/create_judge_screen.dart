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
      appBar: AppBar(title: const Text('Create Judge Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Judge Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _judgeUsernameController,
              decoration: const InputDecoration(labelText: 'Judge Username'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _createJudgeAccount,
              child: const Text('Create Judge'),
            ),
          ],
        ),
      ),
    );
  }
}
