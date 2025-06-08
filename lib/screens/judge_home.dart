import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class JudgeHomeScreen extends StatefulWidget {
  const JudgeHomeScreen({super.key});

  @override
  State<JudgeHomeScreen> createState() => _JudgeHomeScreenState();
}

class _JudgeHomeScreenState extends State<JudgeHomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> assignedEvents = [];
  Map<String, dynamic>? selectedEvent;
  String assignedEvent = '';
  List<String> contestantsList = [];
  List<Map<String, dynamic>> criteriaList = [];
  String? selectedContestant;
  bool isLoading = true;
  Map<String, Map<String, double>> _scores = {};
  Set<String> fullyScoredContestants = {};

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
        _fetchAssignedEvents(judgeUsername);
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

  void _fetchAssignedEvents(String judgeUsername) async {
    setState(() {
      isLoading = true;
    });
    try {
      final snapshot =
          await _database.child('event_assignments/$judgeUsername').get();
      List<Map<String, dynamic>> events = [];
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is Map) {
          // Always treat as multiple event assignments for robustness
          value.forEach((eventKey, eventValue) {
            if (eventValue is Map && eventValue.containsKey('eventName')) {
              events.add({
                'eventName': eventValue['eventName'],
                'contestants': eventValue['contestants'],
              });
            }
          });
          // Fallback for legacy single event assignment
          if (events.isEmpty && value.containsKey('eventName')) {
            final eventName = value['eventName']?.toString() ?? '';
            if (eventName.isNotEmpty) {
              events.add({
                'eventName': eventName,
                'contestants': value['contestants'],
              });
            }
          }
        }
      }
      setState(() {
        assignedEvents = events;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching assigned events: $e');
      setState(() {
        assignedEvents = [];
        isLoading = false;
      });
    }
  }

  Future<void> _selectEvent(Map<String, dynamic> event) async {
    setState(() {
      isLoading = true;
      selectedEvent = event;
      assignedEvent = event['eventName'] ?? '';
      contestantsList = [];
      criteriaList = [];
      selectedContestant = null;
      // DO NOT reset _scores or fullyScoredContestants here!
    });

    // --- Always fetch criteria from the database, not from event map ---
    final criteriaSnapshot =
        await _database.child('events/$assignedEvent/criteria').get();
    List<Map<String, dynamic>> loadedCriteria = [];
    if (criteriaSnapshot.exists) {
      final criteriaValue = criteriaSnapshot.value;
      if (criteriaValue is List) {
        loadedCriteria = criteriaValue
            .where((c) => c != null)
            .map<Map<String, dynamic>>((criterion) {
          final criterionMap = Map<String, dynamic>.from(criterion as Map);
          return {
            'title': criterionMap['title'] as String,
            'minScore': int.tryParse(criterionMap['minScore'].toString()) ?? 0,
            'maxScore': int.tryParse(criterionMap['maxScore'].toString()) ?? 0,
            'controller': TextEditingController(),
          };
        }).toList();
      } else if (criteriaValue is Map) {
        loadedCriteria = (criteriaValue as Map)
            .values
            .where((c) => c != null)
            .map<Map<String, dynamic>>((criterion) {
          final criterionMap = Map<String, dynamic>.from(criterion as Map);
          return {
            'title': criterionMap['title'] as String,
            'minScore': int.tryParse(criterionMap['minScore'].toString()) ?? 0,
            'maxScore': int.tryParse(criterionMap['maxScore'].toString()) ?? 0,
            'controller': TextEditingController(),
          };
        }).toList();
      }
    }
    setState(() {
      criteriaList = loadedCriteria;
    });

    // --- Fetch contestants assigned to this judge for this event ---
    List<String> loadedContestants = [];
    final judgeUsername = ModalRoute.of(context)?.settings.arguments as String?;
    if (judgeUsername != null && assignedEvent.isNotEmpty) {
      final contestantsSnapshot = await _database
          .child('event_assignments/$judgeUsername/$assignedEvent/contestants')
          .get();
      if (contestantsSnapshot.exists) {
        final contestantsValue = contestantsSnapshot.value;
        if (contestantsValue is Map) {
          final contestantsMap = Map<String, dynamic>.from(contestantsValue);
          final sortedEntries = contestantsMap.entries.toList()
            ..sort((a, b) {
              // If both have 'addedAt', sort by it, else keep order
              final aAdded = (a.value is Map && a.value['addedAt'] != null)
                  ? (a.value['addedAt'] as int)
                  : 0;
              final bAdded = (b.value is Map && b.value['addedAt'] != null)
                  ? (b.value['addedAt'] as int)
                  : 0;
              return aAdded.compareTo(bAdded);
            });
          loadedContestants = sortedEntries.map((e) {
            // If value is a map with 'name', use it, else use the key
            if (e.value is Map && e.value['name'] != null) {
              return e.value['name'].toString();
            } else {
              return e.key.toString();
            }
          }).toList();
        } else if (contestantsValue is List) {
          // If contestants are stored as a list
          loadedContestants =
              contestantsValue.where((c) => c != null).map<String>((c) {
            if (c is Map && c['name'] != null) {
              return c['name'].toString();
            }
            return c.toString();
          }).toList();
        }
      }
    }
    setState(() {
      contestantsList = loadedContestants;
      selectedContestant =
          contestantsList.isNotEmpty ? contestantsList.first : null;
      isLoading = false;
    });

    // Load all saved scores for this judge and event (handle >2 contestants)
    await _loadSavedScores();

    setState(() {
      // ...existing code...
      isLoading = false;
    });
  }

  Future<void> _loadSavedScores() async {
    final judgeUsername = ModalRoute.of(context)?.settings.arguments as String?;
    if (judgeUsername != null && assignedEvent.isNotEmpty) {
      final snapshot = await _database.child('scores/$assignedEvent').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        // Flatten scores for all contestants for this judge
        final Map<String, Map<String, double>> loadedScores = {};
        data.forEach((contestant, judgesMap) {
          if (judgesMap is Map && judgesMap.containsKey(judgeUsername)) {
            final judgeScores = judgesMap[judgeUsername];
            if (judgeScores is Map) {
              loadedScores[contestant] = Map<String, double>.from(
                judgeScores.map(
                  (key, value) => MapEntry(key, (value as num).toDouble()),
                ),
              );
            }
          }
        });
        setState(() {
          _scores = loadedScores;
          fullyScoredContestants = _scores.keys.toSet();
        });
      } else {
        setState(() {
          _scores = {};
          fullyScoredContestants = {};
        });
      }
    }
  }

  void _saveScoreForCurrentContestant() async {
    if (selectedContestant == null || selectedContestant!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contestant selected')),
      );
      return;
    }

    final Map<String, double> scores = {};
    bool hasError = false;

    for (var criterion in criteriaList) {
      final criterionTitle = criterion['title'] as String;
      final controller = criterion['controller'] as TextEditingController;
      final maxScore = criterion['maxScore'] as int;
      final minScore = criterion['minScore'] as int;

      if (controller.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter score for $criterionTitle')),
        );
        hasError = true;
        break;
      }

      final enteredScore = double.tryParse(controller.text);
      if (enteredScore == null ||
          enteredScore > maxScore ||
          enteredScore < minScore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Score for $criterionTitle must be between $minScore and $maxScore')),
        );
        hasError = true;
        break;
      }

      scores[criterionTitle] = enteredScore;
    }

    if (!hasError) {
      setState(() {
        _scores[selectedContestant!] = scores;
        fullyScoredContestants.add(selectedContestant!);
      });

      // Save to Firebase immediately for this contestant only
      final judgeUsername =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (judgeUsername != null && assignedEvent.isNotEmpty) {
        // Save only this contestant's scores for this judge
        await _database
            .child('scores/$assignedEvent/$selectedContestant/$judgeUsername')
            .set(scores);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scores saved for $selectedContestant')),
      );
    }
  }

  void _loadScoresForSelectedContestant() {
    if (selectedContestant != null && _scores.containsKey(selectedContestant)) {
      // Load the stored scores for the selected contestant
      final storedScores = _scores[selectedContestant]!;
      for (var criterion in criteriaList) {
        final criterionTitle = criterion['title'] as String;
        final controller = criterion['controller'] as TextEditingController;
        controller.text =
            storedScores[criterionTitle]?.toStringAsFixed(1) ?? '';
      }
    } else {
      // Reset input fields to the minimum score if no scores are stored
      for (var criterion in criteriaList) {
        final controller = criterion['controller'] as TextEditingController;
        final minScore = criterion['minScore'] as int;
        controller.text = minScore.toString();
      }
    }
  }

  void _submitScores() async {
    if (assignedEvent.isNotEmpty &&
        criteriaList.isNotEmpty &&
        _scores.length == contestantsList.length) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB83232), size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Confirm Submission',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Color(0xFF232B6B),
                  ),
                ),
              ],
            ),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  color: Color(0xFF181A20),
                ),
                children: [
                  const TextSpan(
                    text: 'Are you sure you want to ',
                  ),
                  TextSpan(
                    text: 'submit your scores',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB83232),
                    ),
                  ),
                  const TextSpan(
                    text: '?\n\n',
                  ),
                  TextSpan(
                    text: 'You will ',
                    style: TextStyle(color: Color(0xFF181A20)),
                  ),
                  TextSpan(
                    text: 'not be able to edit them after submission.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB83232),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF232B6B),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFB83232),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      try {
        final judgeUsername =
            ModalRoute.of(context)?.settings.arguments as String?;
        if (judgeUsername == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judge username is missing')),
          );
          return;
        }

        debugPrint('Submitting scores for all contestants: $_scores');

        // Save all contestants' scores for this judge (handle >2 contestants)
        for (final entry in _scores.entries) {
          final contestant = entry.key;
          final criteriaScores = entry.value;
          await _database
              .child('scores/$assignedEvent/$contestant/$judgeUsername')
              .set(criteriaScores);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All scores submitted successfully')),
        );

        setState(() {
          selectedEvent = null;
          assignedEvent = '';
          contestantsList = [];
          criteriaList = [];
          selectedContestant = null;
          // DO NOT clear _scores or fullyScoredContestants here!
        });
      } catch (e) {
        debugPrint('Error submitting scores: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit scores: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please score all contestants before submitting')),
      );
    }
  }

  void _printScores() async {
    try {
      final pdf = pw.Document();

      // Retrieve the judge's username from the route arguments
      final judgeUsername =
          ModalRoute.of(context)?.settings.arguments as String?;

      // Add a title to the PDF
      pdf.addPage(
        pw.Page(
          pageFormat:
              PdfPageFormat(8.5 * PdfPageFormat.inch, 14 * PdfPageFormat.inch)
                  .landscape, // Set to legal size in landscape
          margin: const pw.EdgeInsets.all(32), // Add space on all sides
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Scores for Event: $assignedEvent',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Judge: ${judgeUsername ?? "Unknown"}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Judge Scores',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: [
                    'Contestant',
                    ...criteriaList.map((criterion) => criterion['title']),
                    'Total', // Add a "Total" column
                  ],
                  data: _scores.entries.map((entry) {
                    final contestant = entry.key;
                    final scores = entry.value;
                    final totalScore = scores.values.fold(0.0,
                        (sum, score) => sum + score); // Calculate total score
                    return [
                      contestant,
                      ...criteriaList.map((criterion) {
                        final criterionTitle = criterion['title'];
                        return scores[criterionTitle]?.toStringAsFixed(1) ??
                            '0';
                      }),
                      totalScore.toStringAsFixed(1), // Add the total score
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 12),
                  border: pw.TableBorder.all(),
                ),
              ],
            );
          },
        ),
      );

      // Use the printing package to print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scores sent to printer')),
      );
    } catch (e) {
      debugPrint('Error printing scores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print scores: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Darker color palette
    const indigo = Color(0xFF232B6B); // much darker indigo
    const softBlue = Color(0xFF3A4A7A); // deeper blue
    const coral = Color(0xFFB83232); // darker coral/red
    const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
    const charcoalGray = Color(0xFF181A20); // almost black

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Judge Home',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: indigo,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.logout, color: coral, size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (shouldLogout == true) {
                Navigator.of(context).pop(); // Go back to login screen
              }
            },
          ),
        ],
      ),
      backgroundColor: offWhite,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedEvent == null
              // Event selection screen
              ? Center(
                  child: assignedEvents.isEmpty
                      ? const Text(
                          'No events assigned.',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        )
                      : Container(
                          width: double.infinity,
                          height: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Select Event to Score',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: charcoalGray,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Fill the screen with a vertical list of event cards
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 0),
                                  itemCount: assignedEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = assignedEvents[index];
                                    final eventName = event['eventName'] ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0, horizontal: 32.0),
                                      child: GestureDetector(
                                        onTap: () => _selectEvent(event),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          width: double.infinity,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: indigo,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: indigo.withOpacity(0.08),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              const SizedBox(width: 24),
                                              Icon(Icons.event,
                                                  color: coral, size: 40),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child: Text(
                                                  eventName,
                                                  textAlign: TextAlign.left,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Poppins',
                                                    color: charcoalGray,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                )
              // Scoring screen for selected event
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- Return Button ---
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                label: const Text(
                                  'Return',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF232B6B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: () {
                                  setState(() {
                                    selectedEvent = null;
                                    assignedEvent = '';
                                    contestantsList = [];
                                    criteriaList = [];
                                    selectedContestant = null;
                                    // Do not clear _scores or fullyScoredContestants
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Assigned Event Section
                            if (assignedEvent.isNotEmpty)
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: indigo, width: 2),
                                ),
                                color: Colors.white,
                                elevation: 8,
                                margin: const EdgeInsets.only(bottom: 24),
                                child: ListTile(
                                  leading:
                                      Icon(Icons.event, color: coral, size: 32),
                                  title: Text(
                                    'Assigned Event',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      color: charcoalGray,
                                      fontSize: 20,
                                    ),
                                  ),
                                  subtitle: Text(
                                    assignedEvent,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: charcoalGray,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),

                            // Contestants Section
                            if (contestantsList.isNotEmpty) ...[
                              const Text(
                                'Select Contestant',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: charcoalGray,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Wrap(
                                  spacing: 18,
                                  runSpacing: 18,
                                  alignment: WrapAlignment.center,
                                  children: contestantsList.map((contestant) {
                                    final isSelected =
                                        selectedContestant == contestant;
                                    final isFullyScored = fullyScoredContestants
                                        .contains(contestant);
                                    final scores = _scores[contestant];
                                    double total = 0;
                                    double maxTotal = 0;

                                    if (scores != null) {
                                      for (var criterion in criteriaList) {
                                        final title = criterion['title'];
                                        final maxScore =
                                            (criterion['maxScore'] as num)
                                                .toDouble();
                                        maxTotal += maxScore;
                                        total += scores[title] ?? 0;
                                      }
                                    }
                                    final percent = (maxTotal > 0)
                                        ? (total / maxTotal * 100)
                                        : 0;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedContestant = contestant;
                                          _loadScoresForSelectedContestant();
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        width: 170,
                                        height: 70,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isFullyScored
                                              ? softBlue
                                              : (isSelected
                                                  ? indigo
                                                  : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isFullyScored
                                                ? coral
                                                : (isSelected
                                                    ? indigo
                                                    : softBlue),
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            if (isSelected || isFullyScored)
                                              BoxShadow(
                                                color:
                                                    softBlue.withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              contestant,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isSelected || isFullyScored
                                                        ? Colors.white
                                                        : charcoalGray,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${percent.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    isSelected || isFullyScored
                                                        ? Colors.white70
                                                        : charcoalGray
                                                            .withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Score Criteria Section
                            if (criteriaList.isNotEmpty) ...[
                              const Text(
                                'Score Criteria',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: charcoalGray,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...criteriaList.map((criterion) {
                                final controller = criterion['controller']
                                    as TextEditingController;
                                final minScore = criterion['minScore'];
                                final maxScore = criterion['maxScore'];

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: softBlue, width: 2),
                                  ),
                                  color: Colors.white,
                                  elevation: 6,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          criterion['title'],
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: charcoalGray,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text(
                                              'Score: ${controller.text.isEmpty ? minScore.toStringAsFixed(1) : controller.text}',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: indigo,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Slider(
                                                value: double.tryParse(
                                                        controller.text) ??
                                                    minScore.toDouble(),
                                                min: minScore.toDouble(),
                                                max: maxScore.toDouble(),
                                                divisions: ((maxScore -
                                                            minScore) *
                                                        2)
                                                    .toInt(), // <-- increments of 0.5
                                                label: controller.text.isEmpty
                                                    ? minScore
                                                        .toStringAsFixed(1)
                                                    : controller.text,
                                                onChanged: (value) async {
                                                  setState(() {
                                                    controller.text = value
                                                        .toStringAsFixed(1);
                                                    if (selectedContestant !=
                                                        null) {
                                                      _scores[selectedContestant!] ??=
                                                          {};
                                                      _scores[selectedContestant!]![
                                                          criterion[
                                                              'title']] = value;
                                                      fullyScoredContestants
                                                          .remove(
                                                              selectedContestant!);
                                                    }
                                                  });
                                                  final judgeUsername =
                                                      ModalRoute.of(context)
                                                          ?.settings
                                                          .arguments as String?;
                                                  if (judgeUsername != null &&
                                                      assignedEvent
                                                          .isNotEmpty &&
                                                      selectedContestant !=
                                                          null) {
                                                    await _database
                                                        .child(
                                                            'scores/$assignedEvent/$judgeUsername')
                                                        .set(_scores);
                                                  }
                                                },
                                                activeColor: indigo,
                                                inactiveColor:
                                                    softBlue.withOpacity(0.5),
                                                thumbColor: coral,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],

                            // Action Buttons
                            const SizedBox(height: 20),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _saveScoreForCurrentContestant,
                                    icon: const Icon(Icons.save,
                                        color: Colors.white, size: 28),
                                    label: const Text(
                                      'Save Scores',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: indigo,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 8,
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _scores.length == contestantsList.length
                                            ? _submitScores
                                            : null,
                                    icon: const Icon(Icons.send,
                                        color: Colors.white, size: 28),
                                    label: const Text(
                                      'Submit Scores',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: coral,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      floatingActionButton: selectedEvent != null && _scores.isNotEmpty
          ? FloatingActionButton(
              onPressed: _printScores,
              backgroundColor: coral,
              child: const Icon(Icons.print, color: Colors.white),
              tooltip: 'Print Scores',
            )
          : null,
    );
  }
}
