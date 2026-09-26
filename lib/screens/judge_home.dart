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

  int _eventContestantCount(Map<String, dynamic> event) {
    final contestants = event['contestants'];
    if (contestants is Map || contestants is List) {
      return contestants.length;
    }
    return 0;
  }

  String _judgeInitial(String username) {
    final trimmed = username.trim();
    return trimmed.isEmpty ? 'J' : trimmed[0].toUpperCase();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: _JudgeHomePalette.danger,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Log out?',
              style: TextStyle(
                color: _JudgeHomePalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your judge account?',
          style: TextStyle(color: _JudgeHomePalette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _JudgeHomePalette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildJudgeDashboard() {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned(
          top: -170,
          right: -150,
          child: _JudgeHomeBackgroundOrb(size: 420),
        ),
        const Positioned(
          bottom: -220,
          left: -180,
          child: _JudgeHomeBackgroundOrb(size: 480),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pagePadding = constraints.maxWidth < 700 ? 16.0 : 26.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pagePadding,
                  24,
                  pagePadding,
                  40,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Judge Home',
                          style: TextStyle(
                            color: _JudgeHomePalette.ink,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Select an assigned event to begin scoring.',
                          style: TextStyle(
                            color: _JudgeHomePalette.muted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, metricConstraints) {
                            final compact = metricConstraints.maxWidth < 760;
                            final cardWidth = compact
                                ? metricConstraints.maxWidth
                                : (metricConstraints.maxWidth - 16) / 2;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 14,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _JudgeMetricCard(
                                    icon: Icons.calendar_month_rounded,
                                    iconColor: _JudgeHomePalette.primaryLight,
                                    iconBackground: const Color(0xFFF0F1FF),
                                    label: 'Assigned Events',
                                    value: '${assignedEvents.length}',
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _JudgeMetricCard(
                                    icon: Icons.play_circle_outline_rounded,
                                    iconColor: _JudgeHomePalette.success,
                                    iconBackground: const Color(0xFFE8F8F0),
                                    label: 'Ready to Score',
                                    value: '${assignedEvents.length}',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        if (assignedEvents.isEmpty)
                          const _NoAssignedJudgeEvents()
                        else ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Assigned Events',
                                  style: TextStyle(
                                    color: _JudgeHomePalette.ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F1FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${assignedEvents.length} total',
                                  style: const TextStyle(
                                    color: _JudgeHomePalette.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...assignedEvents.asMap().entries.map((entry) {
                            final event = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _JudgeEventCard(
                                eventName:
                                    event['eventName']?.toString() ?? 'Event',
                                contestantCount: _eventContestantCount(event),
                                highlighted: entry.key == 0,
                                onPressed: () => _selectEvent(event),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _returnToEventList() {
    setState(() {
      selectedEvent = null;
      assignedEvent = '';
      contestantsList = [];
      criteriaList = [];
      selectedContestant = null;
      // Keep the existing score state, matching the original workflow.
    });
  }

  int get _scoredContestantCount => _scores.keys
      .where((contestant) => contestantsList.contains(contestant))
      .length;

  double get _totalPossibleScore => criteriaList.fold<double>(
        0,
        (total, criterion) => total + (criterion['maxScore'] as num).toDouble(),
      );

  double _contestantTotalScore(String contestant) {
    final scores = _scores[contestant];
    if (scores == null) return 0;

    return criteriaList.fold<double>(
      0,
      (total, criterion) =>
          total + (scores[criterion['title']] ?? 0).toDouble(),
    );
  }

  double _contestantScorePercent(String contestant) {
    final maximum = _totalPossibleScore;
    if (maximum <= 0) return 0;
    return (_contestantTotalScore(contestant) / maximum * 100)
        .clamp(0, 100)
        .toDouble();
  }

  Widget _buildScoringWorkspace() {
    final scoredCount = _scoredContestantCount;
    final progress = contestantsList.isEmpty
        ? 0.0
        : (scoredCount / contestantsList.length).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned(
          top: -170,
          right: -150,
          child: _JudgeHomeBackgroundOrb(size: 420),
        ),
        const Positioned(
          bottom: -220,
          left: -180,
          child: _JudgeHomeBackgroundOrb(size: 480),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pagePadding = constraints.maxWidth < 700 ? 16.0 : 26.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pagePadding,
                  20,
                  pagePadding,
                  40,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: _returnToEventList,
                          style: TextButton.styleFrom(
                            foregroundColor: _JudgeHomePalette.primaryLight,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                          label: const Text(
                            'Back to Events',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Score Contestants',
                          style: TextStyle(
                            color: _JudgeHomePalette.ink,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Select a contestant and provide your scores for the assigned event.',
                          style: TextStyle(
                            color: _JudgeHomePalette.muted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildScoringEventSummary(
                          scoredCount: scoredCount,
                          progress: progress,
                        ),
                        if (contestantsList.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Select Contestant',
                                  style: TextStyle(
                                    color: _JudgeHomePalette.ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                'Choose a contestant to edit scores.',
                                style: TextStyle(
                                  color: _JudgeHomePalette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, contestantConstraints) {
                              final width = contestantConstraints.maxWidth;
                              final columns = width >= 1000
                                  ? 5
                                  : width >= 720
                                      ? 3
                                      : width >= 440
                                          ? 2
                                          : 1;
                              final gap = 10.0;
                              final cardWidth =
                                  (width - (gap * (columns - 1))) / columns;

                              return Wrap(
                                spacing: gap,
                                runSpacing: 10,
                                children: contestantsList.map((contestant) {
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _buildContestantCard(contestant),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, scoringConstraints) {
                            final criteriaPanel = _buildCriteriaPanel();
                            final summaryPanel = _buildScoreSummaryPanel();

                            if (scoringConstraints.maxWidth < 900) {
                              return Column(
                                children: [
                                  criteriaPanel,
                                  const SizedBox(height: 16),
                                  summaryPanel,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: criteriaPanel),
                                const SizedBox(width: 16),
                                Expanded(flex: 3, child: summaryPanel),
                              ],
                            );
                          },
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
    );
  }

  Widget _buildScoringEventSummary({
    required int scoredCount,
    required double progress,
  }) {
    final eventInformation = Row(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: _JudgeHomePalette.primaryLight,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned Event',
                style: TextStyle(
                  color: _JudgeHomePalette.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                assignedEvent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _JudgeHomePalette.ink,
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.groups_2_rounded,
                    color: _JudgeHomePalette.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${contestantsList.length} contestants',
                    style: const TextStyle(
                      color: _JudgeHomePalette.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final progressInformation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Progress',
          style: TextStyle(
            color: _JudgeHomePalette.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$scoredCount of ${contestantsList.length} scored',
          style: const TextStyle(
            color: _JudgeHomePalette.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE5E7F4),
                  valueColor: const AlwaysStoppedAnimation(
                    _JudgeHomePalette.primaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: _JudgeHomePalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );

    return _JudgeHomePanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                eventInformation,
                const SizedBox(height: 18),
                const Divider(height: 1, color: _JudgeHomePalette.border),
                const SizedBox(height: 18),
                progressInformation,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: eventInformation),
              Container(
                width: 1,
                height: 78,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                color: _JudgeHomePalette.border,
              ),
              Expanded(child: progressInformation),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContestantCard(String contestant) {
    final selected = selectedContestant == contestant;
    final scored = fullyScoredContestants.contains(contestant);
    final percent = _contestantScorePercent(contestant);

    return Material(
      color: selected ? const Color(0xFFF5F5FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: selected
              ? _JudgeHomePalette.primaryLight
              : _JudgeHomePalette.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedContestant = contestant;
            _loadScoresForSelectedContestant();
          });
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? _JudgeHomePalette.primaryLight
                      : const Color(0xFFF0F1FF),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color:
                      selected ? Colors.white : _JudgeHomePalette.primaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contestant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _JudgeHomePalette.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (scored || selected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: selected
                                ? _JudgeHomePalette.primaryLight
                                : _JudgeHomePalette.success,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${percent.toStringAsFixed(1)}% complete',
                      style: const TextStyle(
                        color: _JudgeHomePalette.muted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE5E7F4),
                        valueColor: const AlwaysStoppedAnimation(
                          _JudgeHomePalette.primaryLight,
                        ),
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
  }

  Widget _buildCriteriaPanel() {
    return _JudgeHomePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scoring Criteria',
                      style: TextStyle(
                        color: _JudgeHomePalette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rate the selected contestant for each criterion.',
                      style: TextStyle(
                        color: _JudgeHomePalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Total: ${_totalPossibleScore.toStringAsFixed(0)} points',
                  style: const TextStyle(
                    color: _JudgeHomePalette.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (criteriaList.isEmpty)
            const _NoScoringCriteria()
          else
            ...criteriaList.map(_buildCriterionRow),
        ],
      ),
    );
  }

  Widget _buildCriterionRow(Map<String, dynamic> criterion) {
    final controller = criterion['controller'] as TextEditingController;
    final minScore = (criterion['minScore'] as num).toDouble();
    final maxScore = (criterion['maxScore'] as num).toDouble();
    final currentValue = (double.tryParse(controller.text) ?? minScore)
        .clamp(minScore, maxScore)
        .toDouble();
    final divisions = ((maxScore - minScore) * 2).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _JudgeHomePalette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: _JudgeHomePalette.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      criterion['title'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _JudgeHomePalette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Range ${minScore.toStringAsFixed(0)}–${maxScore.toStringAsFixed(0)} points',
                      style: const TextStyle(
                        color: _JudgeHomePalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final slider = Slider(
            value: currentValue,
            min: minScore,
            max: maxScore,
            divisions: divisions > 0 ? divisions : null,
            label: currentValue.toStringAsFixed(1),
            activeColor: _JudgeHomePalette.primaryLight,
            inactiveColor: const Color(0xFFE1E4F1),
            thumbColor: _JudgeHomePalette.primaryLight,
            onChanged: selectedContestant == null
                ? null
                : (value) async {
                    setState(() {
                      controller.text = value.toStringAsFixed(1);
                      _scores[selectedContestant!] ??= {};
                      _scores[selectedContestant!]![criterion['title']] = value;
                      fullyScoredContestants.remove(selectedContestant!);
                    });

                    final judgeUsername =
                        ModalRoute.of(context)?.settings.arguments as String?;
                    if (judgeUsername != null &&
                        assignedEvent.isNotEmpty &&
                        selectedContestant != null) {
                      await _database
                          .child('scores/$assignedEvent/$judgeUsername')
                          .set(_scores);
                    }
                  },
          );

          final score = Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _JudgeHomePalette.border),
            ),
            child: Text(
              currentValue.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _JudgeHomePalette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

          if (constraints.maxWidth < 560) {
            return Column(
              children: [
                title,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: slider),
                    score,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 200, child: title),
              const SizedBox(width: 10),
              Expanded(child: slider),
              const SizedBox(width: 8),
              score,
              const SizedBox(width: 7),
              Text(
                '/ ${maxScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _JudgeHomePalette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScoreSummaryPanel() {
    final contestant = selectedContestant;
    final total = contestant == null ? 0.0 : _contestantTotalScore(contestant);
    final maximum = _totalPossibleScore;
    final percent = maximum <= 0 ? 0.0 : (total / maximum).clamp(0.0, 1.0);
    final canSubmit = _scores.length == contestantsList.length;

    return _JudgeHomePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: _JudgeHomePalette.primaryLight,
                size: 24,
              ),
              SizedBox(width: 9),
              Text(
                'Score Summary',
                style: TextStyle(
                  color: _JudgeHomePalette.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contestant ?? 'No contestant selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _JudgeHomePalette.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      total.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _JudgeHomePalette.primary,
                        fontSize: 27,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/ ${maximum.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _JudgeHomePalette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(percent * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: _JudgeHomePalette.primaryLight,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(
                      _JudgeHomePalette.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            canSubmit
                ? 'All contestants have scores and are ready to submit.'
                : 'Score every contestant before submitting.',
            style: TextStyle(
              color: canSubmit
                  ? _JudgeHomePalette.success
                  : _JudgeHomePalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSubmit ? _submitScores : null,
              style: FilledButton.styleFrom(
                backgroundColor: _JudgeHomePalette.primaryLight,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD8DAE8),
                disabledForegroundColor: const Color(0xFF9296A9),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text(
                'Submit Scores',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const offWhite = _JudgeHomePalette.background;
    final judgeUsername =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'Judge';
    final showJudgeLabel = MediaQuery.sizeOf(context).width >= 520;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF8FAFF),
        foregroundColor: _JudgeHomePalette.ink,
        surfaceTintColor: const Color(0xFFF8FAFF),
        toolbarHeight: 66,
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: _JudgeHomePalette.primaryLight,
              size: 27,
            ),
            SizedBox(width: 10),
            Text(
              'Judging App',
              style: TextStyle(
                color: _JudgeHomePalette.ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _JudgeHomePalette.primaryLight,
                  _JudgeHomePalette.primary,
                ],
              ),
            ),
            child: Text(
              _judgeInitial(judgeUsername),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (showJudgeLabel) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 124,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judgeUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _JudgeHomePalette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Assigned Judge',
                    style: TextStyle(
                      color: _JudgeHomePalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _JudgeHomePalette.border),
        ),
      ),
      backgroundColor: offWhite,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: _JudgeHomePalette.primary,
              ),
            )
          : selectedEvent == null
              ? _buildJudgeDashboard()
              // Scoring screen for selected event
              : _buildScoringWorkspace(),
      floatingActionButton: null,
    );
  }
}

class _JudgeHomePanel extends StatelessWidget {
  const _JudgeHomePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143034A8),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NoScoringCriteria extends StatelessWidget {
  const _NoScoringCriteria();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _JudgeHomePalette.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.rule_folder_outlined,
            color: _JudgeHomePalette.muted,
            size: 30,
          ),
          SizedBox(height: 9),
          Text(
            'No scoring criteria available',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _JudgeHomePalette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _JudgeMetricCard extends StatelessWidget {
  const _JudgeMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143034A8),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 27),
          ),
          const SizedBox(width: 15),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _JudgeHomePalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _JudgeHomePalette.ink,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JudgeEventCard extends StatelessWidget {
  const _JudgeEventCard({
    required this.eventName,
    required this.contestantCount,
    required this.highlighted,
    required this.onPressed,
  });

  final String eventName;
  final int contestantCount;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFFF9F9FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted
              ? _JudgeHomePalette.primaryLight
              : _JudgeHomePalette.border,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final eventDetails = Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? const Color(0xFFEDEEFF)
                          : const Color(0xFFF1F2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: _JudgeHomePalette.primaryLight,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (highlighted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7E8FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: _JudgeHomePalette.primaryLight,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'First Assigned',
                                  style: TextStyle(
                                    color: _JudgeHomePalette.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                        ],
                        Text(
                          eventName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _JudgeHomePalette.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.groups_2_rounded,
                              color: _JudgeHomePalette.muted,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$contestantCount contestants',
                              style: const TextStyle(
                                color: _JudgeHomePalette.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final status = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _JudgeHomePalette.success,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 7, height: 7),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Ready',
                      style: TextStyle(
                        color: _JudgeHomePalette.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );

              final button = FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: _JudgeHomePalette.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                label: const Text(
                  'Start Scoring',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              );

              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    eventDetails,
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        status,
                        const SizedBox(width: 12),
                        Expanded(child: button),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: eventDetails),
                  const SizedBox(width: 18),
                  status,
                  const SizedBox(width: 28),
                  button,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoAssignedJudgeEvents extends StatelessWidget {
  const _NoAssignedJudgeEvents();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143034A8),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: _JudgeHomePalette.muted,
            size: 42,
          ),
          SizedBox(height: 14),
          Text(
            'No events assigned',
            style: TextStyle(
              color: _JudgeHomePalette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Assigned events will appear here when they are added by an administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _JudgeHomePalette.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _JudgeHomeBackgroundOrb extends StatelessWidget {
  const _JudgeHomeBackgroundOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFCBD2FF).withValues(alpha: 0.72),
      ),
    );
  }
}

class _JudgeHomePalette {
  const _JudgeHomePalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryLight = Color(0xFF4B50D7);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const danger = Color(0xFFD92D38);
  static const success = Color(0xFF0FA958);
}
