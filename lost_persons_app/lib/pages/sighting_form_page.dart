import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:typed_data';

class SightingFormPage extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic>? sighting; // Optional sighting data for updates

  const SightingFormPage({super.key, required this.reportId, this.sighting});

  @override
  _SightingFormPageState createState() => _SightingFormPageState();
}

class _SightingFormPageState extends State<SightingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _dateTimeController = TextEditingController();
  final _addressController = TextEditingController();
  final _coordinatesController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final List<XFile> _selectedImages = [];
  String? _error;
  bool _isLoading = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.sighting != null) {
      // Prefill form for updates
      _descriptionController.text = widget.sighting!['description'] ?? '';
      _addressController.text = widget.sighting!['location']?['address'] ?? '';
      if (widget.sighting!['location']?['coordinates'] != null &&
          widget.sighting!['location']['coordinates'] is List) {
        final coords = widget.sighting!['location']['coordinates'] as List;
        if (coords.length == 2) {
          _coordinatesController.text = '${coords[0]},${coords[1]}';
        }
      }
      _nameController.text = widget.sighting!['contactInfo']?['name'] ?? '';
      _phoneController.text = widget.sighting!['contactInfo']?['phone'] ?? '';
      _emailController.text = widget.sighting!['contactInfo']?['email'] ?? '';
      if (widget.sighting!['location']?['dateTime'] != null) {
        try {
          final dateTime = DateTime.parse(
            widget.sighting!['location']['dateTime'],
          );
          _dateTimeController.text = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(dateTime);
        } catch (e) {
          _dateTimeController.text = '';
        }
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _dateTimeController.text = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(fullDateTime);
        });
      }
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final pickedFiles = await picker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(pickedFiles);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick images: $e';
      });
    }
  }

  Future<void> _submitSighting() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Please fix the form errors.');
      return;
    }
    if (widget.reportId.isEmpty) {
      setState(() => _error = 'Invalid report ID. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Parse coordinates if provided
      List<double>? coordinates;
      if (_coordinatesController.text.isNotEmpty) {
        final coords = _coordinatesController.text.trim().split(',');
        if (coords.length != 2) throw Exception('Invalid coordinates format');
        coordinates = [double.parse(coords[0]), double.parse(coords[1])];
      }

      // Ensure dateTime is in ISO format
      final dateTime =
          DateTime.parse('${_dateTimeController.text}:00Z').toIso8601String();

      final sighting = {
        'description': _descriptionController.text.trim(),
        'location': {
          'dateTime': dateTime,
          if (_addressController.text.isNotEmpty)
            'address': _addressController.text.trim(),
          if (coordinates != null) 'coordinates': coordinates,
        },
        'contactInfo': {
          if (_nameController.text.isNotEmpty)
            'name': _nameController.text.trim(),
          if (_phoneController.text.isNotEmpty)
            'phone': _phoneController.text.trim(),
          if (_emailController.text.isNotEmpty)
            'email': _emailController.text.trim(),
        },
      };

      print('Sighting payload: $sighting');
      print('Selected images: ${_selectedImages.length}');
      print('Submitting with reportId: ${widget.reportId}');

      if (widget.sighting == null) {
        // Create new sighting
        await _apiService.submitSighting(
          widget.reportId,
          sighting,
          _selectedImages,
          context,
        );
      } else {
        // Update existing sighting
        await _apiService.updateSighting(
          widget.reportId,
          widget.sighting!['_id'],
          sighting,
          _selectedImages,
          context,
        );
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('id');
        if (currentUserId == null) {
          throw Exception('User ID not found in SharedPreferences');
        }
        print('Current user ID: $currentUserId');

        final report = await _apiService.getReport(widget.reportId, context);
        final creatorId = report['createdBy']?['_id']?.toString();
        if (creatorId == null) {
          throw Exception('Report creator ID not found');
        }
        print('Report creator ID: $creatorId');

        if (creatorId != currentUserId) {
          final conversation = await _apiService.getOrCreateConversation(
            widget.reportId,
            creatorId,
            context,
          );
          print('Conversation created: ${conversation['_id']}');
          if (mounted) {
            Navigator.pushNamed(
              context,
              '/messaging',
              arguments: {
                'conversationId': conversation['_id'],
                'reportId': widget.reportId,
                'otherParticipantName':
                    report['createdBy']?['name'] ?? 'Unknown',
              },
            );
          }
        } else {
          print('Skipping conversation creation: User is the report creator');
        }
      } catch (e) {
        print('Error starting conversation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to start conversation: ${e.toString().replaceAll('Exception: ', '')}',
              ),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sighting submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Sighting submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit sighting: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sighting == null ? 'Report Sighting' : 'Update Sighting',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateTimeController,
                decoration: InputDecoration(
                  labelText: 'Sighting Date and Time *',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDateTime(context),
                  ),
                ),
                readOnly: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Date and time is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                ),
              ),
              TextFormField(
                controller: _coordinatesController,
                decoration: const InputDecoration(
                  labelText: 'Coordinates (Optional, e.g., 38.74,9.03)',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final coords = value.trim().split(',');
                    if (coords.length != 2) {
                      return 'Enter valid coordinates (lng,lat)';
                    }
                    final lng = double.tryParse(coords[0]);
                    final lat = double.tryParse(coords[1]);
                    if (lng == null ||
                        lat == null ||
                        lng < -180 ||
                        lng > 180 ||
                        lat < -90 ||
                        lat > 90) {
                      return 'Enter valid coordinates (lng: -180 to 180, lat: -90 to 90)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Information (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Your Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Your Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegExp.hasMatch(value)) {
                      return 'Enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Photos (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: _pickImages,
                child: const Text('Select Photos'),
              ),
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      final image = _selectedImages[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            kIsWeb
                                ? FutureBuilder<Uint8List>(
                                  future: image.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          print(
                                            'Selected image error at index $index: $error',
                                          );
                                          return const Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                          );
                                        },
                                      );
                                    }
                                    return const SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                )
                                : Image.file(
                                  File(image.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                      'Selected image error at index $index: $error',
                                    );
                                    return const Icon(
                                      Icons.broken_image,
                                      color: Colors.red,
                                    );
                                  },
                                ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _submitSighting,
                          child: Text(
                            widget.sighting == null ? 'Submit' : 'Update',
                          ),
                        ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _dateTimeController.dispose();
    _addressController.dispose();
    _coordinatesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
