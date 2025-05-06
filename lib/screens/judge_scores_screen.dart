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
        final Map<String, Map<String, Map<String, double>>> parsedScores = {};

        scoresData.forEach((event, judges) {
          if (judges is Map<dynamic, dynamic>) {
            judges.forEach((judge, contestants) {
              if (contestants is Map<dynamic, dynamic>) {
                contestants.forEach((contestant, criteria) {
                  if (criteria is Map<dynamic, dynamic>) {
                    final sanitizedEvent = sanitizeKey(event.toString());
                    final sanitizedContestant =
                        sanitizeKey(contestant.toString());
                    final sanitizedJudge = sanitizeKey(judge.toString());

                    parsedScores[sanitizedEvent] ??= {};
                    parsedScores[sanitizedEvent]![sanitizedContestant] ??= {};

                    // Calculate the total score for the contestant by summing up the scores for all criteria
                    double totalScore = 0.0;
                    criteria.forEach((criterion, score) {
                      if (score is double) {
                        totalScore += score;
                      }
                    });

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
        child: ConstrainedBox(
          constraints: const BoxConstraints.expand(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: selectedEvent == null
                ? _buildEventList()
                : _buildEventScores(selectedEvent!),
          ),
        ),
      ),
      floatingActionButton: selectedEvent != null
          ? FloatingActionButton(
              onPressed: () => _printEventScores(
                  selectedEvent!, eventScores[selectedEvent!]!),
              backgroundColor: const Color(0xFF08D9D6),
              child: const Icon(Icons.print, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEventList() {
    if (eventScores.isEmpty) {
      return const Center(
        child: Text(
          'No scores available',
          style: TextStyle(fontSize: 18, color: Color(0xFFEAEAEA)),
        ),
      );
    }

    return ListView(
      children: eventScores.keys.map((eventName) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF08D9D6), width: 1.5),
          ),
          color: Colors.white.withOpacity(0.1),
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            title: Text(
              eventName,
              style: const TextStyle(fontSize: 18, color: Color(0xFFEAEAEA)),
            ),
            trailing: const Icon(Icons.arrow_forward, color: Color(0xFF08D9D6)),
            onTap: () {
              setState(() {
                selectedEvent = eventName;
              });
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventScores(String eventName) {
    final scores = eventScores[eventName] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xFF08D9D6)),
                    onPressed: () {
                      setState(() {
                        selectedEvent = null;
                      });
                    },
                  ),
                  Text(
                    'Scores for $eventName',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEAEAEA),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildScrollableTable(
                columns: _buildTableColumns(eventName),
                rows: _buildTableRows(eventName),
                title: 'Judges\' Rankings Table',
              ),
              const SizedBox(height: 16),
              _buildScrollableTable(
                columns: _buildJudgeTableColumns(eventName),
                rows: _buildJudgeRankingRows(eventName),
                title: 'Main Scores Table',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollableTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required String title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEAEAEA),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: DataTable(
              columnSpacing: 50,
              dataRowMinHeight: 70,
              dataRowMaxHeight: 80,
              columns: columns,
              rows: rows,
              headingRowColor:
                  MaterialStateProperty.all(const Color(0xFF203A43)),
              dataRowColor: MaterialStateProperty.all(const Color(0xFF2C5364)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFFEAEAEA),
              ),
              dataTextStyle: const TextStyle(
                fontSize: 18,
                color: Color(0xFFEAEAEA),
              ),
              border: TableBorder.all(
                color: const Color(0xFF08D9D6),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DataColumn> _buildTableColumns(String eventName) {
    final assignedJudges = eventScores[eventName]
            ?.values
            .expand((judgeScores) => judgeScores.keys)
            .toSet()
            .toList() ??
        [];

    return [
      const DataColumn(
          label:
              Text('Contestant', style: TextStyle(color: Color(0xFFEAEAEA)))),
      ...assignedJudges.map((judge) => DataColumn(
              label: Text(
            criteriaToUsernames[judge] ?? judge,
            style: const TextStyle(color: Color(0xFFEAEAEA)),
          ))),
      const DataColumn(
          label: Text('Total', style: TextStyle(color: Color(0xFFEAEAEA)))),
      const DataColumn(
          label: Text('Rank', style: TextStyle(color: Color(0xFFEAEAEA)))),
    ];
  }

  List<DataRow> _buildTableRows(String eventName) {
    final assignedJudges = eventScores[eventName]
            ?.values
            .expand((judgeScores) => judgeScores.keys)
            .toSet()
            .toList() ??
        [];

    final scores = eventScores[eventName] ?? {};

    // Calculate individual ranks for each judge
    final Map<String, Map<String, int>> judgeRanks = {};
    for (final judge in assignedJudges) {
      final List<Map<String, dynamic>> judgeScores =
          scores.entries.map((entry) {
        final contestant = entry.key;
        final score = entry.value[judge] ?? 0.0;
        return {'contestant': contestant, 'score': score};
      }).toList();

      judgeScores.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));
      for (int i = 0; i < judgeScores.length; i++) {
        final contestant = judgeScores[i]['contestant'] as String;
        judgeRanks[judge] ??= {};
        judgeRanks[judge]![contestant] = i + 1;
      }
    }

    // Calculate total scores and overall ranks
    final List<Map<String, dynamic>> rankedScores = scores.entries.map((entry) {
      final contestant = entry.key;
      final judgeScores = entry.value;

      final totalScore = judgeScores.values.fold<double>(
        0,
        (sum, score) => sum + (score as double? ?? 0.0),
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
        DataCell(
            Text(contestant, style: const TextStyle(color: Color(0xFFEAEAEA)))),
        ...assignedJudges.map((judge) {
          final judgeRank = judgeRanks[judge]?[contestant];
          return DataCell(Text(
            judgeRank != null ? _getOrdinalSuffix(judgeRank) : '-',
            style: const TextStyle(color: Color(0xFFEAEAEA)),
          ));
        }),
        DataCell(Text(
          totalScore.toStringAsFixed(2),
          style: const TextStyle(color: Color(0xFFEAEAEA)),
        )),
        DataCell(Text(
          _getOrdinalSuffix(rank),
          style: const TextStyle(color: Color(0xFFEAEAEA)),
        )),
      ]);
    }).toList();
  }

  List<DataColumn> _buildJudgeTableColumns(String eventName) {
    final assignedJudges = eventScores[eventName]
            ?.values
            .expand((judgeScores) => judgeScores.keys)
            .toSet()
            .toList() ??
        [];

    return [
      const DataColumn(
          label:
              Text('Contestant', style: TextStyle(color: Color(0xFFEAEAEA)))),
      ...assignedJudges.map((judge) => DataColumn(
          label:
              Text(judge, style: const TextStyle(color: Color(0xFFEAEAEA))))),
      const DataColumn(
          label: Text('Average', style: TextStyle(color: Color(0xFFEAEAEA)))),
      const DataColumn(
          label: Text('Rank', style: TextStyle(color: Color(0xFFEAEAEA)))),
    ];
  }

  List<DataRow> _buildJudgeRankingRows(String eventName) {
    final assignedJudges = eventScores[eventName]
            ?.values
            .expand((judgeScores) => judgeScores.keys)
            .toSet()
            .toList() ??
        [];

    final scores = eventScores[eventName] ?? {};

    // Calculate average scores and ranks
    final List<Map<String, dynamic>> judgeRankedScores =
        scores.entries.map((entry) {
      final contestant = entry.key;
      final judgeScores = entry.value;

      final totalScore = judgeScores.values.fold<double>(
        0,
        (sum, score) => sum + (score as double? ?? 0.0),
      );
      final averageScore = assignedJudges.isNotEmpty
          ? (totalScore / assignedJudges.length)
          : 0.0;

      return {
        'contestant': contestant,
        'scores': judgeScores,
        'average': averageScore,
      };
    }).toList();

    // Sort by average score
    judgeRankedScores.sort((a, b) => b['average'].compareTo(a['average']));
    for (int i = 0; i < judgeRankedScores.length; i++) {
      judgeRankedScores[i]['rank'] = i + 1;
    }

    // Map to DataRow
    return judgeRankedScores.map((entry) {
      final contestant = entry['contestant'];
      final judgeScores = entry['scores'] as Map<String, dynamic>;
      final averageScore = entry['average'];
      final rank = entry['rank'];

      return DataRow(cells: [
        DataCell(
            Text(contestant, style: const TextStyle(color: Color(0xFFEAEAEA)))),
        ...assignedJudges.map((judge) {
          final score = judgeScores[judge] ?? 0.0;
          return DataCell(Text(
            score.toStringAsFixed(2),
            style: const TextStyle(color: Color(0xFFEAEAEA)),
          ));
        }),
        DataCell(Text(
          averageScore.toStringAsFixed(2),
          style: const TextStyle(color: Color(0xFFEAEAEA)),
        )),
        DataCell(Text(
          rank.toString(),
          style: const TextStyle(color: Color(0xFFEAEAEA)),
        )),
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

      // Prepare Main Scores Table
      final List<Map<String, dynamic>> rankedScores =
          scores.entries.map((entry) {
        final contestant = entry.key;
        final contestantScores = entry.value;

        final totalScore = contestantScores.values.fold<double>(
          0,
          (sum, score) => sum + (score as double? ?? 0.0),
        );

        return {
          'contestant': contestant,
          'scores': contestantScores,
          'total': totalScore,
        };
      }).toList();

      rankedScores.sort((a, b) => b['total'].compareTo(a['total']));
      for (int i = 0; i < rankedScores.length; i++) {
        rankedScores[i]['rank'] = i + 1;
      }

      final assignedJudges = scores.values
          .expand((judgeScores) => judgeScores.keys)
          .toSet()
          .toList();

      final mainHeaders = [
        'Contestant',
        ...assignedJudges.map((judge) => criteriaToUsernames[judge] ?? judge),
        'Total',
        'Rank'
      ];
      final mainData = rankedScores.map((entry) {
        final contestantScores = entry['scores'] as Map<String, dynamic>;
        return [
          entry['contestant'],
          ...assignedJudges.map(
              (judge) => contestantScores[judge]?.toStringAsFixed(2) ?? '0.00'),
          entry['total'].toStringAsFixed(2),
          _getOrdinalSuffix(entry['rank']),
        ];
      }).toList();

      // Prepare Judges' Rankings Table
      final List<Map<String, dynamic>> judgeRankedScores =
          scores.entries.map((entry) {
        final contestant = entry.key;
        final judgeScores = entry.value;

        final totalScore = judgeScores.values.fold<double>(
          0,
          (sum, score) => sum + (score as double? ?? 0.0),
        );
        final averageScore = assignedJudges.isNotEmpty
            ? (totalScore / assignedJudges.length)
            : 0.0;

        return {
          'contestant': contestant,
          'average': averageScore,
        };
      }).toList();

      judgeRankedScores.sort((a, b) => b['average'].compareTo(a['average']));
      for (int i = 0; i < judgeRankedScores.length; i++) {
        judgeRankedScores[i]['rank'] = i + 1;
      }

      final judgeHeaders = ['Contestant', 'Average', 'Rank'];
      final judgeData = judgeRankedScores.map((entry) {
        return [
          entry['contestant'],
          entry['average'].toStringAsFixed(2),
          _getOrdinalSuffix(entry['rank']),
        ];
      }).toList();

      // Add both tables to the PDF in landscape mode
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, // Set landscape orientation
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Scores for $eventName',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Text('Main Scores Table',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headers: mainHeaders,
                  data: mainData,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.center,
                  border: pw.TableBorder.all(),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Judges\' Rankings Table',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
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
