import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class JudgeScoresScreen extends StatefulWidget {
  const JudgeScoresScreen({super.key});

  @override
  State<JudgeScoresScreen> createState() => _JudgeScoresScreenState();
}

class _JudgeScoresScreenState extends State<JudgeScoresScreen> {
  // Darker color palette
  static const indigo = Color(0xFF232B6B); // much darker indigo
  static const softBlue = Color(0xFF3A4A7A); // deeper blue
  static const coral = Color(0xFFB83232); // darker coral/red
  static const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
  static const charcoalGray = Color(0xFF181A20); // almost black

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Map<String, Map<String, dynamic>>> eventScores = {};
  String? selectedEvent;
  Map<String, String> criteriaToUsernames = {};

  @override
  void initState() {
    super.initState();
    _fetchJudgeUsernames();
    _fetchEventScores();
  }

  void _fetchJudgeUsernames() async {
    try {
      final snapshot = await _database.child('judges').get();
      if (snapshot.exists) {
        final judgesData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          criteriaToUsernames = judgesData.map((key, value) {
            final username = (value is Map && value.containsKey('username'))
                ? value['username']
                : key.toString();
            return MapEntry(key.toString(), username);
          });
        });
      }
    } catch (e) {
      debugPrint('Error fetching judge usernames: $e');
    }
  }

  void _fetchEventScores() async {
    try {
      final snapshot = await _database.child('scores').get();
      if (snapshot.exists) {
        final scoresData = snapshot.value as Map<dynamic, dynamic>;
        // Parse: event -> contestant -> judge -> criteria
        final Map<String, Map<String, Map<String, double>>> parsedScores = {};

        scoresData.forEach((event, contestants) {
          if (contestants is Map<dynamic, dynamic>) {
            final sanitizedEvent = sanitizeKey(event.toString());
            parsedScores[sanitizedEvent] = {};
            contestants.forEach((contestant, judges) {
              if (judges is Map<dynamic, dynamic>) {
                final sanitizedContestant = sanitizeKey(contestant.toString());
                parsedScores[sanitizedEvent]![sanitizedContestant] = {};
                judges.forEach((judge, criteria) {
                  if (criteria is Map<dynamic, dynamic>) {
                    double totalScore = 0.0;
                    criteria.forEach((criterion, score) {
                      if (score is double || score is int) {
                        totalScore += (score as num).toDouble();
                      }
                    });
                    final sanitizedJudge = sanitizeKey(judge.toString());
                    parsedScores[sanitizedEvent]![sanitizedContestant]![
                        sanitizedJudge] = totalScore;
                  }
                });
              }
            });
          }
        });

        setState(() {
          eventScores = parsedScores;
        });
      }
    } catch (e) {
      debugPrint('Error fetching event scores: $e');
    }
  }

  String sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[.#$[\]/]'), '_');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Judge Scores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: indigo,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: offWhite,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: selectedEvent == null
                ? _buildEventListUI(indigo, softBlue, coral, charcoalGray)
                : _buildEventScoresUI(indigo, softBlue, coral, charcoalGray),
          ),
        ),
      ),
      floatingActionButton: selectedEvent != null
          ? FloatingActionButton(
              onPressed: () => _printEventScores(
                  selectedEvent!, eventScores[selectedEvent!]!),
              backgroundColor: coral,
              child: const Icon(Icons.print, color: Colors.white),
              tooltip: 'Print Scores',
            )
          : null,
    );
  }

  // Updated event list with colored borders and modern cards
  Widget _buildEventListUI(
      Color indigo, Color softBlue, Color coral, Color charcoalGray) {
    if (eventScores.isEmpty) {
      return Center(
        child: Text(
          'No scores available',
          style: TextStyle(
            fontSize: 18,
            color: charcoalGray,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }

    return ListView(
      children: eventScores.keys.map((eventName) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: indigo, width: 2),
          ),
          color: Colors.white,
          elevation: 6,
          margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            leading: Icon(Icons.emoji_events, color: coral, size: 32),
            title: Text(
              eventName,
              style: TextStyle(
                fontSize: 20,
                color: charcoalGray,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.delete, color: coral, size: 26),
                  tooltip: 'Delete Event',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: coral, size: 28),
                            const SizedBox(width: 10),
                            const Text(
                              'Delete Event',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to delete "$eventName"? This cannot be undone.',
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 16),
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
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      // Remove from Firebase
                      await _database.child('scores/$eventName').remove();
                      await _database.child('events/$eventName').remove();
                      setState(() {
                        eventScores.remove(eventName);
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Event "$eventName" deleted')),
                        );
                      }
                    }
                  },
                ),
                Icon(Icons.arrow_forward_ios, color: softBlue, size: 24),
              ],
            ),
            onTap: () {
              setState(() {
                selectedEvent = eventName;
              });
            },
            hoverColor: softBlue.withOpacity(0.12),
          ),
        );
      }).toList(),
    );
  }

  // Updated event scores UI with colored borders and modern tables
  Widget _buildEventScoresUI(
      Color indigo, Color softBlue, Color coral, Color charcoalGray) {
    final scores = eventScores[selectedEvent] ?? {};

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: coral, size: 28),
                onPressed: () {
                  setState(() {
                    selectedEvent = null;
                  });
                },
                tooltip: 'Back to Events',
              ),
              Text(
                'Scores for $selectedEvent',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: charcoalGray,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Center the Judges' Rankings Table
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildColoredTable(
                  columns: _buildTableColumns(selectedEvent!),
                  rows: _buildTableRows(selectedEvent!),
                  title: 'Main Scores Table',
                  indigo: indigo,
                  softBlue: softBlue,
                  coral: coral,
                  charcoalGray: charcoalGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Center the Main Scores Table
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildColoredTable(
                  columns: _buildJudgeTableColumns(selectedEvent!),
                  rows: _buildJudgeRankingRows(selectedEvent!),
                  title: 'Judges\' Rankings Table',
                  indigo: indigo,
                  softBlue: softBlue,
                  coral: coral,
                  charcoalGray: charcoalGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern colored DataTable with borders and header color
  Widget _buildColoredTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required String title,
    required Color indigo,
    required Color softBlue,
    required Color coral,
    required Color charcoalGray,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: indigo,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: softBlue, width: 2),
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: softBlue.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 800),
              child: DataTable(
                columnSpacing: 40,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columns: columns,
                rows: rows,
                headingRowColor:
                    MaterialStateProperty.all(indigo.withOpacity(0.12)),
                dataRowColor:
                    MaterialStateProperty.all(softBlue.withOpacity(0.06)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: coral,
                  fontFamily: 'Poppins',
                ),
                dataTextStyle: TextStyle(
                  fontSize: 16,
                  color: charcoalGray,
                  fontFamily: 'Poppins',
                ),
                border: TableBorder.all(
                  color: indigo,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getJudgeList(String eventName) {
    // Get all unique judges for this event, sorted for consistency
    final scores = eventScores[eventName] ?? {};
    final Set<String> judgeSet = {};
    // Build a set of all possible judge keys by collecting all keys from the 'judges' node
    final Set<String> allJudgeUsernames =
        criteriaToUsernames.keys.map((k) => k.toString()).toSet();

    for (final contestantScores in scores.values) {
      if (contestantScores is Map) {
        // Only add keys that are in the judges list (not contestant names)
        judgeSet.addAll(contestantScores.keys
            .where((k) => allJudgeUsernames.contains(k.toString())));
      }
    }
    final judgeList = judgeSet.toList();
    judgeList.sort((a, b) => (criteriaToUsernames[a] ?? a)
        .toString()
        .compareTo((criteriaToUsernames[b] ?? b).toString()));
    return judgeList;
  }

  List<String> _getContestantList(String eventName) {
    // Get all contestants for this event, sorted for consistency
    final scores = eventScores[eventName] ?? {};
    final allKeys = scores.keys.map((k) => k.toString()).toSet();
    // Remove any keys that are also judge usernames (from the 'judges' node)
    final judgeUsernames =
        criteriaToUsernames.keys.map((k) => k.toString()).toSet();
    final contestantList = allKeys.difference(judgeUsernames).toList();
    contestantList.sort((a, b) => a.compareTo(b));
    return contestantList;
  }

  List<DataColumn> _buildTableColumns(String eventName) {
    final judgeList = _getJudgeList(eventName);
    const charcoalGray = Color(0xFF2C3E50);
    return [
      const DataColumn(
          label: Text('CANDIDATES', style: TextStyle(color: charcoalGray))),
      ...judgeList.map((judge) => DataColumn(
            label: Text(
              criteriaToUsernames[judge] ?? judge,
              style: const TextStyle(color: charcoalGray),
            ),
          )),
      const DataColumn(
          label: Text('Total', style: TextStyle(color: charcoalGray))),
      const DataColumn(
          label: Text('Rank', style: TextStyle(color: charcoalGray))),
    ];
  }

  List<DataRow> _buildTableRows(String eventName) {
    final judgeList = _getJudgeList(eventName);
    final contestantList = _getContestantList(eventName);
    final scores = eventScores[eventName] ?? {};

    final List<Map<String, dynamic>> rankedScores =
        contestantList.map((contestant) {
      final judgeScores = scores[contestant] ?? {};
      final totalScore = judgeList.fold<double>(
        0,
        (sum, judge) => sum + (judgeScores[judge] as double? ?? 0.0),
      );
      return {
        'contestant': contestant,
        'scores': judgeScores,
        'total': totalScore,
      };
    }).toList();

    rankedScores.sort((a, b) => b['total'].compareTo(a['total']));
    for (int i = 0; i < rankedScores.length; i++) {
      rankedScores[i]['rank'] = i + 1;
    }

    return rankedScores.map((entry) {
      final contestant = entry['contestant'];
      final judgeScores = entry['scores'] as Map<String, dynamic>;
      final totalScore = entry['total'];
      final rank = entry['rank'];

      return DataRow(cells: [
        DataCell(Text(contestant, style: const TextStyle(color: charcoalGray))),
        ...judgeList.map((judge) {
          final score = judgeScores[judge] ?? 0.0;
          return DataCell(Text(
            score.toStringAsFixed(2),
            style: const TextStyle(color: charcoalGray),
          ));
        }),
        DataCell(Text(
          totalScore.toStringAsFixed(2),
          style: const TextStyle(color: charcoalGray),
        )),
        DataCell(Text(
          rank.toString(),
          style: const TextStyle(color: charcoalGray),
        )),
      ]);
    }).toList();
  }

  List<DataColumn> _buildJudgeTableColumns(String eventName) {
    final judgeList = _getJudgeList(eventName);
    const charcoalGray = Color(0xFF2C3E50);
    return [
      const DataColumn(
          label: Text('CANDIDATES', style: TextStyle(color: charcoalGray))),
      ...judgeList.map((judge) => DataColumn(
            label: Text(
              criteriaToUsernames[judge] ?? judge,
              style: const TextStyle(color: charcoalGray),
            ),
          )),
      const DataColumn(
          label: Text('Total', style: TextStyle(color: charcoalGray))),
      const DataColumn(
          label: Text('Average', style: TextStyle(color: charcoalGray))),
      const DataColumn(
          label: Text('Rank', style: TextStyle(color: charcoalGray))),
    ];
  }

  List<DataRow> _buildJudgeRankingRows(String eventName) {
    final judgeList = _getJudgeList(eventName);
    final contestantList = _getContestantList(eventName);
    final scores = eventScores[eventName] ?? {};

    final Map<String, Map<String, int>> judgeRanks = {};
    for (final judge in judgeList) {
      final List<Map<String, dynamic>> judgeContestantScores =
          contestantList.map((contestant) {
        final judgeScores = scores[contestant] ?? {};
        final score = judgeScores[judge] ?? 0.0;
        return {'contestant': contestant, 'score': score};
      }).toList();

      judgeContestantScores.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      for (int i = 0; i < judgeContestantScores.length; i++) {
        final contestant = judgeContestantScores[i]['contestant'] as String;
        judgeRanks[judge] ??= {};
        judgeRanks[judge]![contestant] = i + 1;
      }
    }

    // Build DataRows: each row is a contestant, columns are judge rankings
    // Also compute total of ranks, average (from scores), and overall rank for each contestant
    final List<Map<String, dynamic>> rankedRows =
        contestantList.map((contestant) {
      int totalRank = 0;
      List<String> rankStrings = [];
      double totalScore = 0.0;
      int judgeCount = 0;
      for (final judge in judgeList) {
        final rank = judgeRanks[judge]?[contestant] ?? 0;
        totalRank += rank;
        rankStrings.add(rank != 0 ? _getOrdinalSuffix(rank) : '-');
        final judgeScores = scores[contestant] ?? {};
        totalScore += (judgeScores[judge] ?? 0.0) as double;
        judgeCount++;
      }
      double averageScore = judgeCount > 0 ? totalScore / judgeCount : 0.0;
      return {
        'contestant': contestant,
        'ranks': rankStrings,
        'totalRank': totalRank,
        'averageScore': averageScore,
      };
    }).toList();

    // Sort by totalRank ascending, and if tie, by averageScore descending
    rankedRows.sort((a, b) {
      final cmp = a['totalRank'].compareTo(b['totalRank']);
      if (cmp != 0) return cmp;
      // If tie, higher averageScore gets better rank (lower index)
      return (b['averageScore'] as double)
          .compareTo(a['averageScore'] as double);
    });
    for (int i = 0; i < rankedRows.length; i++) {
      rankedRows[i]['rank'] = i + 1;
    }

    return rankedRows.map((row) {
      return DataRow(cells: [
        DataCell(Text(row['contestant'],
            style: const TextStyle(color: charcoalGray))),
        ...row['ranks'].map<DataCell>((rankStr) => DataCell(
            Text(rankStr, style: const TextStyle(color: charcoalGray)))),
        DataCell(Text(row['totalRank'].toString(),
            style: const TextStyle(color: charcoalGray))),
        DataCell(Text(
          (row['averageScore'] as double).toStringAsFixed(2),
          style: const TextStyle(color: charcoalGray),
        )),
        DataCell(Text(row['rank'].toString(),
            style: const TextStyle(color: charcoalGray))),
      ]);
    }).toList();
  }

  String _getOrdinalSuffix(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  void _printEventScores(
      String eventName, Map<String, Map<String, dynamic>> scores) async {
    try {
      final pdf = pw.Document();

      // Use the same logic as the UI for fetching judges and contestants
      final judgeList = _getJudgeList(eventName);
      final contestantList = _getContestantList(eventName);

      // --- Main Scores Table (same as _buildTableColumns/_buildTableRows) ---
      final mainHeaders = [
        'CANDIDATES',
        ...judgeList.map((judge) => criteriaToUsernames[judge] ?? judge),
        'Total',
        'Rank'
      ];

      final List<Map<String, dynamic>> rankedScores =
          contestantList.map((contestant) {
        final judgeScores = scores[contestant] ?? {};
        final totalScore = judgeList.fold<double>(
          0,
          (sum, judge) => sum + (judgeScores[judge] as double? ?? 0.0),
        );
        return {
          'contestant': contestant,
          'scores': judgeScores,
          'total': totalScore,
        };
      }).toList();

      rankedScores.sort((a, b) => b['total'].compareTo(a['total']));
      for (int i = 0; i < rankedScores.length; i++) {
        rankedScores[i]['rank'] = i + 1;
      }

      final mainData = rankedScores.map((entry) {
        final judgeScores = entry['scores'] as Map<String, dynamic>;
        return [
          entry['contestant'],
          ...judgeList
              .map((judge) => (judgeScores[judge] ?? 0.0).toStringAsFixed(2)),
          entry['total'].toStringAsFixed(2),
          entry['rank'].toString(),
        ];
      }).toList();

      // --- Judges' Rankings Table (same as _buildJudgeTableColumns/_buildJudgeRankingRows) ---
      final Map<String, Map<String, int>> judgeRanks = {};
      for (final judge in judgeList) {
        final List<Map<String, dynamic>> judgeContestantScores =
            contestantList.map((contestant) {
          final judgeScores = scores[contestant] ?? {};
          final score = judgeScores[judge] ?? 0.0;
          return {'contestant': contestant, 'score': score};
        }).toList();

        judgeContestantScores.sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double));

        for (int i = 0; i < judgeContestantScores.length; i++) {
          final contestant = judgeContestantScores[i]['contestant'] as String;
          judgeRanks[judge] ??= {};
          judgeRanks[judge]![contestant] = i + 1;
        }
      }

      final List<Map<String, dynamic>> rankedRows =
          contestantList.map((contestant) {
        int totalRank = 0;
        List<String> rankStrings = [];
        double totalScore = 0.0;
        int judgeCount = 0;
        for (final judge in judgeList) {
          final rank = judgeRanks[judge]?[contestant] ?? 0;
          totalRank += rank;
          rankStrings.add(rank != 0 ? _getOrdinalSuffix(rank) : '-');
          final judgeScores = scores[contestant] ?? {};
          totalScore += (judgeScores[judge] ?? 0.0) as double;
          judgeCount++;
        }
        double averageScore = judgeCount > 0 ? totalScore / judgeCount : 0.0;
        return {
          'contestant': contestant,
          'ranks': rankStrings,
          'totalRank': totalRank,
          'averageScore': averageScore,
        };
      }).toList();

      // Sort by totalRank ascending, and if tie, by averageScore descending
      rankedRows.sort((a, b) {
        final cmp = a['totalRank'].compareTo(b['totalRank']);
        if (cmp != 0) return cmp;
        return (b['averageScore'] as double)
            .compareTo(a['averageScore'] as double);
      });
      for (int i = 0; i < rankedRows.length; i++) {
        rankedRows[i]['rank'] = i + 1;
      }

      final judgeHeaders = [
        'CANDIDATES',
        ...judgeList.map((judge) => criteriaToUsernames[judge] ?? judge),
        'Total',
        'Average',
        'Rank'
      ];
      final judgeData = rankedRows.map((row) {
        return [
          row['contestant'],
          ...row['ranks'],
          row['totalRank'].toString(),
          (row['averageScore'] as double).toStringAsFixed(2),
          row['rank'].toString(),
        ];
      }).toList();

      // --- Add Main Scores Table to first page ---
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Main Scores Table for $eventName',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: mainHeaders,
                  data: mainData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                  border: pw.TableBorder.all(),
                ),
              ],
            );
          },
        ),
      );

      // --- Add Judges' Rankings Table to second page ---
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Judges\' Rankings Table for $eventName',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: judgeHeaders,
                  data: judgeData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                  border: pw.TableBorder.all(),
                ),
              ],
            );
          },
        ),
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results sent to printer')),
      );
    } catch (e) {
      debugPrint('Error printing scores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print scores: $e')),
      );
    }
  }
}
