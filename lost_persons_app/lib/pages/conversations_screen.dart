import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _fetchConversations();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('id'); // Assuming 'id' is stored during login
    });
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await ApiService().getConversations(context);
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching conversations: $e')),
      );
    }
  }

  void _startMessaging(Map<String, dynamic> conversation) {
    final reportId = conversation['reportId']?.toString();
    final participants = conversation['participants'] as List<dynamic>;
    final otherParticipant = participants.firstWhere(
      (p) => p['id'] != _userId,
      orElse: () => null,
    );
    if (otherParticipant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other participant found')),
      );
      return;
    }
    final otherParticipantId = otherParticipant['id']?.toString();
    final otherParticipantName =
        otherParticipant['name']?.toString() ?? 'Unknown';

    if (reportId == null ||
        !RegExp(uuidRegex).hasMatch(reportId) ||
        otherParticipantId == null ||
        !RegExp(objectIdRegex).hasMatch(otherParticipantId)) {
      print(
        'Invalid ID format - reportId: $reportId, otherParticipantId: $otherParticipantId',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid report or participant ID')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/messaging',
      arguments: {
        'conversationId': conversation['id']?.toString(),
        'reportId': reportId,
        'otherParticipantName': otherParticipantName,
        'otherParticipantId': otherParticipantId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
              ? const Center(child: Text('No conversations found'))
              : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return ListTile(
                    title: Text(conversation['reportName'] ?? 'Unknown'),
                    subtitle: Text(
                      conversation['lastMessage']?['content'] ?? 'No messages',
                    ),
                    onTap: () => _startMessaging(conversation),
                  );
                },
              ),
    );
  }
}
