import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class JudgeHomeScreen extends StatefulWidget {
  const JudgeHomeScreen({super.key});

  @override
  State<JudgeHomeScreen> createState() => _JudgeHomeScreenState();
}

class _JudgeHomeScreenState extends State<JudgeHomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String assignedEvent = '';
  List<String> contestantsList = []; // List of contestant names
  List<Map<String, dynamic>> criteriaList = [];
  String? selectedContestant; // Selected contestant
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final judgeUsername =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (judgeUsername != null) {
        _validateJudgeUsername(judgeUsername);
      } else {
        debugPrint('No judge username provided.');
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  void _validateJudgeUsername(String judgeUsername) async {
    try {
      final snapshot = await _database.child('judges/$judgeUsername').get();
      if (!mounted) return;
      if (snapshot.exists) {
        _fetchAssignedEvent(judgeUsername);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid username. Please contact the admin.')),
        );
        Navigator.pop(context); // Return to the login screen
      }
    } catch (e) {
      debugPrint('Error validating judge username: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _fetchAssignedEvent(String judgeUsername) async {
    try {
      final snapshot =
          await _database.child('event_assignments/$judgeUsername').get();
      if (snapshot.exists) {
        setState(() {
          assignedEvent = snapshot.child('eventName').value.toString();
          criteriaList = (snapshot.child('criteria').value as List<dynamic>)
              .map((criterion) {
            return {
              'title': criterion['title'],
              'minScore': int.tryParse(criterion['minScore'].toString()) ??
                  0, // Fetch minimum score
              'maxScore': int.tryParse(criterion['maxScore'].toString()) ??
                  0, // Fetch maximum score
              'controller': TextEditingController(),
            };
          }).toList();
        });
        _fetchContestantsForEvent(assignedEvent);
      } else {
        debugPrint('No assigned event found for the judge.');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assigned event: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _fetchContestantsForEvent(String eventName) async {
    try {
      final snapshot =
          await _database.child('events/$eventName/contestants').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          contestantsList = data.keys.map((key) => key.toString()).toList();
          if (contestantsList.isNotEmpty) {
            selectedContestant ??= contestantsList
                .first; // Set the first contestant if none is selected
          }
          isLoading = false;
        });
      } else {
        setState(() {
          contestantsList = [];
          selectedContestant = null; // Reset selected contestant if no data
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching contestants for event: $e');
      setState(() {
        contestantsList = [];
        selectedContestant = null; // Reset selected contestant on error
        isLoading = false;
      });
    }
  }

  void _submitScores() async {
    try {
      if (assignedEvent.isNotEmpty &&
          criteriaList.isNotEmpty &&
          selectedContestant != null) {
        final judgeUsername =
            ModalRoute.of(context)?.settings.arguments as String?;
        if (judgeUsername == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judge username is missing')),
          );
          return;
        }

        final scores = {};
        for (var criterion in criteriaList) {
          final criterionTitle = criterion['title'];
          final controller = criterion['controller'] as TextEditingController;
          if (controller.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Please enter a score for $criterionTitle before submitting.')),
            );
            return;
          }
          scores[criterionTitle] = int.parse(controller.text);
        }

        debugPrint(
            'Submitting scores for $selectedContestant by $judgeUsername in $assignedEvent: $scores');

        // Store the scores in Firebase
        await _database
            .child('scores/$assignedEvent/$selectedContestant/$judgeUsername')
            .set(scores);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Scores for $selectedContestant submitted successfully')),
        );

        // Clear the input fields
        for (var criterion in criteriaList) {
          final controller = criterion['controller'] as TextEditingController;
          controller.clear();
        }

        // Reset the selected contestant
        setState(() {
          selectedContestant = null;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No assigned event, criteria, or contestant')),
        );
      }
    } catch (e) {
      debugPrint('Error submitting scores: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit scores: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Judge Home')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (assignedEvent.isNotEmpty) ...[
                    Text('Assigned Event: $assignedEvent',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const Text('Select Contestant',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: selectedContestant,
                      hint: const Text('Select a contestant'),
                      items: contestantsList.map((contestant) {
                        return DropdownMenuItem<String>(
                          value: contestant,
                          child: Text(contestant),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedContestant = value;
                          debugPrint(
                              'Selected Contestant: $selectedContestant');
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Score Criteria',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ...criteriaList.map((criterion) {
                      final controller =
                          criterion['controller'] as TextEditingController;
                      final minScore = criterion['minScore'];
                      final maxScore = criterion['maxScore'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${criterion['title']} (Range: $minScore-$maxScore)',
                              style: const TextStyle(fontSize: 16),
                            ),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                  labelText: 'Score for ${criterion['title']}'),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _submitScores,
                      child: const Text('Submit Scores'),
                    ),
                  ] else ...[
                    const Text('No assigned event',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
    );
  }
}
