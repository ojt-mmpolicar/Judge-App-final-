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

  // Add this for local contestant management
  List<String> _contestantList = [];

  @override
  void initState() {
    super.initState();
    _fetchJudges();
    // Optionally, fetch contestants if editing an existing event
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
        _eventNameController.text.isNotEmpty) {
      try {
        final contestantName = _contestantNameController.text.trim();
        final eventName = _eventNameController.text.trim();
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        // Add contestant to the event with a timestamp
        await _database
            .child('events/$eventName/contestants/$contestantName')
            .set({'name': contestantName, 'addedAt': timestamp});

        setState(() {
          if (!_contestantList.contains(contestantName)) {
            _contestantList.add(contestantName);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contestant added')),
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

  void _editContestant(int index) async {
    final oldName = _contestantList[index];
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contestant'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Contestant Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final eventName = _eventNameController.text.trim();
      // Update in Firebase (remove old, add new)
      await _database.child('events/$eventName/contestants/$oldName').remove();
      await _database.child('events/$eventName/contestants/$newName').set(
          {'name': newName, 'addedAt': DateTime.now().millisecondsSinceEpoch});
      setState(() {
        _contestantList[index] = newName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contestant updated')),
      );
    }
  }

  void _removeContestant(int index) async {
    final name = _contestantList[index];
    final eventName = _eventNameController.text.trim();
    // Remove from Firebase
    await _database.child('events/$eventName/contestants/$name').remove();
    setState(() {
      _contestantList.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contestant removed')),
    );
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

        // Assign the event and criteria to the judge under the event name
        await _database
            .child('event_assignments/$judgeUsername/$eventName')
            .update({
          'eventName': eventName,
          'criteria': criteria,
        });

        // Assign all contestants to this judge for this event
        for (final contestant in _contestantList) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          await _database
              .child(
                  'event_assignments/$judgeUsername/$eventName/contestants/$contestant')
              .set({'name': contestant, 'addedAt': timestamp});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judge assigned successfully')),
        );
        setState(() {
          _selectedJudge = null;
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
          style: TextStyle(
            color: AppColors.charcoalGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoalGray),
      ),
      backgroundColor: AppColors.offWhite,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.softBlue, width: 2),
            ),
            elevation: 10,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, color: AppColors.indigo, size: 32),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Event',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoalGray,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _eventNameController,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.title, color: AppColors.softBlue),
                      hintText: 'Event Name',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.charcoalGray,
                      ),
                      filled: true,
                      fillColor: AppColors.offWhite,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.softBlue, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.softBlue, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppColors.indigo, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.charcoalGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- Criteria Card ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.softBlue, width: 1.5),
                    ),
                    color: Colors.white,
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
                              color: AppColors.charcoalGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _criteriaTitleController,
                            decoration: InputDecoration(
                              labelText: 'Criteria Title',
                              labelStyle: const TextStyle(
                                  color: AppColors.charcoalGray),
                              filled: true,
                              fillColor: AppColors.offWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    BorderSide(color: AppColors.softBlue),
                              ),
                            ),
                            style:
                                const TextStyle(color: AppColors.charcoalGray),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _minScoreController,
                                  decoration: InputDecoration(
                                    labelText: 'Minimum Score',
                                    labelStyle: const TextStyle(
                                        color: AppColors.charcoalGray),
                                    filled: true,
                                    fillColor: AppColors.offWhite,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide:
                                          BorderSide(color: AppColors.softBlue),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                      color: AppColors.charcoalGray),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _maxScoreController,
                                  decoration: InputDecoration(
                                    labelText: 'Maximum Score',
                                    labelStyle: const TextStyle(
                                        color: AppColors.charcoalGray),
                                    filled: true,
                                    fillColor: AppColors.offWhite,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide:
                                          BorderSide(color: AppColors.softBlue),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                      color: AppColors.charcoalGray),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.indigo,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(color: AppColors.indigo),
                                ),
                                elevation: 10,
                                shadowColor: AppColors.softBlue.withAlpha(128),
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
                  // --- Current Criteria Card ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.softBlue, width: 1.5),
                    ),
                    color: Colors.white,
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
                              color: AppColors.charcoalGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_criteriaList.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  _criteriaList.asMap().entries.map((entry) {
                                final index = entry.key;
                                final criteria = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Title: ${criteria['title']}, Min Score: ${criteria['minScore']}, Max Score: ${criteria['maxScore']}',
                                          style: const TextStyle(
                                            color: AppColors.charcoalGray,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: AppColors.indigo),
                                        tooltip: 'Edit Criteria',
                                        onPressed: () async {
                                          final edited = await showDialog<
                                              Map<String, String>>(
                                            context: context,
                                            builder: (context) {
                                              final titleController =
                                                  TextEditingController(
                                                      text: criteria['title']);
                                              final minController =
                                                  TextEditingController(
                                                      text:
                                                          criteria['minScore']);
                                              final maxController =
                                                  TextEditingController(
                                                      text:
                                                          criteria['maxScore']);
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                title: const Text(
                                                    'Edit Criteria',
                                                    style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller:
                                                          titleController,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Criteria Title'),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      controller: minController,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Minimum Score'),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      controller: maxController,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Maximum Score'),
                                                      keyboardType:
                                                          TextInputType.number,
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          AppColors.indigo,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    onPressed: () {
                                                      if (titleController.text
                                                              .isNotEmpty &&
                                                          minController.text
                                                              .isNotEmpty &&
                                                          maxController.text
                                                              .isNotEmpty) {
                                                        Navigator.of(context)
                                                            .pop({
                                                          'title':
                                                              titleController
                                                                  .text,
                                                          'minScore':
                                                              minController
                                                                  .text,
                                                          'maxScore':
                                                              maxController
                                                                  .text,
                                                        });
                                                      }
                                                    },
                                                    child: const Text('Save'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (edited != null) {
                                            setState(() {
                                              _criteriaList[index] = edited;
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text('Criteria updated')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const Text(
                              'No criteria added yet',
                              style: TextStyle(color: AppColors.charcoalGray),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- Add Contestant Card ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.softBlue, width: 1.5),
                    ),
                    color: Colors.white,
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
                              color: AppColors.charcoalGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _contestantNameController,
                            decoration: InputDecoration(
                              labelText: 'Contestant Name',
                              labelStyle: const TextStyle(
                                  color: AppColors.charcoalGray),
                              filled: true,
                              fillColor: AppColors.offWhite,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    BorderSide(color: AppColors.softBlue),
                              ),
                            ),
                            style:
                                const TextStyle(color: AppColors.charcoalGray),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.indigo,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(color: AppColors.indigo),
                                ),
                                elevation: 10,
                                shadowColor: AppColors.softBlue.withAlpha(128),
                              ),
                              onPressed: _addContestant,
                              child: const Text('Add Contestant'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Show list of contestants with edit option
                          if (_contestantList.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Contestants:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.charcoalGray,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._contestantList.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final name = entry.value;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: AppColors.charcoalGray,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: AppColors.indigo),
                                        tooltip: 'Edit Contestant',
                                        onPressed: () => _editContestant(idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: AppColors.coral),
                                        tooltip: 'Remove Contestant',
                                        onPressed: () => _removeContestant(idx),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // --- Assign Judge Card ---
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppColors.softBlue, width: 1.5),
                    ),
                    color: Colors.white,
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
                              color: AppColors.charcoalGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButton<String>(
                            value: _selectedJudge,
                            hint: const Text(
                              'Select a Judge',
                              style: TextStyle(color: AppColors.charcoalGray),
                            ),
                            items: _judgeList.map((judge) {
                              return DropdownMenuItem<String>(
                                value: judge,
                                child: Text(
                                  judge,
                                  style: const TextStyle(
                                      color: AppColors.charcoalGray),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedJudge = value;
                              });
                            },
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AppColors.softBlue),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.indigo,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(color: AppColors.indigo),
                                ),
                                elevation: 10,
                                shadowColor: AppColors.softBlue.withAlpha(128),
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
                  // --- Create Event Button ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createEvent,
                      icon: const Icon(Icons.celebration, color: Colors.white),
                      label: const Text(
                        'Create Event',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.softBlue.withOpacity(0.3),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ).copyWith(
                        overlayColor: MaterialStateProperty.resolveWith<Color?>(
                          (states) {
                            if (states.contains(MaterialState.hovered) ||
                                states.contains(MaterialState.pressed)) {
                              return AppColors.coral.withOpacity(0.15);
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppColors {
  static const indigo = Color(0xFF232B6B); // much darker indigo
  static const softBlue = Color(0xFF3A4A7A); // deeper blue
  static const coral = Color(0xFFB83232); // darker coral/red
  static const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
  static const charcoalGray = Color(0xFF181A20); // almost black
}
