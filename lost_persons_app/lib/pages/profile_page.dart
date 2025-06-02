import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<dynamic> _reports = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  final _apiService = ApiService();
  String? _name;
  String? _email;
  String? _profilePicture;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadReports();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _apiService.getProfile(context);
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _name = profile['name'] ?? prefs.getString('name') ?? 'User';
        _email = profile['email'] ?? prefs.getString('email') ?? 'N/A';
        _phone = profile['phone'] ?? 'N/A';
        _profilePicture = profile['profilePicture'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to load profile: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
      print('Load profile error: $e');
    }
  }

  Future<void> _loadReports({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _reports = [];
        _hasMore = true;
        _error = null;
      });
    }
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getReports(
        myPosts: true,
        page: _page,
        limit: 10,
        context: context,
      );
      print('Fetched user reports: ${result['reports']}');
      print('Pagination: ${result['pagination']}');
      setState(() {
        _reports.addAll(result['reports'] ?? []);
        _hasMore =
            result['pagination'] != null &&
            result['pagination']['pages'] != null &&
            _page < (result['pagination']['pages'] as int);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'Failed to load your posts: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
      print('Error loading reports: $e');
    }
  }

  void _shareReport(Map<String, dynamic> report) {
    final text =
        'Missing Person: ${report['name']}\nAge: ${report['age']}\nGender: ${report['gender']}\nLast Seen: ${report['lastSeen']['address']}${report['bonus'] != null ? '\nBonus: ${report['bonus']}' : ''}';
    Share.share(text, subject: 'Missing Person Alert');
  }

  Future<void> _deleteReport(String reportId) async {
    setState(() {
      _error = null;
    });
    try {
      await _apiService.deleteReport(reportId, context);
      setState(() {
        _reports.removeWhere((report) => report['_id'] == reportId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report deleted successfully')),
      );
    } catch (e) {
      setState(() {
        _error =
            'Failed to delete report: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Delete report error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Profile',
      body:
          _isLoading && _reports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage:
                                  _profilePicture != null
                                      ? NetworkImage(
                                        '$apiBaseUrl/$_profilePicture?${DateTime.now().millisecondsSinceEpoch}',
                                      )
                                      : null,
                              child:
                                  _profilePicture == null
                                      ? const Icon(Icons.person, size: 40)
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Email: ${_email ?? 'N/A'}'),
                                Text('Phone: ${_phone ?? 'N/A'}'),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/update_profile',
                                );
                                _loadProfile();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // My Posts Section
                      const Text(
                        'My Posts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _reports.isEmpty && _error == null
                          ? const Center(child: Text('No posts available'))
                          : _error != null
                          ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                          : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8.0,
                                  mainAxisSpacing: 8.0,
                                  childAspectRatio: 0.65,
                                ),
                            itemCount: _reports.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _reports.length && _hasMore) {
                                _page++;
                                _loadReports();
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final report = _reports[index];
                              final hasPhoto =
                                  report['media']?.isNotEmpty == true &&
                                  report['media'][0]?.isNotEmpty == true;
                              return Card(
                                elevation: 4.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/details',
                                          arguments: report,
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 120,
                                            width: double.infinity,
                                            child:
                                                hasPhoto
                                                    ? Image.network(
                                                      '$apiBaseUrl/uploads/${report['media'][0]}',
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (
                                                        context,
                                                        child,
                                                        loadingProgress,
                                                      ) {
                                                        if (loadingProgress ==
                                                            null) {
                                                          return child;
                                                        }
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        );
                                                      },
                                                      errorBuilder: (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        print(
                                                          'Image error for ${report['_id']}: $error',
                                                        );
                                                        return const Icon(
                                                          Icons.person,
                                                          size: 50,
                                                        );
                                                      },
                                                    )
                                                    : const Icon(
                                                      Icons.person,
                                                      size: 50,
                                                    ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Name: ${report['name'] ?? 'Unknown'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Age: ${report['age'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  'Gender: ${report['gender'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Flexible(
                                          child: TextButton(
                                            onPressed: () async {
                                              await _deleteReport(
                                                report['_id'],
                                              );
                                            },
                                            child: const Text(
                                              'DELETE',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: TextButton(
                                            onPressed: () async {
                                              await Navigator.pushNamed(
                                                context,
                                                '/report',
                                                arguments: {
                                                  'withRewards':
                                                      report['bonus'] != null,
                                                  'report': report,
                                                },
                                              );
                                              _loadReports(
                                                reset: true,
                                              ); // Refresh list after update
                                            },
                                            child: const Text(
                                              'UPDATE',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: TextButton(
                                            onPressed:
                                                () => _shareReport(report),
                                            child: const Text(
                                              'SHARE',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      if (_error != null && _reports.isNotEmpty)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }
}
