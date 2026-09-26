import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CreateJudgeScreen extends StatefulWidget {
  const CreateJudgeScreen({super.key});

  @override
  State<CreateJudgeScreen> createState() => _CreateJudgeScreenState();
}

class _CreateJudgeScreenState extends State<CreateJudgeScreen> {
  final _judgeUsernameController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  List<String> _judges = [];
  bool _isLoadingJudges = true;
  String _searchQuery = '';

  List<String> get _filteredJudges {
    final judges = [..._judges]
      ..sort((first, second) => first.toLowerCase().compareTo(
            second.toLowerCase(),
          ));
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return judges;
    return judges
        .where((judge) => judge.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchJudges();
  }

  @override
  void dispose() {
    _judgeUsernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchJudges() async {
    if (mounted) setState(() => _isLoadingJudges = true);

    try {
      final snapshot = await _database.child('judges').get();
      if (!mounted) return;

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _judges = data.keys.toList();
          _isLoadingJudges = false;
        });
      } else {
        setState(() {
          _judges = [];
          _isLoadingJudges = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _judges = [];
        _isLoadingJudges = false;
      });
      debugPrint('Error fetching judges: $error');
    }
  }

  Future<void> _deleteJudge(String judgeUsername) async {
    try {
      await _database.child('judges/$judgeUsername').remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Judge "$judgeUsername" deleted')),
      );
      await _fetchJudges();
    } catch (error) {
      debugPrint('Error deleting judge: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete judge: $error')),
      );
    }
  }

  Future<void> _confirmDeleteJudge(String judgeUsername) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: _JudgePalette.danger),
            SizedBox(width: 11),
            Text('Delete Judge'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete judge "$judgeUsername"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _JudgePalette.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteJudge(judgeUsername);
    }
  }

  Future<void> _createJudgeAccount() async {
    final judgeUsername = _judgeUsernameController.text.trim();
    if (judgeUsername.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a judge username')),
      );
      return;
    }

    try {
      final snapshot = await _database.child('judges/$judgeUsername').get();
      if (snapshot.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judge username already exists')),
        );
        return;
      }

      await _database.child('judges/$judgeUsername').set({'active': true});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judge account created successfully')),
      );
      _judgeUsernameController.clear();
      await _fetchJudges();
    } catch (error) {
      debugPrint('Error creating judge account: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create judge account: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _JudgePalette.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFF),
        foregroundColor: _JudgePalette.ink,
        surfaceTintColor: const Color(0xFFF8FAFF),
        toolbarHeight: 66,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Judge accounts',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _JudgePalette.border),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -170,
            right: -150,
            child: _JudgeBackgroundOrb(size: 420),
          ),
          const Positioned(
            bottom: -220,
            left: -180,
            child: _JudgeBackgroundOrb(size: 480),
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
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Judge Account',
                            style: TextStyle(
                              color: _JudgePalette.ink,
                              fontSize: 29,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Add judges who can access assigned events and score contestants.',
                            style: TextStyle(
                              color: _JudgePalette.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildCreatePanel(),
                          const SizedBox(height: 20),
                          _buildJudgesPanel(),
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

  Widget _buildCreatePanel() {
    return _JudgePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _JudgeSectionHeading(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Create Judge Account',
            subtitle: 'Create a username for a new event judge.',
          ),
          const SizedBox(height: 20),
          const Text(
            'Judge Username',
            style: TextStyle(
              color: _JudgePalette.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final usernameField = TextField(
                controller: _judgeUsernameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createJudgeAccount(),
                decoration: _inputDecoration(
                  'Enter judge username',
                  icon: Icons.person_rounded,
                ),
              );
              final createButton = _JudgePrimaryButton(
                label: 'Create Judge',
                icon: Icons.add_circle_outline_rounded,
                onPressed: _createJudgeAccount,
              );

              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    usernameField,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: createButton),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: usernameField),
                  const SizedBox(width: 14),
                  SizedBox(width: 190, child: createButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJudgesPanel() {
    final filteredJudges = _filteredJudges;

    return _JudgePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = _JudgeSectionHeading(
                icon: Icons.people_alt_rounded,
                title: 'Existing Judges',
                subtitle: '${_judges.length} registered judge accounts',
              );
              final search = SizedBox(
                width: constraints.maxWidth < 700 ? double.infinity : 320,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: _inputDecoration(
                    'Search judges by username',
                    icon: Icons.search_rounded,
                  ),
                ),
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 16),
                    search,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 20),
                  search,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (_isLoadingJudges)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 76),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredJudges.isEmpty)
            _EmptyJudgesState(hasSearchQuery: _searchQuery.trim().isNotEmpty)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return _JudgeMobileList(
                    judges: filteredJudges,
                    onDelete: _confirmDeleteJudge,
                  );
                }

                return _JudgesTable(
                  judges: filteredJudges,
                  onDelete: _confirmDeleteJudge,
                );
              },
            ),
        ],
      ),
    );
  }

  static InputDecoration _inputDecoration(
    String hint, {
    required IconData icon,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF8990B1),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: _JudgePalette.muted, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: border(_JudgePalette.border, 1),
      enabledBorder: border(_JudgePalette.border, 1),
      focusedBorder: border(_JudgePalette.primaryLight, 1.8),
    );
  }
}

