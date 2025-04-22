import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AssignJudgeScreen extends StatefulWidget {
  const AssignJudgeScreen({super.key});

  @override
  State<AssignJudgeScreen> createState() => _AssignJudgeScreenState();
}

class _AssignJudgeScreenState extends State<AssignJudgeScreen> {
  final _assignEventController = TextEditingController();
  final _assignJudgeController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  void _assignJudgeToEvent() async {
    final eventNameInput = _assignEventController.text.trim();
    final judgeUsername = _assignJudgeController.text.trim();

    if (eventNameInput.isEmpty || judgeUsername.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      // Search for the event by its real name
      final eventSnapshot = await _database
          .child('events')
          .orderByChild('eventName')
          .equalTo(eventNameInput)
          .get();

      if (!eventSnapshot.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event does not exist')),
        );
        return;
      }

      // Retrieve the first matching event
      final eventData = (eventSnapshot.value as Map<dynamic, dynamic>)
          .values
          .first as Map<dynamic, dynamic>;
      final eventName = eventData['eventName'] as String;
      final criteria = (eventData['criteria'] as List<dynamic>)
          .map((criterion) => Map<String, dynamic>.from(criterion as Map))
          .toList();

      // Assign the judge to the event using the real event name
      await _database.child('event_assignments/$judgeUsername').set({
        'eventName': eventName,
        'criteria': criteria,
      });

      // Add the judge to the event's assigned judges list
      await _database.child('events/$eventName/assignedJudges').update({
        judgeUsername: true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judge assigned to event successfully')),
      );
      _assignEventController.clear();
      _assignJudgeController.clear();
    } catch (e) {
      debugPrint('Error assigning judge to event: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign judge: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Judge to Event')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Judge to Event',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _assignEventController,
              decoration: const InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _assignJudgeController,
              decoration: const InputDecoration(labelText: 'Judge Username'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _assignJudgeToEvent,
              child: const Text('Assign Judge'),
            ),
          ],
        ),
      ),
    );
  }
}
