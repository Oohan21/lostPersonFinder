import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class MessagingScreen extends StatefulWidget {
  final String conversationId;
  final String reportId;
  final String otherParticipantName;
  final String? otherParticipantId; // Added to match arguments

  const MessagingScreen({
    super.key,
    required this.conversationId,
    required this.reportId,
    required this.otherParticipantName,
    this.otherParticipantId,
  });

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _validateReportId();
    _loadUserId();
    _fetchMessages();
  }

  void _validateReportId() {
    if (!RegExp(uuidRegex).hasMatch(widget.reportId)) {
      print('Invalid reportId format: ${widget.reportId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid report ID format.')),
          );
        }
      });
    } else {
      print('Valid reportId: ${widget.reportId}');
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('id'); // Match key used in ApiService
    });
    print('Loaded userId: $_userId');
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = ApiService();
      final messages = await apiService.getMessages(
        widget.conversationId,
        context,
      );
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
        });
      }
      print(
        'Fetched ${_messages.length} messages for conversation: ${widget.conversationId}',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
      }
      print('Error fetching messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _userId == null) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = ApiService();
      print(
        'Sending message with reportId: ${widget.reportId}, content: $content',
      );
      final response = await apiService.sendMessage(
        widget.conversationId,
        widget.reportId,
        content,
      );
      print(
        'Send message response: status ${response['status']}, body: ${response['body']}',
      );
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': {'id': _userId},
            'content': content,
            'createdAt': DateTime.now().toIso8601String(),
          });
          _messageController.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
      print('Error sending message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherParticipantName)),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message['sender']?['id'] == _userId;
                        return ListTile(
                          title: Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(message['content']),
                            ),
                          ),
                          subtitle: Text(
                            message['createdAt'] != null
                                ? DateTime.parse(
                                  message['createdAt'],
                                ).toLocal().toString()
                                : '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
