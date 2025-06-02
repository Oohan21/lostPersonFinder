import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../main.dart';
import '../utils/constants.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _apiService.getNotifications(context);
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      print('Load notifications error: $e');
    }
  }

  Future<void> _markAsRead(
    String notificationId,
    String? conversationId,
    String? reportId,
    String? otherParticipantName,
  ) async {
    if (conversationId == null ||
        conversationId.isEmpty ||
        reportId == null ||
        reportId.isEmpty ||
        !RegExp(uuidRegex).hasMatch(reportId) ||
        otherParticipantName == null ||
        otherParticipantName.isEmpty) {
      print(
        'Blocked navigation due to invalid parameters: conversationId=$conversationId, reportId=$reportId, otherParticipantName=$otherParticipantName',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid notification data. Cannot open chat.'),
        ),
      );
      return;
    }
    try {
      await _apiService.markNotificationAsRead(notificationId, context);
      setState(() {
        _notifications =
            _notifications.map((n) {
              if (n['_id'] == notificationId) {
                return {...n, 'read': true};
              }
              return n;
            }).toList();
      });
      Navigator.pushNamed(
        context,
        '/messaging',
        arguments: {
          'conversationId': conversationId,
          'reportId': reportId,
          'otherParticipantName': otherParticipantName,
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      print('Mark as read error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Notifications',
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : _notifications.isEmpty
              ? const Center(child: Text('No notifications yet'))
              : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final createdAt =
                      DateTime.parse(notification['createdAt']).toLocal();
                  final formattedDate = DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(createdAt);
                  return Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 8.0,
                    ),
                    color:
                        notification['read'] ? Colors.white : Colors.blue[50],
                    child: ListTile(
                      title: Text(notification['content'] ?? 'No content'),
                      subtitle: Text('Received at $formattedDate'),
                      trailing:
                          notification['read']
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(
                                Icons.mark_email_unread,
                                color: Colors.blue,
                              ),
                      onTap:
                          () => _markAsRead(
                            notification['_id'],
                            notification['conversationId'] as String?,
                            notification['reportId'] as String?,
                            notification['otherParticipantName'] as String?,
                          ),
                    ),
                  );
                },
              ),
    );
  }
}
