import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../main.dart';

class ReportsListPage extends StatefulWidget {
  const ReportsListPage({super.key});

  @override
  _ReportsListPageState createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  List<dynamic> _reports = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  final _apiService = ApiService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _loadReports();
  }

  Future<void> _fetchUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('Not authenticated');
      final profile = await _apiService.getProfile(context);
      setState(() {
        _userId = profile['_id'];
      });
      print('Current user ID: $_userId');
    } catch (e) {
      setState(() {
        _error =
            'Failed to load user profile: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      print('Fetch user ID error: $e');
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
        page: _page,
        limit: 10,
        context: context,
      );
      print('Fetched reports: ${result['reports']}');
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
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      print('Load reports error: $e');
    }
  }

  void _shareReport(Map<String, dynamic> report) {
    final text =
        'Missing Person: ${report['name']}\nAge: ${report['age']}\nGender: ${report['gender']}${report['bonus'] != null ? '\nReward: ${report['bonus']}' : ''}';
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
      title: 'Missing Persons',
      body:
          _isLoading && _reports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                              childAspectRatio: 0.7,
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
                          final isOwnReport =
                              _userId != null &&
                              report['reportedBy'] == _userId;

                          return Card(
                            elevation: 4.0,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/details',
                                  arguments: report,
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Photo
                                  Expanded(
                                    child:
                                        hasPhoto
                                            ? Image.network(
                                              '$apiBaseUrl/uploads/${report['media'][0]}',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
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
                                  // Details
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
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text('Age: ${report['age'] ?? 'N/A'}'),
                                        Text(
                                          'Gender: ${report['gender'] ?? 'N/A'}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Buttons (only for the user's own reports)
                                  if (isOwnReport) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            await _deleteReport(report['_id']);
                                          },
                                          child: const Text(
                                            'DELETE',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/report',
                                              arguments: {'report': report},
                                            );
                                          },
                                          child: const Text(
                                            'UPDATE',
                                            style: TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _shareReport(report),
                                          child: const Text(
                                            'SHARE',
                                            style: TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Missing Person'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
