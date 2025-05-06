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
  String assignedEvent = '';
  List<String> contestantsList = []; // List of contestant names
  List<Map<String, dynamic>> criteriaList = [];
  String? selectedContestant; // Single selected contestant
  bool isLoading = true;
  Map<String, Map<String, double>> _scores =
      {}; // Store scores for each contestant

  // Add this Set to track contestants who are fully scored
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
        debugPrint('Assigned event data: ${snapshot.value}');
        setState(() {
          assignedEvent = snapshot.child('eventName').value?.toString() ?? '';
        });

        if (assignedEvent.isNotEmpty) {
          // Fetch criteria for the assigned event
          final criteriaSnapshot =
              await _database.child('events/$assignedEvent/criteria').get();
          if (criteriaSnapshot.exists) {
            debugPrint('Criteria data: ${criteriaSnapshot.value}');
            setState(() {
              criteriaList =
                  (criteriaSnapshot.value as List<dynamic>).map((criterion) {
                final criterionMap =
                    Map<String, dynamic>.from(criterion as Map);
                return {
                  'title': criterionMap['title'] as String,
                  'minScore':
                      int.tryParse(criterionMap['minScore'].toString()) ?? 0,
                  'maxScore':
                      int.tryParse(criterionMap['maxScore'].toString()) ?? 0,
                  'controller': TextEditingController(),
                };
              }).toList();
            });
          } else {
            debugPrint('No criteria found for the event: $assignedEvent');
            setState(() {
              criteriaList = [];
            });
          }

          // Fetch contestants assigned to the judge
          final contestantsSnapshot = await _database
              .child('event_assignments/$judgeUsername/contestants')
              .get();
          if (contestantsSnapshot.exists) {
            debugPrint('Contestants data: ${contestantsSnapshot.value}');
            setState(() {
              contestantsList =
                  (contestantsSnapshot.value as Map<dynamic, dynamic>)
                      .values
                      .map((contestant) {
                if (contestant is Map && contestant.containsKey('name')) {
                  return contestant['name'].toString();
                }
                return 'Unknown Contestant';
              }).toList();
              if (contestantsList.isNotEmpty && selectedContestant == null) {
                selectedContestant = contestantsList.first; // Default selection
              }
            });
          } else {
            debugPrint('No contestants found for the judge: $judgeUsername');
            setState(() {
              contestantsList = [];
              selectedContestant = null;
            });
          }
        }
        setState(() {
          isLoading = false;
        });
      } else {
        debugPrint('No assigned event found for the judge: $judgeUsername');
        setState(() {
          assignedEvent = '';
          criteriaList = [];
          contestantsList = [];
          selectedContestant = null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assigned event: $e');
      setState(() {
        assignedEvent = '';
        criteriaList = [];
        contestantsList = [];
        selectedContestant = null;
        isLoading = false;
      });
    }
  }

  void _saveScoreForCurrentContestant() {
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
        // Save scores for the current contestant
        _scores[selectedContestant!] = scores;
        fullyScoredContestants.add(selectedContestant!); // Mark as fully scored

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scores saved for $selectedContestant')),
        );
      });
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
    // Show a popup notification
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Submitting Scores'),
          content: const Text('Your scores have been submitted successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    try {
      if (assignedEvent.isNotEmpty &&
          criteriaList.isNotEmpty &&
          _scores.length == contestantsList.length) {
        final judgeUsername =
            ModalRoute.of(context)?.settings.arguments as String?;
        if (judgeUsername == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judge username is missing')),
          );
          return;
        }

        debugPrint('Submitting scores for all contestants: $_scores');

        // Store the scores in Firebase
        await _database
            .child('scores/$assignedEvent/$judgeUsername')
            .set(_scores);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All scores submitted successfully')),
        );

        // Allow printing after submission
        setState(() {
          _scores = Map.from(_scores); // Ensure state is updated
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please score all contestants before submitting')),
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
    return Scaffold(
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back button
        title: const Text(
          'Judge Home',
          style: TextStyle(
            fontFamily: 'Roboto', // Modern font
            color: Color(0xFFEAEAEA),
            fontWeight: FontWeight.bold,
            fontSize: 24, // Increased font size for better visibility
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 10,
                color:
                    Color(0xFF08D9D6), // Bright Cyan glow for better visibility
              ),
            ],
          ),
        ),
        backgroundColor:
            const Color(0xFF0F0F0F), // Dark background for contrast
        elevation: 4, // Add slight shadow for separation from the background
        iconTheme:
            const IconThemeData(color: Color(0xFFEAEAEA)), // Match icon color
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight, // Ensure full height
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: kToolbarHeight +
                              48, // Increased space below the AppBar
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Assigned Event Section
                            if (assignedEvent.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C5364),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event,
                                            color: Color(0xFF08D9D6)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Assigned Event:',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFEAEAEA),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      assignedEvent,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFFEAEAEA),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Contestants Section
                            if (contestantsList.isNotEmpty) ...[
                              const Text(
                                'Select Contestant',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEAEAEA),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Wrap(
                                  spacing: 20, // Adjust spacing between buttons
                                  runSpacing: 20, // Adjust spacing between rows
                                  alignment: WrapAlignment
                                      .center, // Center align the buttons
                                  children: contestantsList.map((contestant) {
                                    final isSelected = selectedContestant ==
                                        contestant; // Check if selected
                                    final isFullyScored =
                                        fullyScoredContestants.contains(
                                            contestant); // Check if fully scored

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedContestant =
                                              contestant; // Update selected contestant
                                          _loadScoresForSelectedContestant(); // Load scores for the selected contestant
                                        });
                                      },
                                      child: Container(
                                        width: 180, // Reduced width
                                        height: 60, // Reduced height
                                        alignment: Alignment
                                            .center, // Center the text inside the button
                                        decoration: BoxDecoration(
                                          color: isFullyScored
                                              ? const Color(
                                                  0xFF08D9D6) // Highlight fully scored contestant
                                              : (isSelected
                                                  ? const Color(
                                                      0xFF08D9D6) // Highlight selected contestant
                                                  : const Color(
                                                      0xFF2C5364)), // Default color for unselected
                                          borderRadius: BorderRadius.circular(
                                              15), // Rounded corners
                                          boxShadow: [
                                            if (isSelected || isFullyScored)
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                          ],
                                        ),
                                        child: Text(
                                          contestant,
                                          style: const TextStyle(
                                            fontSize: 18, // Reduced font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Score Criteria Section
                            if (criteriaList.isNotEmpty) ...[
                              const Text(
                                'Score Criteria',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEAEAEA),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...criteriaList.map((criterion) {
                                final controller = criterion['controller']
                                    as TextEditingController;
                                final minScore = criterion['minScore'];
                                final maxScore = criterion['maxScore'];
                                final percentage = ((maxScore / 100) * 100)
                                    .toStringAsFixed(0); // Calculate percentage

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C5364),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${criterion['title']} (Range: $percentage%)',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEAEAEA),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            'Score: ${controller.text.isEmpty ? minScore.toStringAsFixed(1) : controller.text}',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF08D9D6),
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
                                              divisions:
                                                  (maxScore - minScore) * 10,
                                              label: controller.text.isEmpty
                                                  ? minScore.toStringAsFixed(1)
                                                  : controller.text,
                                              onChanged: (value) {
                                                setState(() {
                                                  controller.text =
                                                      value.toStringAsFixed(1);
                                                });
                                              },
                                              activeColor:
                                                  const Color(0xFF08D9D6),
                                              inactiveColor:
                                                  const Color(0xFF8C8C8C),
                                              thumbColor:
                                                  const Color(0xFF08D9D6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                        color: Colors.white,
                                        size: 32), // Larger icon
                                    label: const Text(
                                      'Save Scores',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight.bold), // Larger font
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF08D9D6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 20), // Larger padding
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 10,
                                    ),
                                  ),
                                  const SizedBox(
                                      width:
                                          40), // Increased spacing between buttons
                                  ElevatedButton.icon(
                                    onPressed:
                                        _scores.length == contestantsList.length
                                            ? _submitScores
                                            : null,
                                    icon: const Icon(Icons.send,
                                        color: Colors.white,
                                        size: 32), // Larger icon
                                    label: const Text(
                                      'Submit Scores',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight.bold), // Larger font
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF08D9D6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 20), // Larger padding
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      elevation: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
      floatingActionButton: _scores.isNotEmpty
          ? FloatingActionButton(
              onPressed: _printScores,
              backgroundColor: const Color(0xFF08D9D6),
              child: const Icon(Icons.print, color: Colors.white),
              tooltip: 'Print Scores',
            )
          : null,
    );
  }
}
