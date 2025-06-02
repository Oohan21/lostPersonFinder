import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/update_profile_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/sighting_form_page.dart';
import 'pages/profile_page.dart';
import 'pages/notifications_page.dart';
import 'pages/help_page.dart';
import 'pages/details_page.dart';
import 'pages/report_form_page.dart';
import 'pages/search_page.dart';
import 'pages/reports_list_page.dart';
import 'services/api_service.dart';
import 'pages/conversations_screen.dart';
import 'pages/messaging_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => LostPersonsApp(isDarkMode: isDarkMode),
    ),
  );
}

class LostPersonsApp extends StatefulWidget {
  final bool isDarkMode;

  const LostPersonsApp({super.key, required this.isDarkMode});

  @override
  // ignore: library_private_types_in_public_api
  _LostPersonsAppState createState() => _LostPersonsAppState();
}

class _LostPersonsAppState extends State<LostPersonsApp> {
  late ValueNotifier<bool> isDarkMode;

  @override
  void initState() {
    super.initState();
    isDarkMode = ValueNotifier<bool>(widget.isDarkMode);
    // ignore: avoid_print
    print('Initial dark mode: ${widget.isDarkMode}');
  }

  void toggleTheme(bool value) {
    final newValue = !value;
    setState(() {
      isDarkMode.value = newValue;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isDarkMode', newValue).then((_) {
        // ignore: avoid_print
        print('Theme toggled to: $newValue');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        // ignore: avoid_print
        print('Current theme mode: ${darkMode ? 'dark' : 'light'}');
        return MaterialApp(
          title: 'Lost Persons Ethiopia',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.black, fontFamily: 'Roboto'),
              bodyMedium: TextStyle(
                color: Colors.black87,
                fontFamily: 'Roboto',
              ),
            ),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.grey[900],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            drawerTheme: const DrawerThemeData(backgroundColor: Colors.grey),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
              bodyMedium: TextStyle(
                color: Colors.white70,
                fontFamily: 'Roboto',
              ),
            ),
            fontFamily: 'Roboto',
          ),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/home': (context) => const HomePage(),
            '/sighting_form': (context) {
              final args = ModalRoute.of(context)!.settings.arguments;
              if (args == null || args is! Map<String, dynamic>) {
                // ignore: avoid_print
                print(
                  'Navigation error: Expected Map<String, dynamic> for /sighting_form, got: ${args.runtimeType}',
                );
                return const Scaffold(
                  body: Center(
                    child: Text('Error: Invalid navigation arguments'),
                  ),
                );
              }
              final reportId = args['reportId'] as String?;
              final sighting = args['sighting'] as Map<String, dynamic>?;
              if (reportId == null) {
                // ignore: avoid_print
                print('Navigation error: reportId not provided in arguments');
                return const Scaffold(
                  body: Center(child: Text('Error: Report ID not provided')),
                );
              }
              return SightingFormPage(reportId: reportId, sighting: sighting);
            },
            '/profile': (context) => const ProfilePage(),
            '/update_profile': (context) => const UpdateProfilePage(),
            '/notifications': (context) => const NotificationsPage(),
            '/help': (context) => const HelpPage(),
            '/details': (context) => const DetailsPage(),
            '/report': (context) => const ReportFormPage(),
            '/search': (context) => const SearchPage(),
            '/reports_list': (context) => const ReportsListPage(),
            '/conversations': (context) => const ConversationsScreen(),
            '/messaging': (context) {
              final args =
                  ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>?;
              if (args == null ||
                  args['conversationId'] == null ||
                  args['conversationId'].toString().isEmpty ||
                  args['reportId'] == null ||
                  args['reportId'].toString().isEmpty ||
                  args['otherParticipantName'] == null ||
                  args['otherParticipantName'].toString().isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid navigation parameters.'),
                      ),
                    );
                  }
                });
                return const SizedBox.shrink();
              }
              final reportId = args['reportId'].toString();
              // Updated UUID validation
              if (!RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              ).hasMatch(reportId)) {
                print('Invalid reportId format: $reportId');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid report ID format.'),
                      ),
                    );
                  }
                });
                return const SizedBox.shrink();
              }
              return MessagingScreen(
                conversationId: args['conversationId'] as String,
                reportId: reportId,
                otherParticipantName: args['otherParticipantName'] as String,
              );
            },
          },
          builder: DevicePreview.appBuilder,
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkAuth(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return false;

    try {
      final apiService = ApiService();
      await apiService.getProfile(context);
      return true;
    } catch (e) {
      await prefs.remove('token');
      await prefs.remove('role');
      await prefs.remove('name');
      await prefs.remove('email');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuth(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data!) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class MainScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final Widget? floatingActionButton;

  const MainScaffold({
    super.key,
    required this.body,
    required this.title,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (title != 'Profile')
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () => Navigator.pushNamed(context, '/conversations'),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              final appState =
                  context.findAncestorStateOfType<_LostPersonsAppState>();
              if (appState != null) {
                appState.toggleTheme(
                  Theme.of(context).brightness == Brightness.dark,
                );
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<Map<String, String>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('name') ?? 'User',
      'email': prefs.getString('email') ?? 'email@example.com',
    };
  }

  Future<void> _logout(BuildContext context) async {
    final apiService = ApiService();
    await apiService.logout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<Map<String, String>>(
        future: _getUserInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading user info'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No user info available'));
          }

          final userName = snapshot.data!['name'] ?? 'User';
          final userEmail = snapshot.data!['email'] ?? 'email@example.com';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome $userName',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.home,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Home',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              ListTile(
                leading: Icon(
                  Icons.search,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Search',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () => Navigator.pushReplacementNamed(context, '/search'),
              ),
              ListTile(
                leading: Icon(
                  Icons.person,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Profile',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap:
                    () => Navigator.pushReplacementNamed(context, '/profile'),
              ),
              ListTile(
                leading: Icon(
                  Icons.help,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Help',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () => Navigator.pushReplacementNamed(context, '/help'),
              ),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                onTap: () => _logout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
