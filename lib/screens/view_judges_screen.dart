import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
    final snapshot = await _database.child('judges').get();
    if (snapshot.exists) {
      setState(() {
        _judges = Map<String, dynamic>.from(snapshot.value as Map);
        _loading = false;
      });
    } else {
      setState(() {
        _judges = {};
        _loading = false;
      });
    }
  }

  Future<void> _fetchAssignedEvents(String judgeUsername) async {
    setState(() {
      _selectedJudge = judgeUsername;
      _assignedEvents = [];
      _loading = true;
    });
    final snapshot =
        await _database.child('event_assignments/$judgeUsername').get();
    List<String> events = [];
    if (snapshot.exists) {
      final value = snapshot.value;
      if (value is Map) {
        value.forEach((eventKey, eventValue) {
          if (eventValue is Map && eventValue.containsKey('eventName')) {
            events.add(eventValue['eventName'].toString());
          }
        });
      }
    }
    setState(() {
      _assignedEvents = events;
      _loading = false;
    });
  }

  Future<void> _deleteAssignedEvent(
      String judgeUsername, String eventName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Event Assignment'),
        content: Text(
            'Are you sure you want to remove "$eventName" from this judge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _database
          .child('event_assignments/$judgeUsername/$eventName')
          .remove();
      setState(() {
        _assignedEvents.remove(eventName);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event "$eventName" removed from judge.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the same color palette as admin_home
    const indigo = Color(0xFF232B6B);
    const softBlue = Color(0xFF3A4A7A);
    const coral = Color(0xFFB83232);
    const offWhite = Color(0xFFE5E7EB);
    const charcoalGray = Color(0xFF181A20);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'View Judges',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: indigo,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _fetchJudges,
          ),
        ],
      ),
      backgroundColor: offWhite,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Judges List
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Judges',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: charcoalGray,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: _judges.entries.map((entry) {
                              final username = entry.key;
                              final judgeData = entry.value;
                              final displayName = (judgeData is Map &&
                                      judgeData['username'] != null)
                                  ? judgeData['username'].toString()
                                  : username;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Material(
                                  color: _selectedJudge == username
                                      ? softBlue.withOpacity(0.12)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _fetchAssignedEvents(username),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            indigo.withOpacity(0.15),
                                        child:
                                            Icon(Icons.person, color: softBlue),
                                      ),
                                      title: Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: charcoalGray,
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(username,
                                          style: const TextStyle(fontSize: 13)),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        color: _selectedJudge == username
                                            ? coral
                                            : softBlue,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(width: 1, color: softBlue.withOpacity(0.2)),
                // Assigned Events
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.white,
                    child: _selectedJudge == null
                        ? const Center(
                            child: Text(
                              'Select a judge to view assigned events.',
                              style: TextStyle(
                                fontSize: 18,
                                color: charcoalGray,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: indigo.withOpacity(0.15),
                                      child: const Icon(Icons.person,
                                          color: softBlue),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Assigned Events for "${_selectedJudge!}":',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: indigo,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _fetchAssignedEvents(_selectedJudge!),
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Refresh'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: softBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        elevation: 2,
                                        textStyle: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                if (_assignedEvents.isEmpty)
                                  const Text(
                                    'No events assigned.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: charcoalGray,
                                      fontFamily: 'Poppins',
                                    ),
                                  )
                                else
                                  ..._assignedEvents.map((event) => Card(
                                        color: offWhite,
                                        elevation: 2,
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: softBlue.withOpacity(0.2)),
                                        ),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                coral.withOpacity(0.15),
                                            child: const Icon(Icons.event,
                                                color: coral),
                                          ),
                                          title: Text(
                                            event,
                                            style: const TextStyle(
                                              color: charcoalGray,
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            tooltip: 'Remove Event Assignment',
                                            onPressed: () =>
                                                _deleteAssignedEvent(
                                                    _selectedJudge!, event),
                                          ),
                                        ),
                                      )),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
