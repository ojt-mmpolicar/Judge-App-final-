import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:printing/printing.dart'; // Add this import for printing functionality
import 'package:pdf/pdf.dart'; // Add this import for PDF generation
import 'package:pdf/widgets.dart' as pw; // Add this import for PDF widgets

class JudgeScoresScreen extends StatefulWidget {
  const JudgeScoresScreen({super.key});

  @override
  State<JudgeScoresScreen> createState() => _JudgeScoresScreenState();
}

class _JudgeScoresScreenState extends State<JudgeScoresScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Map<String, Map<String, Map<String, dynamic>>> eventScores =
      {}; // {eventName: {contestant: {criterion: [scores]}}}
  String? selectedEvent;

  @override
  void initState() {
    super.initState();
    _fetchEventScores();
  }

  void _fetchEventScores() async {
    try {
      final snapshot = await _database.child('scores').get();
      if (snapshot.exists) {
        debugPrint('Raw scores data: ${snapshot.value}');
        final scoresData = snapshot.value as Map<dynamic, dynamic>;
        final Map<String, Map<String, Map<String, dynamic>>> parsedScores = {};

        scoresData.forEach((event, contestants) {
          if (contestants is Map<dynamic, dynamic>) {
            contestants.forEach((contestant, judges) {
              if (judges is Map<dynamic, dynamic>) {
                judges.forEach((judge, criteria) {
                  if (criteria is Map<dynamic, dynamic>) {
                    criteria.forEach((criterion, score) {
                      parsedScores[event] ??= {};
                      parsedScores[event]![contestant] ??= {};
                      parsedScores[event]![contestant]![criterion] ??= [];
                      parsedScores[event]![contestant]![criterion]
                          .add(score as int);
                    });
                  }
                });
              }
            });
          }
        });

        debugPrint('Parsed scores: $parsedScores');
        setState(() {
          eventScores = parsedScores;
        });
      } else {
        debugPrint('No scores found in the database.');
        setState(() {
          eventScores = {};
        });
      }
    } catch (e) {
      debugPrint('Error fetching event scores: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Judge Scores')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: selectedEvent == null
            ? _buildEventList()
            : _buildEventScores(selectedEvent!),
      ),
    );
  }

  Widget _buildEventList() {
    if (eventScores.isEmpty) {
      return const Center(
        child: Text('No scores available', style: TextStyle(fontSize: 16)),
      );
    }

    return ListView(
      children: eventScores.keys.map((eventName) {
        return ListTile(
          title: Text(eventName, style: const TextStyle(fontSize: 18)),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            setState(() {
              selectedEvent = eventName;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildEventScores(String eventName) {
    final scores = eventScores[eventName] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  selectedEvent = null;
                });
              },
            ),
            Text(
              'Scores for $eventName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: _buildTableColumns(scores),
              rows: _buildTableRows(scores),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: () => _printEventScores(eventName, scores),
            child: const Text('Print Results'),
          ),
        ),
      ],
    );
  }

  void _printEventScores(
      String eventName, Map<String, Map<String, dynamic>> scores) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          final headers = [
            'Contestant',
            ...scores.values.first.keys,
            'Average Score'
          ];
          final data = scores.entries.map((entry) {
            final contestant = entry.key;
            final contestantScores = entry.value;

            final row = [
              contestant,
              ...contestantScores.keys.map((criterion) {
                final scoreList = contestantScores[criterion] as List<dynamic>;
                final totalScore = scoreList.fold<int>(
                    0, (sum, score) => sum + (score as int));
                return totalScore.toString();
              }),
              (() {
                final totalScore = contestantScores.values.fold<int>(
                  0,
                  (sum, scoreList) =>
                      sum +
                      (scoreList as List<dynamic>)
                          .fold<int>(0, (sum, score) => sum + (score as int)),
                );
                final averageScore = contestantScores.isNotEmpty
                    ? (totalScore / contestantScores.length).toStringAsFixed(2)
                    : '0';
                return averageScore;
              })(),
            ];
            return row;
          }).toList();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Scores for $eventName',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.center,
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
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
      const SnackBar(content: Text('Results sent to printer')),
    );
  }

  List<DataColumn> _buildTableColumns(
      Map<String, Map<String, dynamic>> scores) {
    final criteria = scores.values
        .expand((contestantScores) => contestantScores.keys)
        .toSet()
        .toList();

    return [
      const DataColumn(label: Text('Contestant')),
      ...criteria.map((criterion) => DataColumn(label: Text(criterion))),
      const DataColumn(label: Text('Average Score')),
    ];
  }

  List<DataRow> _buildTableRows(Map<String, Map<String, dynamic>> scores) {
    return scores.entries.map((entry) {
      final contestant = entry.key;
      final contestantScores = entry.value;

      final criteria = contestantScores.keys.toList();
      final totalScore = criteria.fold<int>(
        0,
        (sum, criterion) =>
            sum +
            (contestantScores[criterion] as List<dynamic>)
                .fold<int>(0, (sum, score) => sum + (score as int)),
      );
      final averageScore = criteria.isNotEmpty
          ? (totalScore / criteria.length).toStringAsFixed(2)
          : '0';

      return DataRow(
        cells: [
          DataCell(Text(contestant)),
          ...criteria.map((criterion) {
            final scores = contestantScores[criterion] as List<dynamic>;
            final scoreSum =
                scores.fold<int>(0, (sum, score) => sum + (score as int));
            return DataCell(Text(scoreSum.toString()));
          }),
          DataCell(Text(averageScore)),
        ],
      );
    }).toList();
  }
}
