import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Models
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'user',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
    };
  }
}

class MissingPerson {
  final String id;
  final String reportId;
  final String name;
  final int age;
  final String gender;
  final String status;
  final int? conversationCount;

  MissingPerson({
    required this.id,
    required this.reportId,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    this.conversationCount,
  });

  factory MissingPerson.fromJson(Map<String, dynamic> json) {
    return MissingPerson(
      id: json['_id']?.toString() ?? '',
      reportId: json['reportId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      age:
          (json['age'] is int)
              ? json['age']
              : int.tryParse(json['age'].toString()) ?? 0,
      gender: json['gender']?.toString() ?? 'Unknown',
      status: json['status']?.toString() ?? 'active',
      conversationCount: json['conversationCount']?.toInt(),
    );
  }
}

class Sighting {
  final String id;
  final String reportId;
  final String description;
  final String status;
  final String createdBy;
  final String? reportName;

  Sighting({
    required this.id,
    required this.reportId,
    required this.description,
    required this.status,
    required this.createdBy,
    this.reportName,
  });

  factory Sighting.fromJson(Map<String, dynamic> json) {
    return Sighting(
      id: json['_id']?.toString() ?? '',
      reportId: json['reportId']?.toString() ?? '',
      description: json['description']?.toString() ?? 'No description',
      status: json['status']?.toString() ?? 'pending',
      createdBy:
          (json['createdBy'] is Map
                  ? json['createdBy']['_id']
                  : json['createdBy'])
              ?.toString() ??
          '',
      reportName: json['reportName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'reportId': reportId,
      'description': description,
      'status': status,
      'createdBy': createdBy,
      'reportName': reportName,
    };
  }
}

// Auth Provider
class AuthProvider with ChangeNotifier {
  String? _token;
  String? _role;
  String? _userId;
  final AdminApiService _apiService = AdminApiService();

  String? get token => _token;
  String? get role => _role;
  String? get userId => _userId;
  bool get isAuthenticated => _token != null;
  bool get isAdmin => _role == 'admin';

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.login(email, password);
      if (response['token'] != null) {
        _token = response['token'];
        _role = response['user']?['role']?.toString();
        _userId = response['user']?['_id']?.toString();
        print(
          'Login successful, token: $_token, role: $_role, userId: $_userId',
        );
        notifyListeners();
        if (_role != 'admin') {
          await logout();
          throw Exception('Admin access required');
        }
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login failed: $e');
      rethrow;
    }
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _role = prefs.getString('role');
    _userId = prefs.getString('userId');
    print('Loaded token from prefs: $_token, role: $_role, userId: $_userId');
    if (_token != null) {
      try {
        if (await _apiService.validateToken()) {
          print('Token validated successfully');
          notifyListeners();
          return;
        } else {
          print('Token invalid, skipping logout API call');
          _token = null;
          _role = null;
          _userId = null;
          notifyListeners();
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.pushReplacementNamed(context, '/login');
          }
          return;
        }
      } catch (e) {
        print('Token validation failed: $e');
        if (e.toString().contains('jwt is not defined')) {
          print('Backend JWT issue detected, logging out');
        }
      }
    }
    print('No valid token, logging out');
    await logout(redirect: true);
  }

  Future<void> logout({bool redirect = false}) async {
    if (_token != null) {
      await _apiService.logout();
    }
    _token = null;
    _role = null;
    _userId = null;
    print('Logged out, token cleared');
    notifyListeners();
    if (redirect) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}

// Data Provider
class DataProvider with ChangeNotifier {
  final AdminApiService _apiService =
      AdminApiService(); // Update to AdminApiService
  List<User> _users = [];
  List<MissingPerson> _missingPersons = [];
  List<Sighting> _sightings = [];
  Map<String, dynamic> _pagination = {};

  List<User> get users => _users;
  List<MissingPerson> get missingPersons => _missingPersons;
  List<Sighting> get sightings => _sightings;
  Map<String, dynamic> get pagination => _pagination;

  Future<void> fetchUsers() async {
    final data = await _apiService.getUsers();
    _users = data.map((json) => User.fromJson(json)).toList();
    notifyListeners();
  }

  Future<void> fetchMissingPersons({int page = 1, int limit = 10}) async {
    final data = await _apiService.getReports(page: page, limit: limit);
    _missingPersons =
        (data['reports'] as List)
            .map((e) => MissingPerson.fromJson(e))
            .toList();
    _pagination = data['pagination'];
    for (var report in _missingPersons) {
      try {
        report = MissingPerson(
          id: report.id,
          reportId: report.reportId,
          name: report.name,
          age: report.age,
          gender: report.gender,
          status: report.status,
        );
      } catch (e) {
        print('Error fetching conversations for report ${report.id}: $e');
      }
    }
    notifyListeners();
  }

