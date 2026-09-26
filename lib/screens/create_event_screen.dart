import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

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
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<Map<String, String>> _criteriaList = [];
  List<String> _judgeList = [];
  String? _selectedJudge;
  final List<String> _contestantList = [];

  @override
  void initState() {
    super.initState();
    _fetchJudges();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _criteriaTitleController.dispose();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    _contestantNameController.dispose();
    super.dispose();
  }

  void _fetchJudges() async {
    try {
      final snapshot = await _database.child('judges').get();
      if (!mounted) return;

      if (snapshot.exists) {
        final judgesData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _judgeList = judgesData.keys.map((key) => key.toString()).toList();
        });
      } else {
        debugPrint('No judges found in the database.');
      }
    } catch (error) {
      debugPrint('Error fetching judges: $error');
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
              .map(
                (criterion) => {
                  'title': criterion['title'] ?? '',
                  'minScore': int.parse(criterion['minScore'] ?? '0'),
                  'maxScore': int.parse(criterion['maxScore'] ?? '0'),
                },
              )
              .toList(),
        };

        final eventRef = _database.child('events/$eventName');
        await eventRef.set(eventData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        setState(() {
          _eventNameController.clear();
          _criteriaList = [];
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $error')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields and add criteria'),
        ),
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

  Future<void> _editCriteria(int index) async {
    final criterion = _criteriaList[index];
    final titleController = TextEditingController(text: criterion['title']);
    final minController = TextEditingController(text: criterion['minScore']);
    final maxController = TextEditingController(text: criterion['maxScore']);

    final edited = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Edit Criteria',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: _inputDecoration('Criteria Title'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Minimum Score'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Maximum Score'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _CreateEventPalette.primary,
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  minController.text.isNotEmpty &&
                  maxController.text.isNotEmpty) {
                Navigator.of(dialogContext).pop({
                  'title': titleController.text,
                  'minScore': minController.text,
                  'maxScore': maxController.text,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    titleController.dispose();
    minController.dispose();
    maxController.dispose();

    if (edited != null && mounted) {
      setState(() => _criteriaList[index] = edited);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criteria updated')),
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

        await _database
            .child('events/$eventName/contestants/$contestantName')
            .set({'name': contestantName, 'addedAt': timestamp});

        if (!mounted) return;
        setState(() {
          if (!_contestantList.contains(contestantName)) {
            _contestantList.add(contestantName);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contestant added')),
        );
        _contestantNameController.clear();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add contestant: $error')),
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Edit Contestant',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          decoration: _inputDecoration('Contestant Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _CreateEventPalette.primary,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final eventName = _eventNameController.text.trim();
      await _database.child('events/$eventName/contestants/$oldName').remove();
      await _database.child('events/$eventName/contestants/$newName').set({
        'name': newName,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      setState(() => _contestantList[index] = newName);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contestant updated')),
      );
    }
  }

  void _removeContestant(int index) async {
    final name = _contestantList[index];
    final eventName = _eventNameController.text.trim();
    await _database.child('events/$eventName/contestants/$name').remove();
    if (!mounted) return;
    setState(() => _contestantList.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contestant removed')),
    );
  }

  void _assignJudge() async {
    if (_selectedJudge != null && _eventNameController.text.isNotEmpty) {
      try {
        final judgeUsername = _selectedJudge!;
        final eventName = _eventNameController.text;

        final criteriaSnapshot =
            await _database.child('events/$eventName/criteria').get();
        final criteria = criteriaSnapshot.value;

        await _database
            .child('event_assignments/$judgeUsername/$eventName')
            .update({
          'eventName': eventName,
          'criteria': criteria,
        });

        for (final contestant in _contestantList) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          await _database
              .child(
            'event_assignments/$judgeUsername/$eventName/'
            'contestants/$contestant',
          )
              .set({'name': contestant, 'addedAt': timestamp});
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judge assigned successfully')),
        );
        setState(() => _selectedJudge = null);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign judge: $error')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a judge and fill in the event name'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _CreateEventPalette.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFF),
        foregroundColor: _CreateEventPalette.ink,
        surfaceTintColor: const Color(0xFFF8FAFF),
        toolbarHeight: 66,
        elevation: 0,
        shadowColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text(
          'Event setup',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _CreateEventPalette.border),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _CreateEventBackgroundOrb(size: 420),
          ),
          const Positioned(
            bottom: -220,
            left: -180,
            child: _CreateEventBackgroundOrb(size: 480),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pagePadding = constraints.maxWidth < 700 ? 16.0 : 26.0;

                return SingleChildScrollView(
                  padding:
                      EdgeInsets.fromLTRB(pagePadding, 24, pagePadding, 40),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEventSummary(),
                          const SizedBox(height: 20),
                          if (constraints.maxWidth >= 1050)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildMainForm()),
                                const SizedBox(width: 20),
                                SizedBox(width: 320, child: _buildSidePanel()),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildMainForm(),
                                const SizedBox(height: 20),
                                _buildSidePanel(),
                              ],
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
    );
  }

  Widget _buildEventSummary() {
    final eventName = _eventNameController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F1FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F43528A),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final eventIdentity = Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4B50D7), Color(0xFF3034A8)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x333034A8),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName.isEmpty ? 'New Judging Event' : eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CreateEventPalette.ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EAFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'DRAFT SETUP',
                        style: TextStyle(
                          color: _CreateEventPalette.primaryDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final counters = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryCount(
                icon: Icons.emoji_events_rounded,
                value: _criteriaList.length,
                label: 'Criteria',
              ),
              _SummaryCount(
                icon: Icons.groups_2_rounded,
                value: _contestantList.length,
                label: 'Contestants',
              ),
              _SummaryCount(
                icon: Icons.people_alt_rounded,
                value: _judgeList.length,
                label: 'Judges Available',
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                eventIdentity,
                const SizedBox(height: 18),
                counters,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: eventIdentity),
              const SizedBox(width: 20),
              counters,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      children: [
        _buildEventDetailsSection(),
        const SizedBox(height: 16),
        _buildCriteriaSection(),
        const SizedBox(height: 16),
        _buildContestantsSection(),
        const SizedBox(height: 16),
        _buildJudgeSection(),
      ],
    );
  }

  Widget _buildEventDetailsSection() {
    return _EventPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.description_rounded,
            title: 'Event Details',
            subtitle: 'Give your judging event a clear name.',
          ),
          const SizedBox(height: 18),
          const _FieldLabel(text: 'Event Name', isRequired: true),
          const SizedBox(height: 8),
          TextField(
            controller: _eventNameController,
            onChanged: (_) => setState(() {}),
            decoration: _inputDecoration(
              'Enter event name',
              prefixIcon: Icons.event_note_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaSection() {
    return _EventPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.emoji_events_rounded,
            title: 'Scoring Criteria',
            subtitle: 'Add and manage the scoring criteria for this event.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    TextField(
                      controller: _criteriaTitleController,
                      decoration: _inputDecoration('Criteria title'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minScoreController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Minimum score'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxScoreController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Maximum score'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryButton(
                        label: 'Add Criteria',
                        icon: Icons.add_rounded,
                        onPressed: _addCriteria,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(text: 'Criteria Title'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _criteriaTitleController,
                          decoration: _inputDecoration('Enter criteria title'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(text: 'Minimum Score'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _minScoreController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('0'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(text: 'Maximum Score'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _maxScoreController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('10'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: _PrimaryButton(
                      label: 'Add Criteria',
                      icon: Icons.add_rounded,
                      onPressed: _addCriteria,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (_criteriaList.isEmpty)
            const _InlineEmptyState(
              icon: Icons.rule_rounded,
              text: 'No scoring criteria added yet.',
            )
          else
            Column(
              children: _criteriaList.asMap().entries.map((entry) {
                final index = entry.key;
                final criterion = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _criteriaList.length - 1 ? 0 : 8,
                  ),
                  child: _CriteriaRow(
                    index: index,
                    title: criterion['title'] ?? '',
                    minimum: criterion['minScore'] ?? '0',
                    maximum: criterion['maxScore'] ?? '0',
                    onEdit: () => _editCriteria(index),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildContestantsSection() {
    return _EventPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.groups_2_rounded,
            title: 'Contestants',
            subtitle: 'Add and manage contestants for this event.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                controller: _contestantNameController,
                onSubmitted: (_) => _addContestant(),
                decoration: _inputDecoration(
                  'Enter contestant name',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              );
              final button = _PrimaryButton(
                label: 'Add Contestant',
                icon: Icons.add_rounded,
                onPressed: _addContestant,
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    field,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: button),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  SizedBox(width: 170, child: button),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter the event name before adding contestants.',
            style: TextStyle(
              color: _CreateEventPalette.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          if (_contestantList.isEmpty)
            const _InlineEmptyState(
              icon: Icons.person_search_rounded,
              text: 'No contestants added yet.',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _contestantList.asMap().entries.map((entry) {
                return _ContestantChip(
                  number: entry.key + 1,
                  name: entry.value,
                  onEdit: () => _editContestant(entry.key),
                  onDelete: () => _removeContestant(entry.key),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildJudgeSection() {
    return _EventPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.people_alt_rounded,
            title: 'Assign Judge',
            subtitle: 'Choose a registered judge to evaluate this event.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final dropdown = DropdownButtonFormField<String>(
                initialValue: _selectedJudge,
                isExpanded: true,
                hint: const Text('Select a judge'),
                decoration: _inputDecoration(
                  'Select a judge',
                  prefixIcon: Icons.person_search_rounded,
                ),
                items: _judgeList
                    .map(
                      (judge) => DropdownMenuItem<String>(
                        value: judge,
                        child: Text(judge),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedJudge = value),
              );
              final button = _PrimaryButton(
                label: 'Assign Judge',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: _assignJudge,
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    dropdown,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: button),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: dropdown),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: button),
                ],
              );
            },
          ),
          if (_judgeList.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'No judge accounts are currently available.',
              style: TextStyle(
                color: _CreateEventPalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    final hasName = _eventNameController.text.trim().isNotEmpty;
    final hasCriteria = _criteriaList.isNotEmpty;
    final hasContestants = _contestantList.isNotEmpty;
    final completedSteps = [hasName, hasCriteria, hasContestants]
        .where((completed) => completed)
        .length;
    final progress = completedSteps / 3;

    return Column(
      children: [
        _EventPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                icon: Icons.verified_rounded,
                title: 'Event Readiness',
                subtitle: 'Track your event setup progress.',
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 106,
                  height: 106,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        backgroundColor: const Color(0xFFE8EDF5),
                        color: progress == 1
                            ? _CreateEventPalette.success
                            : _CreateEventPalette.primary,
                      ),
                      Center(
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            color: _CreateEventPalette.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ReadinessRow(label: 'Event name entered', complete: hasName),
              const SizedBox(height: 11),
              _ReadinessRow(
                label: 'Scoring criteria added',
                complete: hasCriteria,
              ),
              const SizedBox(height: 11),
              _ReadinessRow(
                label: 'Contestants added',
                complete: hasContestants,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _EventPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                icon: Icons.bolt_rounded,
                title: 'Quick Actions',
                subtitle: 'Finish or leave this event setup.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Create Event',
                  icon: Icons.save_rounded,
                  onPressed: _createEvent,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _CreateEventPalette.danger,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(
                      color: Color(0x33D92D38),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static InputDecoration _inputDecoration(
    String hint, {
    IconData? prefixIcon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF8995AC),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: _CreateEventPalette.muted, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: border(_CreateEventPalette.border, 1),
      enabledBorder: border(_CreateEventPalette.border, 1),
      focusedBorder: border(_CreateEventPalette.primary, 1.7),
    );
  }
}

class _EventPanel extends StatelessWidget {
  const _EventPanel({required this.child});

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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF2F2FF), Color(0xFFE7E8FF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _CreateEventPalette.primary, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _CreateEventPalette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _CreateEventPalette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: _CreateEventPalette.danger),
            ),
        ],
      ),
      style: const TextStyle(
        color: _CreateEventPalette.ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 115),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3D46A8),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _CreateEventPalette.primary, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: _CreateEventPalette.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: _CreateEventPalette.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B50D7), Color(0xFF3034A8)],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x293034A8),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({
    required this.index,
    required this.title,
    required this.minimum,
    required this.maximum,
    required this.onEdit,
  });

  final int index;
  final String title;
  final String minimum;
  final String maximum;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _CreateEventPalette.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFECEEFF),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: _CreateEventPalette.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _CreateEventPalette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _ScoreBadge(label: 'Min: $minimum'),
          const SizedBox(width: 8),
          _ScoreBadge(label: 'Max: $maximum'),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Edit criteria',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: _CreateEventPalette.muted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _CreateEventPalette.muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ContestantChip extends StatelessWidget {
  const _ContestantChip({
    required this.number,
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  final int number;
  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.fromLTRB(9, 6, 5, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _CreateEventPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFFECEEFF),
            child: Text(
              '$number',
              style: const TextStyle(
                color: _CreateEventPalette.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _CreateEventPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit contestant',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: _CreateEventPalette.muted,
              size: 18,
            ),
          ),
          IconButton(
            tooltip: 'Remove contestant',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(
              Icons.close_rounded,
              color: _CreateEventPalette.danger,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _CreateEventPalette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _CreateEventPalette.muted, size: 20),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: _CreateEventPalette.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          complete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color:
              complete ? _CreateEventPalette.success : const Color(0xFFB4BFCE),
          size: 19,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: complete
                  ? _CreateEventPalette.ink
                  : _CreateEventPalette.muted,
              fontSize: 12,
              fontWeight: complete ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateEventBackgroundOrb extends StatelessWidget {
  const _CreateEventBackgroundOrb({required this.size});

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

class _CreateEventPalette {
  const _CreateEventPalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryDark = Color(0xFF232B6B);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const success = Color(0xFF19A95B);
  static const danger = Color(0xFFD92D38);
}
