import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'create_event_screen.dart';
import 'create_judge_screen.dart';
import 'judge_scores_screen.dart';
import 'view_judges_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  final Map<String, Map<dynamic, dynamic>> _liveData = {
    'events': <dynamic, dynamic>{},
    'judges': <dynamic, dynamic>{},
    'event_assignments': <dynamic, dynamic>{},
    'scores': <dynamic, dynamic>{},
  };
  final Set<String> _loadedPaths = <String>{};
  final List<StreamSubscription<DatabaseEvent>> _subscriptions = [];

  Object? _dashboardError;

  @override
  void initState() {
    super.initState();
    _startRealtimeDashboard();
  }

  void _startRealtimeDashboard() {
    for (final path in _liveData.keys) {
      final subscription = _database.child(path).onValue.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _liveData[path] = _mapFrom(event.snapshot.value);
            _loadedPaths.add(path);
            _dashboardError = null;
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _dashboardError = error);
        },
      );
      _subscriptions.add(subscription);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  _DashboardData _buildDashboardData() {
    final eventsData = _liveData['events']!;
    final judgesData = _liveData['judges']!;
    final assignmentsData = _liveData['event_assignments']!;
    final scoresData = _liveData['scores']!;

    final events = <_EventOverview>[];
    var totalContestants = 0;
    var eventsWithScores = 0;

    for (final entry in eventsData.entries) {
      final eventName = entry.key.toString();
      final eventDetails = _mapFrom(entry.value);
      final contestantNames = _mapFrom(eventDetails['contestants'])
          .keys
          .map((key) => key.toString())
          .toSet();
      var assignedJudges = 0;

      for (final judgeAssignments in assignmentsData.values) {
        final judgeEvents = _mapFrom(judgeAssignments);
        if (judgeEvents.containsKey(eventName)) {
          assignedJudges++;
          final assignedEvent = _mapFrom(judgeEvents[eventName]);
          contestantNames.addAll(
            _mapFrom(assignedEvent['contestants'])
                .keys
                .map((key) => key.toString()),
          );
        }
      }

      final eventScores = _mapFrom(scoresData[eventName]);
      contestantNames.addAll(eventScores.keys.map((key) => key.toString()));

      final contestants = contestantNames.length;
      final hasScores = eventScores.isNotEmpty;
      if (hasScores) eventsWithScores++;
      totalContestants += contestants;

      events.add(
        _EventOverview(
          name: eventName,
          contestantCount: contestants,
          judgeCount: assignedJudges,
          hasScores: hasScores,
        ),
      );
    }

    events.sort(
      (first, second) => first.name.toLowerCase().compareTo(
            second.name.toLowerCase(),
          ),
    );

    return _DashboardData(
      totalEvents: eventsData.length,
      totalJudges: judgesData.length,
      totalContestants: totalContestants,
      eventsWithScores: eventsWithScores,
      events: events,
    );
  }

  static Map<dynamic, dynamic> _mapFrom(Object? value) {
    if (value is Map) return Map<dynamic, dynamic>.from(value);
    return <dynamic, dynamic>{};
  }

  Future<void> _refreshDashboard() async {
    try {
      final paths = _liveData.keys.toList();
      final snapshots = await Future.wait(
        paths.map((path) => _database.child(path).get()),
      );
      if (!mounted) return;

      setState(() {
        for (var index = 0; index < paths.length; index++) {
          _liveData[paths[index]] = _mapFrom(snapshots[index].value);
          _loadedPaths.add(paths[index]);
        }
        _dashboardError = null;
      });
    } catch (error) {
      if (mounted) setState(() => _dashboardError = error);
    }
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _showExitConfirmationDialog() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: _AdminPalette.danger),
            SizedBox(width: 12),
            Text('Log Out'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _AdminPalette.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogOut == true && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }

  void _closeDrawerIfNeeded(bool isDrawer) {
    if (isDrawer) Navigator.of(context).pop();
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return _AdminSidebar(
      onHome: () => _closeDrawerIfNeeded(isDrawer),
      onCreateEvent: () {
        _closeDrawerIfNeeded(isDrawer);
        _openPage(const CreateEventScreen());
      },
      onCreateJudge: () {
        _closeDrawerIfNeeded(isDrawer);
        _openPage(const CreateJudgeScreen());
      },
      onJudgeScores: () {
        _closeDrawerIfNeeded(isDrawer);
        _openPage(const JudgeScoresScreen());
      },
      onViewJudges: () {
        _closeDrawerIfNeeded(isDrawer);
        _openPage(const ViewJudgesScreen());
      },
      onLogout: () {
        _closeDrawerIfNeeded(isDrawer);
        _showExitConfirmationDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _AdminPalette.background,
      drawer: isDesktop
          ? null
          : Drawer(
              width: 280,
              child: _buildSidebar(isDrawer: true),
            ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _AdminBackgroundOrb(size: 430),
          ),
          const Positioned(
            bottom: -220,
            left: 90,
            child: _AdminBackgroundOrb(size: 470),
          ),
          Positioned.fill(
            child: Row(
              children: [
                if (isDesktop) _buildSidebar(isDrawer: false),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        _AdminTopBar(
                          showMenuButton: !isDesktop,
                          onMenuPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refreshDashboard,
                            child: _buildDashboard(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final isLoading = _loadedPaths.length < _liveData.length;
    final data = _buildDashboardData();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 700 ? 20.0 : 28.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            26,
            horizontalPadding,
            36,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 24),
                  if (_dashboardError != null) ...[
                    _DashboardErrorBanner(onRetry: _refreshDashboard),
                    const SizedBox(height: 18),
                  ],
                  _StatsGrid(data: data, isLoading: isLoading),
                  const SizedBox(height: 24),
                  if (constraints.maxWidth >= 1080)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _EventsPanel(
                            events: data.events,
                            isLoading: isLoading,
                            onViewScores: () =>
                                _openPage(const JudgeScoresScreen()),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 330,
                          child: _buildActionColumn(),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildActionColumn(),
                        const SizedBox(height: 20),
                        _EventsPanel(
                          events: data.events,
                          isLoading: isLoading,
                          onViewScores: () =>
                              _openPage(const JudgeScoresScreen()),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, Admin!',
                style: TextStyle(
                  color: _AdminPalette.ink,
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage your events, judges, and scoring all in one place.',
                style: TextStyle(
                  color: _AdminPalette.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Refresh dashboard',
          onPressed: _refreshDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildActionColumn() {
    return Column(
      children: [
        _QuickActionsPanel(
          onCreateEvent: () => _openPage(const CreateEventScreen()),
          onCreateJudge: () => _openPage(const CreateJudgeScreen()),
          onViewJudges: () => _openPage(const ViewJudgesScreen()),
          onJudgeScores: () => _openPage(const JudgeScoresScreen()),
        ),
        const SizedBox(height: 20),
        const _SystemInfoPanel(),
      ],
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: _AdminPalette.border),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              tooltip: 'Open menu',
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: _AdminPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin',
                style: TextStyle(
                  color: _AdminPalette.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Administrator',
                style: TextStyle(
                  color: _AdminPalette.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.onHome,
    required this.onCreateEvent,
    required this.onCreateJudge,
    required this.onJudgeScores,
    required this.onViewJudges,
    required this.onLogout,
  });

  final VoidCallback onHome;
  final VoidCallback onCreateEvent;
  final VoidCallback onCreateJudge;
  final VoidCallback onJudgeScores;
  final VoidCallback onViewJudges;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232B6B), Color(0xFF10183E)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _AppMark(),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Judging App',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Admin',
                            style: TextStyle(
                              color: Color(0xFFD4D7F2),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _SidebarItem(
                label: 'Home',
                icon: Icons.home_rounded,
                isSelected: true,
                onTap: onHome,
              ),
              const SizedBox(height: 6),
              _SidebarItem(
                label: 'Create Event',
                icon: Icons.event_note_rounded,
                onTap: onCreateEvent,
              ),
              const SizedBox(height: 6),
              _SidebarItem(
                label: 'Create Judge Account',
                icon: Icons.person_add_alt_1_rounded,
                onTap: onCreateJudge,
              ),
              const SizedBox(height: 6),
              _SidebarItem(
                label: 'Judge Scores',
                icon: Icons.analytics_rounded,
                onTap: onJudgeScores,
              ),
              const SizedBox(height: 6),
              _SidebarItem(
                label: 'View Judges',
                icon: Icons.groups_rounded,
                onTap: onViewJudges,
              ),
              const Spacer(),
              const Divider(color: Color(0xFF3D467B), height: 28),
              _SidebarItem(
                label: 'Log Out',
                icon: Icons.logout_rounded,
                foregroundColor: const Color(0xFFFF7B85),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        color: _AdminPalette.primary,
        size: 29,
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF4B50D7), Color(0xFF3034A8)],
              )
            : null,
        borderRadius: BorderRadius.circular(13),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0x263034A8),
                  blurRadius: 14,
                  offset: Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data, required this.isLoading});

  final _DashboardData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        const spacing = 16.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _StatCard(
              width: width,
              label: 'Total Events',
              value: data.totalEvents,
              icon: Icons.event_rounded,
              accent: _AdminPalette.primary,
              iconBackground: const Color(0xFFF0F1FF),
              helper: 'Available events',
              isLoading: isLoading,
            ),
            _StatCard(
              width: width,
              label: 'Total Judges',
              value: data.totalJudges,
              icon: Icons.people_alt_rounded,
              accent: _AdminPalette.primaryLight,
              iconBackground: const Color(0xFFF0F1FF),
              helper: 'Registered accounts',
              isLoading: isLoading,
            ),
            _StatCard(
              width: width,
              label: 'Total Contestants',
              value: data.totalContestants,
              icon: Icons.groups_2_rounded,
              accent: _AdminPalette.primaryLight,
              iconBackground: const Color(0xFFF0F1FF),
              helper: 'Across all events',
              isLoading: isLoading,
            ),
            _StatCard(
              width: width,
              label: 'Events With Scores',
              value: data.eventsWithScores,
              icon: Icons.check_circle_rounded,
              accent: _AdminPalette.success,
              iconBackground: const Color(0xFFE8F9EF),
              helper: 'Ready for review',
              isLoading: isLoading,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.helper,
    required this.isLoading,
  });

  final double width;
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final String helper;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(22),
      decoration: _AdminPalette.panelDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent, size: 29),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _AdminPalette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isLoading ? '—' : '$value',
                  style: const TextStyle(
                    color: _AdminPalette.ink,
                    fontSize: 28,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  helper,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.events,
    required this.isLoading,
    required this.onViewScores,
  });

  final List<_EventOverview> events;
  final bool isLoading;
  final VoidCallback onViewScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _AdminPalette.panelDecoration,
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
                      'Current Events',
                      style: TextStyle(
                        color: _AdminPalette.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Events and participation currently in your system.',
                      style: TextStyle(
                        color: _AdminPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewScores,
                child: const Text('View Scores'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (events.isEmpty)
            const _EmptyEventsState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 680) {
                  return Column(
                    children: events
                        .take(6)
                        .map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EventMobileCard(
                              event: event,
                              onViewScores: onViewScores,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return _EventsTable(
                  events: events.take(6).toList(),
                  onViewScores: onViewScores,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EventsTable extends StatelessWidget {
  const _EventsTable({required this.events, required this.onViewScores});

  final List<_EventOverview> events;
  final VoidCallback onViewScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _AdminPalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _EventTableRow(isHeader: true),
          for (final event in events)
            _EventTableRow(event: event, onViewScores: onViewScores),
        ],
      ),
    );
  }
}

class _EventTableRow extends StatelessWidget {
  const _EventTableRow({
    this.event,
    this.onViewScores,
    this.isHeader = false,
  });

  final _EventOverview? event;
  final VoidCallback? onViewScores;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: isHeader ? _AdminPalette.muted : _AdminPalette.ink,
      fontSize: isHeader ? 12 : 13,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
    );

    return Container(
      constraints: BoxConstraints(minHeight: isHeader ? 45 : 58),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFFF4F5FF) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: _AdminPalette.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              isHeader ? 'Event Name' : event!.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isHeader ? 'Contestants' : '${event!.contestantCount}',
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isHeader ? 'Judges' : '${event!.judgeCount}',
              style: textStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: isHeader
                ? Text('Status', style: textStyle)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(hasScores: event!.hasScores),
                  ),
          ),
          SizedBox(
            width: 52,
            child: isHeader
                ? Text('View', style: textStyle)
                : IconButton(
                    tooltip: 'View scores',
                    onPressed: onViewScores,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventMobileCard extends StatelessWidget {
  const _EventMobileCard({required this.event, required this.onViewScores});

  final _EventOverview event;
  final VoidCallback onViewScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AdminPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.event_rounded,
              color: _AdminPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    color: _AdminPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${event.contestantCount} contestants  •  '
                  '${event.judgeCount} judges',
                  style: const TextStyle(
                    color: _AdminPalette.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusChip(hasScores: event.hasScores),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View scores',
            onPressed: onViewScores,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.hasScores});

  final bool hasScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasScores ? const Color(0xFFE5F8ED) : const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hasScores ? 'Scores available' : 'Ready',
        style: TextStyle(
          color: hasScores ? const Color(0xFF128848) : const Color(0xFF44627A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  const _EmptyEventsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 54),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              color: _AdminPalette.muted,
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'No events created yet',
              style: TextStyle(
                color: _AdminPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create your first event from Quick Actions.',
              style: TextStyle(color: _AdminPalette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({
    required this.onCreateEvent,
    required this.onCreateJudge,
    required this.onViewJudges,
    required this.onJudgeScores,
  });

  final VoidCallback onCreateEvent;
  final VoidCallback onCreateJudge;
  final VoidCallback onViewJudges;
  final VoidCallback onJudgeScores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _AdminPalette.panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: _AdminPalette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _QuickActionTile(
            title: 'Create Event',
            subtitle: 'Set up a new judging event',
            icon: Icons.event_rounded,
            onTap: onCreateEvent,
          ),
          const SizedBox(height: 9),
          _QuickActionTile(
            title: 'Create Judge Account',
            subtitle: 'Add a new judge to the system',
            icon: Icons.person_add_alt_1_rounded,
            onTap: onCreateJudge,
          ),
          const SizedBox(height: 9),
          _QuickActionTile(
            title: 'View Judges',
            subtitle: 'See all registered judges',
            icon: Icons.groups_rounded,
            onTap: onViewJudges,
          ),
          const SizedBox(height: 9),
          _QuickActionTile(
            title: 'Judge Scores',
            subtitle: 'View and manage scores',
            icon: Icons.analytics_rounded,
            onTap: onJudgeScores,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: _AdminPalette.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _AdminPalette.primary, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminPalette.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _AdminPalette.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemInfoPanel extends StatelessWidget {
  const _SystemInfoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _AdminPalette.panelDecoration,
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Information',
                  style: TextStyle(
                    color: _AdminPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Firebase Realtime Database',
                  style: TextStyle(
                    color: _AdminPalette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _OnlineBadge(),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F8ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _AdminPalette.success, size: 8),
          SizedBox(width: 6),
          Text(
            'Ready',
            style: TextStyle(
              color: Color(0xFF128848),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorBanner extends StatelessWidget {
  const _DashboardErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _AdminPalette.danger),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Dashboard data could not be loaded. Your management tools are still available.',
              style: TextStyle(color: _AdminPalette.ink, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.totalEvents,
    required this.totalJudges,
    required this.totalContestants,
    required this.eventsWithScores,
    required this.events,
  });

  final int totalEvents;
  final int totalJudges;
  final int totalContestants;
  final int eventsWithScores;
  final List<_EventOverview> events;
}

class _EventOverview {
  const _EventOverview({
    required this.name,
    required this.contestantCount,
    required this.judgeCount,
    required this.hasScores,
  });

  final String name;
  final int contestantCount;
  final int judgeCount;
  final bool hasScores;
}

class _AdminBackgroundOrb extends StatelessWidget {
  const _AdminBackgroundOrb({required this.size});

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

class _AdminPalette {
  const _AdminPalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryLight = Color(0xFF4B50D7);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const success = Color(0xFF18A957);
  static const danger = Color(0xFFD92D38);

  static BoxDecoration get panelDecoration => BoxDecoration(
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
      );
}