  Future<void> fetchSightings(String reportId) async {
    if (reportId.isEmpty) return;
    final sightingsData = await _apiService.getSightings(reportId);
    _sightings =
        sightingsData.map((json) {
          final sighting = Sighting.fromJson(json);
          return Sighting.fromJson({
            ...sighting.toMap(),
            'reportName':
                _missingPersons
                    .firstWhere(
                      (r) => r.id == reportId,
                      orElse:
                          () => MissingPerson(
                            id: '',
                            reportId: '',
                            name: 'Unknown',
                            age: 0,
                            gender: 'Unknown',
                            status: 'active',
                          ),
                    )
                    .name,
          });
        }).toList();
    notifyListeners();
  }

  Future<void> updateSightingStatus(
    String reportId,
    String sightingId,
    String status,
  ) async {
    await _apiService.updateSightingStatus(reportId, sightingId, status);
    await fetchSightings(reportId);
  }

  Future<void> updateReportStatus(String reportId, String status) async {
    try {
      final response = await _apiService.updateReportStatus(reportId, status);
      await fetchMissingPersons(page: _pagination['page']?.toInt() ?? 1);
    } catch (e) {
      print('Error updating report status: $e');
      rethrow;
    }
  }

  Future<void> deleteMissingPerson(String id) async {
    await _apiService.deleteMissingPerson(id);
    await fetchMissingPersons(page: _pagination['page']?.toInt() ?? 1);
  }
}

// Main App
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Admin Dashboard',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(primarySwatch: Colors.blue),
            initialRoute:
                authProvider.isAuthenticated && authProvider.isAdmin
                    ? '/dashboard'
                    : '/login',
            routes: {
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/users': (context) => const UsersScreen(),
              '/reports': (context) => const ReportsScreen(),
            },
          );
        },
      ),
    );
  }
}

