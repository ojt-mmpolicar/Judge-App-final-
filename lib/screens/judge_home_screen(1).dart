import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class JudgeHomeScreen extends StatefulWidget {
  final String judgeUsername;
  const JudgeHomeScreen({super.key, required this.judgeUsername});

  @override
  State<JudgeHomeScreen> createState() => _JudgeHomeScreenState();
}

class _JudgeHomeScreenState extends State<JudgeHomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _assignedEvents = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedEvent;
  Map<String, TextEditingController> _scoreControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchAssignedEvents();
  }

  Future<void> _fetchAssignedEvents() async {
    setState(() {
      _loading = true;
    });
    final snapshot = await _database
        .child('event_assignments/${widget.judgeUsername}')
        .get();
    List<Map<String, dynamic>> events = [];
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      // Support both legacy (single event) and new (multiple events) structure
      if (data.containsKey('eventName')) {
        // Legacy: single event assignment
        final eventName = data['eventName'];
        final criteria = data['criteria'] as List<dynamic>? ?? [];
        // Fetch contestants for this event
        final contestantsSnapshot = await _database
            .child('event_assignments/${widget.judgeUsername}/contestants')
            .get();
        Map<dynamic, dynamic> contestants = {};
        if (contestantsSnapshot.exists) {
          contestants = contestantsSnapshot.value as Map<dynamic, dynamic>;
        }
        events.add({
          'eventName': eventName,
          'criteria': criteria,
          'contestants': contestants,
        });
      } else {
        // New: multiple events assigned
        for (final entry in data.entries) {
          final eventValue = entry.value;
          if (eventValue is Map && eventValue.containsKey('eventName')) {
            // Fetch contestants for this event
            Map<dynamic, dynamic> contestants = {};
            if (eventValue['contestants'] != null) {
              contestants = eventValue['contestants'] as Map<dynamic, dynamic>;
            } else {
              // Try to fetch from DB in case not loaded in snapshot
              final contestantsSnapshot = await _database
                  .child(
                      'event_assignments/${widget.judgeUsername}/${eventValue['eventName']}/contestants')
                  .get();
              if (contestantsSnapshot.exists) {
                contestants =
                    contestantsSnapshot.value as Map<dynamic, dynamic>;
              }
            }
            events.add({
              'eventName': eventValue['eventName'],
              'criteria': eventValue['criteria'] ?? [],
              'contestants': contestants,
            });
          }
        }
      }
    }
    setState(() {
      _assignedEvents = events;
      _loading = false;
    });
  }

  void _selectEvent(Map<String, dynamic> event) {
    setState(() {
      _selectedEvent = event;
      _scoreControllers.clear();
      for (var c in event['criteria']) {
        _scoreControllers[c['title']] = TextEditingController();
      }
    });
  }

  Future<void> _submitScores() async {
    final eventName = _selectedEvent!['eventName'];
    final scores = <String, int>{};
    for (var c in _selectedEvent!['criteria']) {
      final title = c['title'];
      final controller = _scoreControllers[title];
      if (controller == null || controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter all scores')),
        );
        return;
      }
      scores[title] = int.tryParse(controller.text) ?? 0;
    }
    // Save scores to Firebase under judge's scores for the event
    await _database
        .child('scores/$eventName/${widget.judgeUsername}')
        .set(scores);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scores submitted!')),
    );
    setState(() {
      _selectedEvent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Home'),
      ),
      body: _selectedEvent == null
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: _assignedEvents.isEmpty
                  ? const Center(child: Text('No events assigned.'))
                  : ListView.builder(
                      itemCount: _assignedEvents.length,
                      itemBuilder: (context, idx) {
                        final event = _assignedEvents[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          child: ListTile(
                            title: Text(event['eventName'] ?? ''),
                            trailing: ElevatedButton(
                              onPressed: () => _selectEvent(event),
                              child: const Text('Score Event'),
                            ),
                          ),
                        );
                      },
                    ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scoring for: ${_selectedEvent!['eventName']}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ..._selectedEvent!['criteria'].map<Widget>((c) {
                    final title = c['title'];
                    final min = c['minScore'];
                    final max = c['maxScore'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextField(
                        controller: _scoreControllers[title],
                        decoration: InputDecoration(
                          labelText: '$title (Min: $min, Max: $max)',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _submitScores,
                        child: const Text('Submit Scores'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedEvent = null;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
