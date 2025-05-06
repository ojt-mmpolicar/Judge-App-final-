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
  List<String> _judgeList = []; // List of judges fetched from Firebase
  String? _selectedJudge; // Selected judge from the dropdown

  @override
  void initState() {
    super.initState();
    _fetchJudges(); // Fetch the list of judges on initialization
  }

  void _fetchJudges() async {
    try {
      final snapshot = await _database.child('judges').get();
      if (snapshot.exists) {
        final judgesData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _judgeList = judgesData.keys.map((key) => key.toString()).toList();
        });
      } else {
        debugPrint('No judges found in the database.');
      }
    } catch (e) {
      debugPrint('Error fetching judges: $e');
    }
  }

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
        if (!mounted) return;
        setState(() {
          _eventNameController.clear();
          _criteriaList = [];
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } else {
      if (!mounted) return;
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
        _selectedJudge != null) {
      // Use _selectedJudge instead of _judgeUsernameController
      try {
        final contestantName = _contestantNameController.text.trim();
        final eventName = _eventNameController.text.trim();
        final judgeUsername = _selectedJudge!; // Use the selected judge

        // Add contestant to the event
        await _database
            .child('events/$eventName/contestants/$contestantName')
            .set({'name': contestantName});

        // Assign the contestant to the judge
        await _database
            .child('event_assignments/$judgeUsername/contestants')
            .update({
          contestantName: {'name': contestantName},
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Contestant added and directly assigned to the judge')),
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

  void _assignJudge() async {
    if (_selectedJudge != null && _eventNameController.text.isNotEmpty) {
      try {
        final judgeUsername = _selectedJudge!;
        final eventName = _eventNameController.text;

        // Fetch criteria for the event
        final criteriaSnapshot =
            await _database.child('events/$eventName/criteria').get();
        final criteria = criteriaSnapshot.value;

        // Assign the event and criteria to the judge
        await _database.child('event_assignments/$judgeUsername').update({
          'eventName': eventName,
          'criteria': criteria,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judge assigned successfully')),
        );
        setState(() {
          _selectedJudge = null; // Reset the selected judge
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign judge: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a judge and fill in the event name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Event',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Event',
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
              TextField(
                controller: _eventNameController,
                decoration: InputDecoration(
                  labelText: 'Event Name',
                  labelStyle: const TextStyle(color: Color(0xFF8C8C8C)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF08D9D6)),
                  ),
                ),
                style: const TextStyle(color: Color(0xFFEAEAEA)),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
                ),
                color: Colors.white.withAlpha(25),
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
                          color: Color(0xFFEAEAEA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _criteriaTitleController,
                        decoration: InputDecoration(
                          labelText: 'Criteria Title',
                          labelStyle: const TextStyle(color: Color(0xFF8C8C8C)),
                          filled: true,
                          fillColor: Colors.white.withAlpha(25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide:
                                const BorderSide(color: Color(0xFF08D9D6)),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFFEAEAEA)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minScoreController,
                              decoration: InputDecoration(
                                labelText: 'Minimum Score',
                                labelStyle:
                                    const TextStyle(color: Color(0xFF8C8C8C)),
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF08D9D6)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFFEAEAEA)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxScoreController,
                              decoration: InputDecoration(
                                labelText: 'Maximum Score',
                                labelStyle:
                                    const TextStyle(color: Color(0xFF8C8C8C)),
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF08D9D6)),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Color(0xFFEAEAEA)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                            shadowColor: const Color(0xFF08D9D6).withAlpha(128),
                          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
                ),
                color: Colors.white.withAlpha(25),
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
                          color: Color(0xFFEAEAEA),
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
                                'Title: ${criteria['title']}, Min Score: ${criteria['minScore']}, Max Score: ${criteria['maxScore']}',
                                style: const TextStyle(
                                  color: Color(0xFFEAEAEA),
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        const Text(
                          'No criteria added yet',
                          style: TextStyle(color: Color(0xFF8C8C8C)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
                ),
                color: Colors.white.withAlpha(25),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Contestant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _contestantNameController,
                        decoration: InputDecoration(
                          labelText: 'Contestant Name',
                          labelStyle: const TextStyle(color: Color(0xFF8C8C8C)),
                          filled: true,
                          fillColor: Colors.white.withAlpha(25),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide:
                                const BorderSide(color: Color(0xFF08D9D6)),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFFEAEAEA)),
                      ),
                      const SizedBox(height: 16),
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
                            shadowColor: const Color(0xFF08D9D6).withAlpha(128),
                          ),
                          onPressed: _addContestant,
                          child: const Text('Add Contestant'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
                ),
                color: Colors.white.withAlpha(25),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign Judge',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEAEAEA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButton<String>(
                        value: _selectedJudge,
                        hint: const Text(
                          'Select a Judge',
                          style: TextStyle(color: Color(0xFFEAEAEA)),
                        ),
                        items: _judgeList.map((judge) {
                          return DropdownMenuItem<String>(
                            value: judge,
                            child: Text(
                              judge,
                              style: const TextStyle(color: Color(0xFFEAEAEA)),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedJudge = value;
                          });
                        },
                        dropdownColor: const Color(0xFF2C5364),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF08D9D6)),
                      ),
                      const SizedBox(height: 16),
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
                            shadowColor: const Color(0xFF08D9D6).withAlpha(128),
                          ),
                          onPressed: _assignJudge,
                          child: const Text('Assign Judge'),
                        ),
                      ),
                    ],
                  ),
                ),
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
                      side: const BorderSide(
                          color: Color.fromARGB(255, 255, 255, 255)),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF08D9D6).withAlpha(128),
                  ),
                  onPressed: _createEvent,
                  child: const Text('Create Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
