import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../main.dart';
import '../services/api_service.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final ApiService _apiService = ApiService();
  String? _userRole;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _apiService.getUserData(context);
      setState(() {
        _user = userData;
        _userRole = userData['role'] ?? 'user';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      // ignore: avoid_print
      print('Load user data error: $e');
    }
  }

  Future<void> _startMessaging(
    BuildContext context,
    Map<String, dynamic> report,
  ) async {
    final apiService = ApiService();
    try {
      final reportId =
          report['reportId'] as String? ?? report['_id'] as String?;
      if (reportId == null ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(reportId)) {
        print('Invalid reportId format in DetailsPage: $reportId');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid report ID')));
        return;
      }

      // Assume messaging the report's creator
      final otherParticipantId =
          report['createdBy']?['_id'] as String? ??
          report['createdBy'] as String?;
      if (otherParticipantId == null ||
          !RegExp(objectIdRegex).hasMatch(otherParticipantId)) {
        print('Invalid otherParticipantId in DetailsPage: $otherParticipantId');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid participant ID')));
        return;
      }

      final conversation = await apiService.getOrCreateConversation(
        reportId,
        otherParticipantId,
        context,
      );
      final otherParticipantName =
          conversation['otherParticipantName'] ?? 'Unknown';

      print(
        'Navigating to MessagingScreen with conversationId: ${conversation['id']}, '
        'reportId: $reportId, otherParticipantName: $otherParticipantName',
      );

      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/messaging',
          arguments: {
            'conversationId': conversation['id'] as String,
            'reportId': reportId,
            'otherParticipantName': otherParticipantName,
          },
        );
      }
    } catch (e) {
      print('Error starting messaging: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start messaging: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    if (report == null) {
      return MainScaffold(
        title: 'Details',
        body: const Center(child: Text('No report data available')),
      );
    }

    final hasPhoto =
        report['media']?.isNotEmpty == true &&
        report['media'][0]?.isNotEmpty == true;
    final lastSeen = report['lastSeen'] ?? {};
    final lastSeenDateTime =
        lastSeen['dateTime'] != null
            ? DateFormat.yMMMd().add_jm().format(
              DateTime.parse(lastSeen['dateTime']).toLocal(),
            )
            : 'Unknown';
    final lastSeenAddress = lastSeen['address'] ?? 'Unknown';
    final lastSeenCoordinates =
        lastSeen['coordinates'] != null
            ? '[${lastSeen['coordinates'][0]}, ${lastSeen['coordinates'][1]}]'
            : 'Not available';

    return MainScaffold(
      title: 'Missing Person Details',
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child:
                              hasPhoto
                                  ? Image.network(
                                    '$apiBaseUrl/uploads/${report['media'][0]}',
                                    fit: BoxFit.cover,
                                    width: 200,
                                    height: 200,
                                    errorBuilder: (context, error, stackTrace) {
                                      // ignore: avoid_print
                                      print(
                                        'Image error for ${report['_id']}: $error',
                                      );
                                      return const Icon(
                                        Icons.person,
                                        size: 100,
                                      );
                                    },
                                  )
                                  : const Icon(Icons.person, size: 100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Name: ${report['name'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text('Age: ${report['age'] ?? 'N/A'}'),
                            Text('Gender: ${report['gender'] ?? 'N/A'}'),
                            if (report['bonus'] != null) ...[
                              const SizedBox(height: 8),
                              Text('Bonus: ${report['bonus']}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Seen',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Date: $lastSeenDateTime'),
                            Text('Address: $lastSeenAddress'),
                            Text('Coordinates: $lastSeenCoordinates'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contact Info',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Phone: ${report['phone'] ?? 'Contact info not provided'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Additional Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Description: ${report['description'] ?? 'No description provided'}',
                            ),
                            Text('Weight: ${report['weight'] ?? 'N/A'}'),
                            Text('Height: ${report['height'] ?? 'N/A'}'),
                            Text('Hair Color: ${report['hairColor'] ?? 'N/A'}'),
                            Text('Eye Color: ${report['eyeColor'] ?? 'N/A'}'),
                            Text('Markup: ${report['markup'] ?? 'N/A'}'),
                            Text('Skin Color: ${report['skinColor'] ?? 'N/A'}'),
                            Text(
                              'Police Report Number: ${report['policeReportNumber'] ?? 'N/A'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sightings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _apiService.getSightings(
                                report['_id'],
                                context,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.red),
                                  );
                                }
                                final sightings = snapshot.data ?? [];
                                if (sightings.isEmpty) {
                                  return const Text('No sightings available');
                                }
                                return Column(
                                  children:
                                      sightings.map((sighting) {
                                        final isEditable =
                                            _userRole == 'admin' ||
                                            (_user != null &&
                                                sighting['createdBy']?['_id'] ==
                                                    _user?['_id']);
                                        return ListTile(
                                          title: Text(
                                            sighting['description'] ??
                                                'No description',
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Sighted on: ${DateFormat.yMMMd().add_jm().format(DateTime.parse(sighting['location']['dateTime']))}',
                                              ),
                                              Text(
                                                'Status: ${(sighting['status'] ?? 'pending').toString().capitalize()}',
                                              ),
                                              if (sighting['location']['coordinates']?['coordinates'] !=
                                                  null)
                                                Text(
                                                  'Coordinates: [${sighting['location']['coordinates']['coordinates'][0]}, ${sighting['location']['coordinates']['coordinates'][1]}]',
                                                ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isEditable)
                                                IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  onPressed: () {
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/sighting_form',
                                                      arguments: {
                                                        'reportId':
                                                            report['_id'],
                                                        'sighting': sighting,
                                                      },
                                                    );
                                                  },
                                                ),
                                              if (_userRole == 'admin')
                                                DropdownButton<String>(
                                                  value:
                                                      sighting['status'] ??
                                                      'pending',
                                                  items:
                                                      [
                                                        'pending',
                                                        'verified',
                                                        'rejected',
                                                      ].map((status) {
                                                        return DropdownMenuItem(
                                                          value: status,
                                                          child: Text(
                                                            status.capitalize(),
                                                          ),
                                                        );
                                                      }).toList(),
                                                  onChanged: (newStatus) async {
                                                    if (newStatus != null) {
                                                      try {
                                                        await _apiService
                                                            .updateSightingStatus(
                                                              report['_id'],
                                                              sighting['_id'],
                                                              newStatus,
                                                              context,
                                                            );
                                                        setState(
                                                          () {},
                                                        ); // Refresh sightings
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Sighting status updated to $newStatus',
                                                            ),
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
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // ignore: avoid_print
                          print(
                            'Navigating to SightingFormPage with reportId: ${report['_id']}',
                          );
                          Navigator.pushNamed(
                            context,
                            '/sighting_form',
                            arguments: {'reportId': report['_id']},
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('Report a Sighting'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _startMessaging(context, report),
                        icon: const Icon(Icons.message),
                        label: const Text('Message About This Person'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
