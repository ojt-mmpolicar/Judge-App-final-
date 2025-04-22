import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewContestantsScreen extends StatefulWidget {
  const ViewContestantsScreen({super.key});

  @override
  State<ViewContestantsScreen> createState() => _ViewContestantsScreenState();
}

class _ViewContestantsScreenState extends State<ViewContestantsScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> contestants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContestants();
  }

  void _fetchContestants() async {
    try {
      final snapshot = await _database.child('contestants').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          contestants = data.entries.map((entry) {
            final details = entry.value as Map<dynamic, dynamic>;
            return {
              'name': details['name'] ?? 'Unknown',
              'details': details,
            };
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        debugPrint('No contestants found.');
      }
    } catch (e) {
      debugPrint('Error fetching contestants: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Contestants')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : contestants.isEmpty
              ? const Center(child: Text('No contestants found.'))
              : ListView.builder(
                  itemCount: contestants.length,
                  itemBuilder: (context, index) {
                    final contestant = contestants[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: ListTile(
                        title: Text(contestant['name']),
                        subtitle: Text(
                          contestant['details'] != null
                              ? contestant['details'].toString()
                              : 'No additional details',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