class _JudgePanel extends StatelessWidget {
  const _JudgePanel({required this.child});

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

class _JudgeSectionHeading extends StatelessWidget {
  const _JudgeSectionHeading({
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
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _JudgePalette.primary, size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _JudgePalette.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _JudgePalette.muted,
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

class _JudgePrimaryButton extends StatelessWidget {
  const _JudgePrimaryButton({
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
          colors: [_JudgePalette.primaryLight, _JudgePalette.primary],
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

class _JudgesTable extends StatelessWidget {
  const _JudgesTable({required this.judges, required this.onDelete});

  final List<String> judges;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _JudgePalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _JudgeTableHeader(),
          for (final judge in judges)
            _JudgeTableRow(judge: judge, onDelete: () => onDelete(judge)),
        ],
      ),
    );
  }
}

class _JudgeTableHeader extends StatelessWidget {
  const _JudgeTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: _JudgePalette.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF4F5FF),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('JUDGE USERNAME', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(
            width: 70,
            child: Text('ACTIONS', textAlign: TextAlign.center, style: style),
          ),
        ],
      ),
    );
  }
}

class _JudgeTableRow extends StatelessWidget {
  const _JudgeTableRow({required this.judge, required this.onDelete});

  final String judge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: _JudgePalette.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _JudgeAvatar(username: judge),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    judge,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _JudgePalette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(flex: 2, child: _ActiveBadge()),
          SizedBox(
            width: 70,
            child: Center(
              child: IconButton(
                tooltip: 'Delete judge',
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEFF1),
                  foregroundColor: _JudgePalette.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JudgeMobileList extends StatelessWidget {
  const _JudgeMobileList({required this.judges, required this.onDelete});

  final List<String> judges;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: judges.map((judge) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _JudgePalette.border),
            ),
            child: Row(
              children: [
                _JudgeAvatar(username: judge),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judge,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _JudgePalette.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const _ActiveBadge(),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete judge',
                  onPressed: () => onDelete(judge),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: _JudgePalette.danger,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _JudgeAvatar extends StatelessWidget {
  const _JudgeAvatar({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final initial =
        username.trim().isEmpty ? '?' : username.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 17,
      backgroundColor: const Color(0xFFE9EAFF),
      child: Text(
        initial,
        style: const TextStyle(
          color: _JudgePalette.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

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
        child: const Text(
          'Active',
          style: TextStyle(
            color: Color(0xFF128848),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyJudgesState extends StatelessWidget {
  const _EmptyJudgesState({required this.hasSearchQuery});

  final bool hasSearchQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F1FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearchQuery
                    ? Icons.person_search_rounded
                    : Icons.group_add_rounded,
                color: _JudgePalette.primary,
                size: 29,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasSearchQuery ? 'No matching judges' : 'No judges found',
              style: const TextStyle(
                color: _JudgePalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasSearchQuery
                  ? 'Try a different username.'
                  : 'Create the first judge account above.',
              style: const TextStyle(
                color: _JudgePalette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JudgeBackgroundOrb extends StatelessWidget {
  const _JudgeBackgroundOrb({required this.size});

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

class _JudgePalette {
  const _JudgePalette._();

  static const primary = Color(0xFF3034A8);
  static const primaryLight = Color(0xFF4B50D7);
  static const ink = Color(0xFF10183E);
  static const muted = Color(0xFF69709A);
  static const background = Color(0xFFF3F6FF);
  static const border = Color(0xFFD5D9EE);
  static const danger = Color(0xFFD92D38);
}
