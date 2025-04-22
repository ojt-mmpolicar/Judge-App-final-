import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _eventNameController = TextEditingController();
  final _criteriaTitleController = TextEditingController();
  final _minScoreController = TextEditingController();
  final _maxScoreController = TextEditingController();
  final _contestantNameController = TextEditingController();
  final _judgeUsernameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<Map<String, String>> _criteriaList = [];

  void _createEvent() async {
    if (_eventNameController.text.isNotEmpty && _criteriaList.isNotEmpty) {
      try {
        final eventName = _eventNameController.text;
        final criteria = _criteriaList;

        final eventData = {
          'eventName': eventName,
          'criteria': criteria
              .map((c) => {
                    'title': c['title'] ?? '',
                    'minScore': int.parse(c['minScore'] ?? '0'),
                    'maxScore': int.parse(c['maxScore'] ?? '0'),
                  })
              .toList(),
        };

        final eventRef = _database.child('events/$eventName');
        await eventRef.set(eventData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        setState(() {
          _eventNameController.clear();
          _criteriaList = [];
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all fields and add criteria')),
      );
    }
  }

  void _addCriteria() {
    if (_criteriaTitleController.text.isNotEmpty &&
        _minScoreController.text.isNotEmpty &&
        _maxScoreController.text.isNotEmpty) {
      setState(() {
        _criteriaList.add({
          'title': _criteriaTitleController.text,
          'minScore': _minScoreController.text,
          'maxScore': _maxScoreController.text,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criteria added successfully')),
      );

      _criteriaTitleController.clear();
      _minScoreController.clear();
      _maxScoreController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
    }
  }

  void _addContestant() async {
    if (_contestantNameController.text.isNotEmpty &&
        _eventNameController.text.isNotEmpty &&
        _judgeUsernameController.text.isNotEmpty) {
      try {
        final contestantName = _contestantNameController.text;
        final eventName = _eventNameController.text;
        final judgeUsername = _judgeUsernameController.text;

        // Add contestant to the event
        await _database
            .child('events/$eventName/contestants')
            .update({contestantName: true});

        // Assign contestant and criteria to the judge
        await _database.child('event_assignments/$judgeUsername').update({
          'eventName': eventName,
          'criteria': _criteriaList,
          'contestants': {contestantName: true},
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contestant added successfully')),
        );
        _contestantNameController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add contestant: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Event',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Scoring Criteria',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _criteriaTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Criteria Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minScoreController,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Score',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _maxScoreController,
                            decoration: const InputDecoration(
                              labelText: 'Maximum Score',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addCriteria,
                        child: const Text('Add Criteria'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Criteria',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_criteriaList.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _criteriaList.map((criteria) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                                'Title: ${criteria['title']}, Min Score: ${criteria['minScore']}, Max Score: ${criteria['maxScore']}'),
                          );
                        }).toList(),
                      )
                    else
                      const Text('No criteria added yet'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _contestantNameController,
              decoration: const InputDecoration(
                labelText: 'Contestant Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _judgeUsernameController,
              decoration: const InputDecoration(
                labelText: 'Judge Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addContestant,
              child: const Text('Add Contestant'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createEvent,
                child: const Text('Create Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