// Auth Wrapper
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return FutureBuilder(
      future: authProvider.loadToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        return authProvider.isAuthenticated && authProvider.isAdmin
            ? const ReportsScreen()
            : const LoginScreen();
      },
    );
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).login(_emailController.text, _passwordController.text);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      setState(() {
        _error =
            'Login failed: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Admin Login',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Login'),
                    ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Dashboard Screen
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();

    // Initialize animation controller for fade-in effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final AdminApiService apiService = AdminApiService();
    try {
      // Validate token before fetching data
      if (!await apiService.validateToken()) {
        await authProvider.logout(redirect: true);
        throw Exception('Session expired');
      }
      await Future.wait([
        dataProvider.fetchUsers(),
        dataProvider.fetchMissingPersons(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await authProvider.logout(redirect: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!.contains('Session expired')
                          ? 'Session expired. Please log in again.'
                          : 'Failed to load dashboard data: $_error',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          _error!.contains('Session expired')
                              ? () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              )
                              : _fetchData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _error!.contains('Session expired')
                            ? 'Log In'
                            : 'Retry',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[700]!, Colors.blue[500]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, Admin!',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Manage your reports and users efficiently.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats Overview
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatCard(
                                'Total Users',
                                dataProvider.users.length,
                                Icons.person,
                                Colors.green,
                              ),
                              _buildStatCard(
                                'Missing Persons',
                                dataProvider.missingPersons.length,
                                Icons.person_search,
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Navigation Cards
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Wrap(
                            spacing: 16.0,
                            runSpacing: 16.0,
                            alignment: WrapAlignment.center,
                            children: [
                              DashboardCard(
                                title: 'Users',
                                count: dataProvider.users.length,
                                icon: Icons.group,
                                gradientColors: [
                                  Colors.blue[600]!,
                                  Colors.blue[400]!,
                                ],
                                onTap:
                                    () =>
                                        Navigator.pushNamed(context, '/users'),
                              ),
                              DashboardCard(
                                title: 'Missing Persons',
                                count: dataProvider.missingPersons.length,
                                icon: Icons.person_search,
                                gradientColors: [
                                  Colors.orange[600]!,
                                  Colors.orange[400]!,
                                ],
                                onTap:
                                    () => Navigator.pushNamed(
                                      context,
                                      '/reports',
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = (screenWidth / 3 - 32).clamp(200.0, 300.0);
    final minCardWidth = (maxCardWidth * 0.8).clamp(150.0, 200.0);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 200.0,
          constraints: BoxConstraints(
            maxWidth: maxCardWidth,
            minWidth: minCardWidth,
          ),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Admin Drawer
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Admin Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushNamed(context, '/dashboard'),
          ),
          ListTile(
            title: const Text('Users'),
            onTap: () => Navigator.pushNamed(context, '/users'),
          ),
          ListTile(
            title: const Text('Missing Persons'),
            onTap: () => Navigator.pushNamed(context, '/reports'),
          ),
          ListTile(
            title: const Text('Logout'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              await Provider.of<AuthProvider>(
                context,
                listen: false,
              ).logout(redirect: true);
              Navigator.pop(context); // Close the drawer
            },
          ),
        ],
      ),
    );
  }
}

// Users Screen
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<void> _fetchUsersFuture;

  @override
  void initState() {
    super.initState();
    _fetchUsersFuture =
        Provider.of<DataProvider>(context, listen: false).fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        backgroundColor: Colors.blue[700],
      ),
      drawer: const AdminDrawer(),
      body: FutureBuilder(
        future: _fetchUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load users: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                dataProvider.users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            childAspectRatio: 2 / 1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: dataProvider.users.length,
                      itemBuilder: (context, index) {
                        final user = dataProvider.users[index];
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Role: ${user.role}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Phone: ${user.phone ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          );
        },
      ),
    );
  }
}

// Reports Screen
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? _error;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    _fetchData();

    // Initialize animation controller for fade-in effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<void> _fetchData({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Provider.of<DataProvider>(
        context,
        listen: false,
      ).fetchMissingPersons(page: page);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error =
            'Failed to fetch data: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
      if (_error!.contains('Session expired') ||
          _error!.contains('not authenticated')) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    setState(() {
      final filtered =
          dataProvider.missingPersons.where((report) {
            return report.name.toLowerCase().contains(query) ||
                report.status.toLowerCase().contains(query);
          }).toList();
      dataProvider._missingPersons = filtered;
      dataProvider.notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final currentPage = dataProvider.pagination['page']?.toInt() ?? 1;
    final totalPages = dataProvider.pagination['pages']?.toInt() ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Missing Persons',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 4,
      ),
      drawer: const AdminDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _fetchData(page: currentPage),
        backgroundColor: Colors.blue[700],
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Reports',
                        hintText: 'Enter name or status...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.blue,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterData();
                                  },
                                )
                                : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    // Pagination Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page $currentPage of $totalPages',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color:
                                    currentPage > 1
                                        ? Colors.blue[700]
                                        : Colors.grey,
                              ),
                              onPressed:
                                  currentPage > 1
                                      ? () => _fetchData(page: currentPage - 1)
                                      : null,
                              tooltip: 'Previous Page',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_forward,
                                color:
                                    currentPage < totalPages
                                        ? Colors.blue[700]
                                        : Colors.grey,
                              ),
                              onPressed:
                                  currentPage < totalPages
                                      ? () => _fetchData(page: currentPage + 1)
                                      : null,
                              tooltip: 'Next Page',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Reports Grid
                    Expanded(
                      child:
                          dataProvider.missingPersons.isEmpty
                              ? Center(
                                child: Text(
                                  'No reports found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                              : FadeTransition(
                                opacity: _fadeAnimation,
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        childAspectRatio: 3 / 2,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: dataProvider.missingPersons.length,
                                  itemBuilder: (context, index) {
                                    final report =
                                        dataProvider.missingPersons[index];
                                    return Card(
                                      elevation: 6,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      color: Colors.white,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Name and Status Row
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    report.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        report.status ==
                                                                'active'
                                                            ? Colors.orange[100]
                                                            : Colors.green[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    report.status,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          report.status ==
                                                                  'active'
                                                              ? Colors
                                                                  .orange[800]
                                                              : Colors
                                                                  .green[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Details
                                            Text(
                                              'Age: ${report.age}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              'Gender: ${report.gender}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const Spacer(),
                                            // Action Buttons
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                DropdownButton<String>(
                                                  value: report.status,
                                                  onChanged: (value) async {
                                                    try {
                                                      await dataProvider
                                                          .updateReportStatus(
                                                            report.id,
                                                            value!,
                                                          );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Report status updated',
                                                          ),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  items:
                                                      [
                                                        'active',
                                                        'resolved',
                                                      ].map((status) {
                                                        return DropdownMenuItem(
                                                          value: status,
                                                          child: Text(
                                                            status,
                                                            style: TextStyle(
                                                              color:
                                                                  Colors
                                                                      .blue[700],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                  style: TextStyle(
                                                    color: Colors.blue[700],
                                                  ),
                                                  iconEnabledColor:
                                                      Colors.blue[700],
                                                  underline: const SizedBox(),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_red_eye,
                                                    color: Colors.blue,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (_) =>
                                                                SightingsScreen(
                                                                  reportId:
                                                                      report.id,
                                                                ),
                                                      ),
                                                    );
                                                  },
                                                  tooltip: 'View Sightings',
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      await dataProvider
                                                          .deleteMissingPerson(
                                                            report.id,
                                                          );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Report deleted',
                                                          ),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  tooltip: 'Delete Report',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Sightings Screen
class SightingsScreen extends StatelessWidget {
  final String? reportId;

  const SightingsScreen({super.key, this.reportId});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Sightings')),
      drawer: const AdminDrawer(),
      body: FutureBuilder(
        future: dataProvider.fetchSightings(reportId ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return dataProvider.sightings.isEmpty
              ? const Center(child: Text('No sightings found'))
              : ListView.builder(
                itemCount: dataProvider.sightings.length,
                itemBuilder: (context, index) {
                  final sighting = dataProvider.sightings[index];
                  return Card(
                    child: ListTile(
                      title: Text(sighting.description),
                      subtitle: Text('Status: ${sighting.status}'),
                      trailing: DropdownButton<String>(
                        value: sighting.status,
                        items:
                            ['pending', 'verified', 'rejected'].map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                        onChanged: (newStatus) async {
                          try {
                            await dataProvider.updateSightingStatus(
                              reportId ?? sighting.reportId,
                              sighting.id,
                              newStatus!,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sighting status updated'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              );
        },
      ),
    );
  }
}
