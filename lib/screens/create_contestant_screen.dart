import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateContestantScreen extends StatefulWidget {
  const CreateContestantScreen({super.key});

  @override
  State<CreateContestantScreen> createState() => _CreateContestantScreenState();
}

class _CreateContestantScreenState extends State<CreateContestantScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final Map<String, List<String>> judges = {}; // {eventName: [judge1, judge2]}
  final List<String> events = [];
  final List<String> availableJudges = [];
  String? selectedEvent;
  String? selectedJudge;

  @override
  void initState() {
    super.initState();
    _fetchEventsAndJudges();
  }

  void _fetchEventsAndJudges() async {
    try {
      final eventsSnapshot = await _database.child('events').get();
      final judgesSnapshot = await _database.child('judges').get();

      if (eventsSnapshot.exists && judgesSnapshot.exists) {
        setState(() {
          // Fetch real event names instead of keys
          events.addAll((eventsSnapshot.value as Map).values.map((event) => event['eventName'].toString()));
          availableJudges.addAll((judgesSnapshot.value as Map).keys.cast<String>());
        });
      }
    } catch (e) {
      debugPrint('Error fetching events or judges: $e');
    }
  }

  void _addJudgeToEvent() {
    if (selectedEvent != null && selectedJudge != null) {
      setState(() {
        judges[selectedEvent!] ??= [];
        if (!judges[selectedEvent!]!.contains(selectedJudge)) {
          judges[selectedEvent!]!.add(selectedJudge!);
        }
      });
    }
  }

  void _submitContestant() async {
    final name = nameController.text.trim();
    final age = int.tryParse(ageController.text.trim());

    if (name.isEmpty || age == null || judges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and assign judges to events')),
      );
      return;
    }

    try {
      // Store the real event names in the contestant's data
      final Map<String, List<String>> realEventJudges = {};
      for (var entry in judges.entries) {
        final eventName = entry.key; // Use the real event name
        realEventJudges[eventName] = entry.value;
      }

      await _database.child('contestants').push().set({
        'name': name,
        'age': age,
        'events': realEventJudges, // Store real event names
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contestant added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error adding contestant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add contestant')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Contestant')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedEvent,
              items: events
                  .map((event) => DropdownMenuItem(
                        value: event,
                        child: Text(event),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedEvent = value),
              decoration: const InputDecoration(labelText: 'Select Event'),
            ),
            DropdownButtonFormField<String>(
              value: selectedJudge,
              items: availableJudges
                  .map((judge) => DropdownMenuItem(
                        value: judge,
                        child: Text(judge),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedJudge = value),
              decoration: const InputDecoration(labelText: 'Select Judge'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _addJudgeToEvent,
              child: const Text('Add Judge to Event'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: judges.entries.map((entry) {
                  final event = entry.key;
                  final assignedJudges = entry.value;
                  return ListTile(
                    title: Text('Event: $event'),
                    subtitle: Text('Judges: ${assignedJudges.join(', ')}'),
                  );
                }).toList(),
              ),
            ),
            ElevatedButton(
              onPressed: _submitContestant,
              child: const Text('Submit Contestant'),
            ),
          ],
        ),
      ),
    );
  }
}
