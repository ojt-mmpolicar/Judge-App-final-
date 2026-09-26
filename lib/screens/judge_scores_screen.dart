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
  static const indigo = _ScorePalette.primary;
  static const softBlue = _ScorePalette.muted;
  static const coral = _ScorePalette.danger;
  static const offWhite = _ScorePalette.background;
  static const charcoalGray = _ScorePalette.ink;

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
        title: Text(
          selectedEvent == null ? 'Judge scores' : 'Event results',
          style: TextStyle(
            color: _ScorePalette.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFF),
        foregroundColor: _ScorePalette.ink,
        surfaceTintColor: const Color(0xFFF8FAFF),
        toolbarHeight: 66,
        titleSpacing: 0,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _ScorePalette.border),
        ),
      ),
      backgroundColor: offWhite,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _ScoreBackgroundOrb(size: 420),
          ),
          const Positioned(
            bottom: -220,
            left: -180,
            child: _ScoreBackgroundOrb(size: 480),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pagePadding = constraints.maxWidth < 700 ? 16.0 : 26.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding,
                    24,
                    pagePadding,
                    34,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: selectedEvent == null
                          ? _buildEventListUI(
                              indigo,
                              softBlue,
                              coral,
                              charcoalGray,
                            )
                          : _buildEventScoresUI(
                              indigo,
                              softBlue,
                              coral,
                              charcoalGray,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: selectedEvent != null
          ? FloatingActionButton.extended(
              onPressed: () => _printEventScores(
                  selectedEvent!, eventScores[selectedEvent!]!),
              backgroundColor: _ScorePalette.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.print_rounded),
              label: const Text('Print Results'),
              tooltip: 'Print Scores',
            )
          : null,
    );
  }

  Widget _buildEventListUI(
      Color indigo, Color softBlue, Color coral, Color charcoalGray) {
    final eventNames = eventScores.keys.toList()
      ..sort((first, second) => first.toLowerCase().compareTo(
            second.toLowerCase(),
          ));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Judge Scores',
            style: TextStyle(
              color: _ScorePalette.ink,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'View and manage scoring events.',
            style: TextStyle(
              color: _ScorePalette.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: SizedBox(
                width: double.infinity,
                child: _ScorePanel(
                  child: eventNames.isEmpty
                      ? const _EmptyScoresState()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 900) {
                              return Column(
                                children: eventNames.map((eventName) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildEventMobileCard(eventName),
                                  );
                                }).toList(),
                              );
                            }

                            return _buildEventTable(eventNames);
                          },
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTable(List<String> eventNames) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _ScorePalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFFF0F1FF),
            child: const Row(
              children: [
                Expanded(flex: 5, child: _EventHeaderText('EVENT NAME')),
                Expanded(flex: 2, child: _EventHeaderText('CONTESTANTS')),
                Expanded(flex: 2, child: _EventHeaderText('JUDGES')),
                Expanded(flex: 2, child: _EventHeaderText('STATUS')),
                SizedBox(
                  width: 150,
                  child: _EventHeaderText('ACTIONS', centered: true),
                ),
              ],
            ),
          ),
          for (final eventName in eventNames) _buildEventTableRow(eventName),
        ],
      ),
    );
  }

  Widget _buildEventTableRow(String eventName) {
    final contestantCount = _getContestantList(eventName).length;
    final judgeCount = _getJudgeList(eventName).length;

    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _ScorePalette.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFF1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: _ScorePalette.danger,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eventName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ScorePalette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _CountLabel(
              icon: Icons.groups_2_rounded,
              count: contestantCount,
            ),
          ),
          Expanded(
            flex: 2,
            child: _CountLabel(
              icon: Icons.person_rounded,
              count: judgeCount,
            ),
          ),
          const Expanded(flex: 2, child: _ScoresAvailableBadge()),
          SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => selectedEvent = eventName),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('View Scores'),
                ),
                IconButton(
                  tooltip: 'Delete event',
                  onPressed: () => _confirmDeleteEvent(eventName),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: _ScorePalette.danger,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMobileCard(String eventName) {
    final contestantCount = _getContestantList(eventName).length;
    final judgeCount = _getJudgeList(eventName).length;

    return Material(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => selectedEvent = eventName),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _ScorePalette.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _ScorePalette.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName,
                      style: const TextStyle(
                        color: _ScorePalette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$contestantCount contestants  •  $judgeCount judges',
                      style: const TextStyle(
                        color: _ScorePalette.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _ScoresAvailableBadge(),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete event',
                onPressed: () => _confirmDeleteEvent(eventName),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _ScorePalette.danger,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _ScorePalette.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEvent(String eventName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _ScorePalette.danger),
            SizedBox(width: 10),
            Text('Delete Event'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$eventName"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _ScorePalette.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _database.child('scores/$eventName').remove();
      await _database.child('events/$eventName').remove();
      if (!mounted) return;
      setState(() => eventScores.remove(eventName));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "$eventName" deleted')),
      );
    }
  }

  Widget _buildEventScoresUI(
      Color indigo, Color softBlue, Color coral, Color charcoalGray) {
    final contestantCount = _getContestantList(selectedEvent!).length;
    final judgeCount = _getJudgeList(selectedEvent!).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: _ScorePalette.primary,
                ),
                onPressed: () => setState(() => selectedEvent = null),
                tooltip: 'Back to Events',
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scores for $selectedEvent',
                      style: const TextStyle(
                        color: _ScorePalette.ink,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Event results and ranking overview.',
                      style: TextStyle(
                        color: _ScorePalette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ScorePanel(
            child: Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                _ResultMetric(
                  icon: Icons.groups_2_rounded,
                  label: 'Total Candidates',
                  value: '$contestantCount',
                ),
                _ResultMetric(
                  icon: Icons.person_rounded,
                  label: 'Judges',
                  value: '$judgeCount',
                ),
                const _ResultMetric(
                  icon: Icons.check_circle_rounded,
                  label: 'Status',
                  value: 'Scores available',
                  isSuccess: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildColoredTable(
            columns: _buildTableColumns(selectedEvent!),
            rows: _buildTableRows(selectedEvent!),
            title: 'Main Scores Table',
            subtitle: 'Scores given by each judge, with totals and ranking.',
            icon: Icons.emoji_events_rounded,
            indigo: indigo,
            softBlue: softBlue,
            coral: coral,
            charcoalGray: charcoalGray,
          ),
          const SizedBox(height: 18),
          _buildColoredTable(
            columns: _buildJudgeTableColumns(selectedEvent!),
            rows: _buildJudgeRankingRows(selectedEvent!),
            title: 'Judges\' Rankings Table',
            subtitle:
                'Rankings from each judge, with totals, averages, and final rank.',
            icon: Icons.bar_chart_rounded,
            indigo: indigo,
            softBlue: softBlue,
            coral: coral,
            charcoalGray: charcoalGray,
          ),
          const SizedBox(height: 74),
        ],
      ),
    );
  }

  Widget _buildColoredTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color indigo,
    required Color softBlue,
    required Color coral,
    required Color charcoalGray,
  }) {
    return _ScorePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: indigo, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: charcoalGray,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: softBlue,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _ScorePalette.border),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 800),
                  child: DataTable(
                    columnSpacing: 38,
                    dataRowMinHeight: 54,
                    dataRowMaxHeight: 66,
                    headingRowHeight: 48,
                    columns: columns,
                    rows: rows,
                    headingRowColor: WidgetStatePropertyAll(
                      indigo.withValues(alpha: 0.08),
                    ),
                    dataRowColor: const WidgetStatePropertyAll(Colors.white),
                    headingTextStyle: TextStyle(
                      color: charcoalGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    dataTextStyle: TextStyle(
                      color: charcoalGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    border: const TableBorder(
                      horizontalInside: BorderSide(
                        color: _ScorePalette.border,
                      ),
                      verticalInside: BorderSide(
                        color: _ScorePalette.border,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
      // Only add keys that are in the judges list (not contestant names)
      judgeSet.addAll(contestantScores.keys
          .where((k) => allJudgeUsernames.contains(k.toString())));
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
        DataCell(_RankBadge(rank: rank as int)),
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
        DataCell(_RankBadge(rank: row['rank'] as int)),
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
                pw.TableHelper.fromTextArray(
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
                pw.TableHelper.fromTextArray(
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results sent to printer')),
      );
    } catch (e) {
      debugPrint('Error printing scores: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to print scores: $e')),
      );
    }
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143034A8),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EventHeaderText extends StatelessWidget {
  const _EventHeaderText(this.text, {this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: _ScorePalette.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _ScorePalette.primaryLight, size: 18),
        const SizedBox(width: 7),
        Text(
          '$count',
          style: const TextStyle(
            color: _ScorePalette.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScoresAvailableBadge extends StatelessWidget {
  const _ScoresAvailableBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F8EE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: _ScorePalette.success, size: 7),
            SizedBox(width: 6),
            Text(
              'Scores available',
              style: TextStyle(
                color: Color(0xFF128848),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.isSuccess = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final accent = isSuccess ? _ScorePalette.success : _ScorePalette.primary;

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ScorePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isSuccess ? const Color(0xFFE7F8EE) : const Color(0xFFF0F1FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _ScorePalette.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: isSuccess ? accent : _ScorePalette.ink,
                  fontSize: 14,
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

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (rank) {
      1 => (const Color(0xFFFFE8A3), const Color(0xFF9A6800)),
      2 => (const Color(0xFFE5EAF2), const Color(0xFF56637A)),
      3 => (const Color(0xFFF6DACB), const Color(0xFF9A5836)),
      _ => (const Color(0xFFF0F1FF), _ScorePalette.primary),
    };

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyScoresState extends StatelessWidget {
  const _EmptyScoresState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 70),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.scoreboard_outlined,
              color: _ScorePalette.primary,
              size: 48,
            ),
            SizedBox(height: 14),
            Text(
              'No scores available',
              style: TextStyle(
                color: _ScorePalette.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Events will appear here after judges submit scores.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ScorePalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBackgroundOrb extends StatelessWidget {
  const _ScoreBackgroundOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x6698A7FF),
      ),
    );
  }
}

class _ScorePalette {
  const _ScorePalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryLight = Color(0xFF4B50D7);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const success = Color(0xFF18A957);
  static const danger = Color(0xFFD92D38);
}
