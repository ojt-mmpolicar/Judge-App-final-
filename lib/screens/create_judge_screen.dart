import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchJudges();
  }

  void _fetchJudges() async {
    setState(() {
      _isLoadingJudges = true;
    });
    try {
      final snapshot = await _database.child('judges').get();
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
    } catch (e) {
      setState(() {
        _judges = [];
        _isLoadingJudges = false;
      });
      debugPrint('Error fetching judges: $e');
    }
  }

  void _deleteJudge(String judgeUsername) async {
    try {
      await _database.child('judges/$judgeUsername').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Judge "$judgeUsername" deleted')),
      );
      _fetchJudges();
    } catch (e) {
      debugPrint('Error deleting judge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete judge: $e')),
      );
    }
  }

  void _createJudgeAccount() async {
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
      _fetchJudges();
    } catch (e) {
      debugPrint('Error creating judge account: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create judge account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Darker color palette
    const indigo = Color(0xFF232B6B); // much darker indigo
    const softBlue = Color(0xFF3A4A7A); // deeper blue
    const coral = Color(0xFFB83232); // darker coral/red
    const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
    const charcoalGray = Color(0xFF181A20); // almost black

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Judge',
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: softBlue, width: 2),
              ),
              elevation: 10,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: indigo, size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'Create Judge Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: charcoalGray,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Judge Username',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _judgeUsernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person, color: softBlue),
                        hintText: 'Enter Judge Username',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: offWhite,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: softBlue, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: softBlue, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: indigo, width: 2),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: charcoalGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createJudgeAccount,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text(
                          'Create Judge',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 8,
                          shadowColor: softBlue.withOpacity(0.3),
                          textStyle: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ).copyWith(
                          overlayColor:
                              MaterialStateProperty.resolveWith<Color?>(
                            (states) {
                              if (states.contains(MaterialState.hovered) ||
                                  states.contains(MaterialState.pressed)) {
                                return coral.withOpacity(0.15);
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const Text(
                      'Existing Judges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isLoadingJudges
                        ? const Center(child: CircularProgressIndicator())
                        : _judges.isEmpty
                            ? const Text(
                                'No judges found.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _judges.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final judge = _judges[index];
                                  return Card(
                                    color: offWhite,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                          color: softBlue, width: 1.2),
                                    ),
                                    child: ListTile(
                                      leading: Icon(Icons.person,
                                          color: indigo, size: 28),
                                      title: Text(
                                        judge,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: charcoalGray,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: coral),
                                        tooltip: 'Delete Judge',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Judge'),
                                              content: Text(
                                                  'Are you sure you want to delete judge "$judge"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop();
                                                    _deleteJudge(judge);
                                                  },
                                                  child: const Text(
                                                    'Delete',
                                                    style:
                                                        TextStyle(color: coral),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
