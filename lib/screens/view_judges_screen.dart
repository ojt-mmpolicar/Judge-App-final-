import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ViewJudgesScreen extends StatefulWidget {
  const ViewJudgesScreen({super.key});

  @override
  State<ViewJudgesScreen> createState() => _ViewJudgesScreenState();
}

class _ViewJudgesScreenState extends State<ViewJudgesScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Map<String, dynamic> _judges = {};
  String? _selectedJudge;
  List<String> _assignedEvents = [];
  bool _loading = true;
  bool _loadingAssignments = false;

  List<MapEntry<String, dynamic>> get _sortedJudges {
    final judges = _judges.entries.toList();
    judges.sort(
      (first, second) => _displayName(first.key, first.value)
          .toLowerCase()
          .compareTo(_displayName(second.key, second.value).toLowerCase()),
    );
    return judges;
  }

  @override
  void initState() {
    super.initState();
    _fetchJudges();
  }

  Future<void> _fetchJudges() async {
    setState(() {
      _loading = true;
      _selectedJudge = null;
      _assignedEvents = [];
    });

    try {
      final snapshot = await _database.child('judges').get();
      if (!mounted) return;

      setState(() {
        _judges = snapshot.exists
            ? Map<String, dynamic>.from(snapshot.value as Map)
            : {};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _judges = {};
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load judges: $error')),
      );
    }
  }

  Future<void> _fetchAssignedEvents(String judgeUsername) async {
    setState(() {
      _selectedJudge = judgeUsername;
      _assignedEvents = [];
      _loadingAssignments = true;
    });

    try {
      final snapshot =
          await _database.child('event_assignments/$judgeUsername').get();
      final events = <String>[];

      if (snapshot.exists && snapshot.value is Map) {
        final value = snapshot.value as Map;
        value.forEach((eventKey, eventValue) {
          if (eventValue is Map && eventValue.containsKey('eventName')) {
            events.add(eventValue['eventName'].toString());
          }
        });
      }
      events.sort(
        (first, second) => first.toLowerCase().compareTo(second.toLowerCase()),
      );

      if (!mounted || _selectedJudge != judgeUsername) return;
      setState(() {
        _assignedEvents = events;
        _loadingAssignments = false;
      });
    } catch (error) {
      if (!mounted || _selectedJudge != judgeUsername) return;
      setState(() => _loadingAssignments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load assigned events: $error')),
      );
    }
  }

  Future<void> _deleteAssignedEvent(
    String judgeUsername,
    String eventName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove event assignment?',
          style: TextStyle(
            color: _ViewJudgesPalette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Remove "$eventName" from this judge? The event itself will not be deleted.',
          style: const TextStyle(color: _ViewJudgesPalette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _ViewJudgesPalette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _database
          .child('event_assignments/$judgeUsername/$eventName')
          .remove();
      if (!mounted) return;
      setState(() => _assignedEvents.remove(eventName));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "$eventName" removed from judge.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove event: $error')),
      );
    }
  }

  String _displayName(String username, dynamic data) {
    if (data is Map && data['username'] != null) {
      return data['username'].toString();
    }
    return username;
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  bool _isActiveJudge(dynamic data) {
    if (data is Map && data.containsKey('active')) {
      return data['active'] != false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ViewJudgesPalette.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFF),
        foregroundColor: _ViewJudgesPalette.ink,
        surfaceTintColor: const Color(0xFFF8FAFF),
        toolbarHeight: 66,
        titleSpacing: 0,
        elevation: 0,
        title: const Text(
          'View judges',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh judges',
              onPressed: _fetchJudges,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _ViewJudgesPalette.border),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _ViewJudgesBackgroundOrb(size: 420),
          ),
          const Positioned(
            bottom: -220,
            left: -180,
            child: _ViewJudgesBackgroundOrb(size: 480),
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
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'View Judges',
                            style: TextStyle(
                              color: _ViewJudgesPalette.ink,
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Manage judges and review their assigned events.',
                            style: TextStyle(
                              color: _ViewJudgesPalette.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, contentConstraints) {
                              if (contentConstraints.maxWidth < 860) {
                                return Column(
                                  children: [
                                    SizedBox(
                                      height: 420,
                                      child: _buildJudgesPanel(),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildDetailsPanel(
                                      fillAvailableHeight: false,
                                    ),
                                  ],
                                );
                              }

                              return SizedBox(
                                height: 660,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 350,
                                      child: _buildJudgesPanel(),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: _buildDetailsPanel(
                                        fillAvailableHeight: true,
                                      ),
                                    ),
                                  ],
                                ),
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
      ),
    );
  }

  Widget _buildJudgesPanel() {
    return _ViewJudgesPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Judges',
                  style: TextStyle(
                    color: _ViewJudgesPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_judges.length}',
                  style: const TextStyle(
                    color: _ViewJudgesPalette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a judge to view assignments.',
            style: TextStyle(
              color: _ViewJudgesPalette.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _ViewJudgesPalette.border),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sortedJudges.isEmpty
                    ? const _NoJudgesState()
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _sortedJudges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, index) {
                          final entry = _sortedJudges[index];
                          final username = entry.key;
                          final name = _displayName(username, entry.value);

                          return _JudgeListTile(
                            username: username,
                            displayName: name,
                            initials: _initials(name),
                            selected: _selectedJudge == username,
                            onTap: () => _fetchAssignedEvents(username),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel({required bool fillAvailableHeight}) {
    final selectedJudge = _selectedJudge;

    if (selectedJudge == null) {
      return _ViewJudgesPanel(
        child: SizedBox(
          height: fillAvailableHeight ? double.infinity : 260,
          child: const _SelectJudgeState(),
        ),
      );
    }

    final judgeData = _judges[selectedJudge];
    final name = _displayName(selectedJudge, judgeData);
    final active = _isActiveJudge(judgeData);

    Widget eventsContent;
    if (_loadingAssignments) {
      eventsContent = const Padding(
        padding: EdgeInsets.symmetric(vertical: 62),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_assignedEvents.isEmpty) {
      eventsContent = const _NoAssignedEventsState();
    } else if (fillAvailableHeight) {
      eventsContent = Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 2),
          itemCount: _assignedEvents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildEventTile(
            selectedJudge,
            _assignedEvents[index],
          ),
        ),
      );
    } else {
      eventsContent = Column(
        children: _assignedEvents
            .map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildEventTile(selectedJudge, event),
              ),
            )
            .toList(),
      );
    }

    return _ViewJudgesPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final identity = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _JudgeAvatar(
                    initials: _initials(name),
                    size: 68,
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ViewJudgesPalette.ink,
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              color: _ViewJudgesPalette.muted,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                selectedJudge,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ViewJudgesPalette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _StatusBadge(active: active),
                      ],
                    ),
                  ),
                ],
              );

              final refreshButton = OutlinedButton.icon(
                onPressed: _loadingAssignments
                    ? null
                    : () => _fetchAssignedEvents(selectedJudge),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ViewJudgesPalette.primary,
                  side: const BorderSide(color: _ViewJudgesPalette.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              );

              if (constraints.maxWidth < 540) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: refreshButton),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  refreshButton,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _AssignedEventsMetric(count: _assignedEvents.length),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _ViewJudgesPalette.border),
          const SizedBox(height: 17),
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: _ViewJudgesPalette.primaryLight,
                size: 23,
              ),
              SizedBox(width: 10),
              Text(
                'Assigned Events',
                style: TextStyle(
                  color: _ViewJudgesPalette.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          eventsContent,
        ],
      ),
    );
  }

  Widget _buildEventTile(String judgeUsername, String eventName) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ViewJudgesPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: _ViewJudgesPalette.danger,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              eventName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ViewJudgesPalette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove event assignment',
            onPressed: () => _deleteAssignedEvent(judgeUsername, eventName),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFECEF),
              foregroundColor: _ViewJudgesPalette.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ViewJudgesPanel extends StatelessWidget {
  const _ViewJudgesPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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

class _JudgeListTile extends StatelessWidget {
  const _JudgeListTile({
    required this.username,
    required this.displayName,
    required this.initials,
    required this.selected,
    required this.onTap,
  });

  final String username;
  final String displayName;
  final String initials;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F1FF) : const Color(0xFFFCFCFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? _ViewJudgesPalette.primaryLight
              : _ViewJudgesPalette.border,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              _JudgeAvatar(initials: initials, size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ViewJudgesPalette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ViewJudgesPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? _ViewJudgesPalette.primary
                    : _ViewJudgesPalette.muted,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JudgeAvatar extends StatelessWidget {
  const _JudgeAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8EAFF), Color(0xFFCDD3FF)],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: _ViewJudgesPalette.primary,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? _ViewJudgesPalette.success : _ViewJudgesPalette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedEventsMetric extends StatelessWidget {
  const _AssignedEventsMetric({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ViewJudgesPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: _ViewJudgesPalette.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned events',
                style: TextStyle(
                  color: _ViewJudgesPalette.muted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: const TextStyle(
                  color: _ViewJudgesPalette.primary,
                  fontSize: 18,
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

class _SelectJudgeState extends StatelessWidget {
  const _SelectJudgeState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SelectJudgeIcon(),
          SizedBox(height: 16),
          Text(
            'Select a judge',
            style: TextStyle(
              color: _ViewJudgesPalette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Choose a judge from the list to review assigned events.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ViewJudgesPalette.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectJudgeIcon extends StatelessWidget {
  const _SelectJudgeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.manage_accounts_rounded,
        color: _ViewJudgesPalette.primary,
        size: 34,
      ),
    );
  }
}

class _NoJudgesState extends StatelessWidget {
  const _NoJudgesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No judge accounts found.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _ViewJudgesPalette.muted,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NoAssignedEventsState extends StatelessWidget {
  const _NoAssignedEventsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ViewJudgesPalette.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: _ViewJudgesPalette.muted,
            size: 30,
          ),
          SizedBox(height: 10),
          Text(
            'No events assigned',
            style: TextStyle(
              color: _ViewJudgesPalette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'This judge does not have any event assignments yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ViewJudgesPalette.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewJudgesBackgroundOrb extends StatelessWidget {
  const _ViewJudgesBackgroundOrb({required this.size});

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

class _ViewJudgesPalette {
  const _ViewJudgesPalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryLight = Color(0xFF4B50D7);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const danger = Color(0xFFD92D38);
  static const success = Color(0xFF0FA958);
}
