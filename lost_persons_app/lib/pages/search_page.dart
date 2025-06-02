import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _nameController = TextEditingController();
  final _ageMinController = TextEditingController();
  final _ageMaxController = TextEditingController();
  final _genderController = TextEditingController();
  final _locationController = TextEditingController();
  final _radiusController = TextEditingController();
  List<dynamic> _reports = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  final _apiService = ApiService();
  Timer? _debounce;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchReports(reset: true); // Initial load
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _nameController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    _genderController.dispose();
    _locationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoading) {
      _loadMoreReports();
    }
  }

  Future<void> _searchReports({bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _page = 1;
        _reports = [];
        _hasMore = true;
        _error = null;
      });
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.getReports(
        name:
            _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : null,
        ageMin:
            _ageMinController.text.isNotEmpty
                ? int.tryParse(_ageMinController.text)
                : null,
        ageMax:
            _ageMaxController.text.isNotEmpty
                ? int.tryParse(_ageMaxController.text)
                : null,
        gender:
            _genderController.text.trim().isNotEmpty
                ? _genderController.text.trim()
                : null,
        location:
            _locationController.text.trim().isNotEmpty
                ? _locationController.text.trim()
                : null,
        radius:
            _radiusController.text.isNotEmpty
                ? double.tryParse(_radiusController.text)
                : null,
        page: _page,
        limit: 10,
        context: context,
      );
      if (!mounted) return;
      setState(() {
        _reports.addAll(result['reports'] ?? []);
        _hasMore =
            result['pagination'] != null &&
            result['pagination']['pages'] != null &&
            _page < (result['pagination']['pages'] as int);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      print('Search reports error: $e');
    }
  }

  void _loadMoreReports() {
    if (!_isLoading && _hasMore) {
      _page++;
      _searchReports();
    }
  }

  void _onSearchChanged(String _) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchReports(reset: true);
    });
  }

  void _shareReport(Map<String, dynamic> report) {
    final text =
        'Missing Person: ${report['name']}\nAge: ${report['age']}\nGender: ${report['gender']}\nLast Seen: ${report['lastSeen']['address'] ?? 'N/A'}';
    Share.share(text, subject: 'Missing Person Alert');
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Search Missing Persons',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: _onSearchChanged,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageMinController,
                    decoration: const InputDecoration(labelText: 'Min Age'),
                    keyboardType: TextInputType.number,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _ageMaxController,
                    decoration: const InputDecoration(labelText: 'Max Age'),
                    keyboardType: TextInputType.number,
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _genderController,
              decoration: const InputDecoration(labelText: 'Gender'),
              onChanged: _onSearchChanged,
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (e.g., 38.74,9.03)',
              ),
              onChanged: _onSearchChanged,
            ),
            TextField(
              controller: _radiusController,
              decoration: const InputDecoration(labelText: 'Radius (km)'),
              keyboardType: TextInputType.number,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading && _reports.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Text(_error!))
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          final hasPhoto =
                              report['media']?.isNotEmpty == true &&
                              report['media'][0]?.isNotEmpty == true;
                          return Card(
                            elevation: 4.0,
                            child: ListTile(
                              leading:
                                  hasPhoto
                                      ? Image.network(
                                        '$apiBaseUrl/uploads/${report['media'][0]}',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
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
                                      : const Icon(Icons.person, size: 50),
                              title: Text(report['name'] ?? 'Unknown'),
                              subtitle: Text(
                                'Age: ${report['age'] ?? 'N/A'} | Gender: ${report['gender'] ?? 'N/A'}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _shareReport(report),
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/details',
                                  arguments: report,
                                );
                              },
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
    );
  }
}
