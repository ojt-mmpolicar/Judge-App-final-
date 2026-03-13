import 'package:flutter/material.dart';
import 'create_event_screen.dart';
import 'create_judge_screen.dart';
import 'judge_scores_screen.dart';
import 'login_screen.dart'; // Import the login screen
import 'view_judges_screen.dart';

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
    // Darker color palette
    const indigo = Color(0xFF232B6B); // much darker indigo
    const softBlue = Color(0xFF3A4A7A); // deeper blue
    const coral = Color(0xFFB83232); // darker coral/red
    const offWhite = Color(0xFFE5E7EB); // darker off-white (light gray)
    const charcoalGray = Color(0xFF181A20); // almost black

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Home',
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
      ),
      drawer: Drawer(
        child: Container(
          color: offWhite,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: indigo,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  image: const DecorationImage(
                    image: AssetImage('assets/admin_banner.jpg'),
                    fit: BoxFit.cover,
                    opacity: 0.25,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Admin Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 10,
                          color: softBlue.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.event, color: indigo, size: 28),
                title: const Text('Create Event',
                    style: TextStyle(
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateEventScreen()),
                  );
                },
                hoverColor: softBlue.withOpacity(0.2),
              ),
              ListTile(
                leading: Icon(Icons.person_add, color: indigo, size: 28),
                title: const Text('Create Judge Account',
                    style: TextStyle(
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateJudgeScreen()),
                  );
                },
                hoverColor: softBlue.withOpacity(0.2),
              ),
              ListTile(
                leading: Icon(Icons.score, color: indigo, size: 28),
                title: const Text('Judge Scores',
                    style: TextStyle(
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const JudgeScoresScreen()),
                  );
                },
                hoverColor: softBlue.withOpacity(0.2),
              ),
              ListTile(
                leading: Icon(Icons.people, color: indigo, size: 28),
                title: const Text('View Judges',
                    style: TextStyle(
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ViewJudgesScreen()),
                  );
                },
                hoverColor: softBlue.withOpacity(0.2),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: coral, size: 28),
                title: const Text('Log Out',
                    style: TextStyle(
                        color: charcoalGray,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500)),
                onTap: _showExitConfirmationDialog,
                hoverColor: coral.withOpacity(0.08),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: offWhite,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: indigo, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: softBlue.withOpacity(0.18),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 110,
                  color: indigo,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 16,
                      color: softBlue.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to Admin Home',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: charcoalGray,
                  fontFamily: 'Poppins',
                  letterSpacing: 1.1,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 10,
                      color: softBlue.withOpacity(0.5),
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
