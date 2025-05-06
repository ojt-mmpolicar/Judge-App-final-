import 'package:flutter/material.dart';
import 'create_event_screen.dart';
import 'create_judge_screen.dart';
import 'judge_scores_screen.dart';
import 'login_screen.dart'; // Import the login screen

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ); // Navigate back to the login page
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Home',
          style: TextStyle(
            color: Color(0xFFEAEAEA), // Light text color for contrast
            fontWeight: FontWeight.bold,
            fontSize: 20,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 10,
                color:
                    Color(0xFF08D9D6), // Bright Cyan glow for better visibility
              ),
            ],
          ),
        ),
        backgroundColor:
            const Color(0xFF0F0F0F), // Dark background for contrast
        elevation: 4, // Add slight shadow for separation from the background
        iconTheme:
            const IconThemeData(color: Color(0xFFEAEAEA)), // Match icon color
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F0F0F), // Dark background
                Color(0xFF08D9D6) // Bright Cyan
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  image: DecorationImage(
                    image: AssetImage('assets/admin_banner.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Admin Menu',
                    style: TextStyle(
                      color: Color(0xFFEAEAEA),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 10,
                          color: Color(0xFF08D9D6), // Bright Cyan glow
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.event, color: Color(0xFF08D9D6), size: 28),
                title: const Text('Create Event',
                    style: TextStyle(color: Color(0xFFEAEAEA))),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateEventScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add,
                    color: Color(0xFF08D9D6), size: 28),
                title: const Text('Create Judge Account',
                    style: TextStyle(color: Color(0xFFEAEAEA))),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateJudgeScreen()),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.score, color: Color(0xFF08D9D6), size: 28),
                title: const Text('Judge Scores',
                    style: TextStyle(color: Color(0xFFEAEAEA))),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const JudgeScoresScreen()),
                  );
                },
              ),
              const Divider(), // Add a divider for better UI
              ListTile(
                leading: const Icon(Icons.exit_to_app,
                    color: Color(0xFF08D9D6), size: 28),
                title: const Text('Log Out',
                    style: TextStyle(color: Color(0xFFEAEAEA))),
                onTap: _showExitConfirmationDialog, // Show confirmation dialog
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 15, 15, 15), // Dark background
              Color.fromARGB(255, 8, 217, 214) // Bright Cyan
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF08D9D6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF08D9D6).withAlpha(128),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 120,
                  color: Color(0xFFEAEAEA),
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 20,
                      color: Color(0xFF08D9D6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Admin Home',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEAEAEA),
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 10,
                      color: Color(0xFF08D9D6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
