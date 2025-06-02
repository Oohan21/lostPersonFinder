import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'package:uuid/uuid.dart'; // Add this import

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({super.key});

  @override
  _ReportFormPageState createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _hairColorController = TextEditingController();
  final _eyeColorController = TextEditingController();
  final _markupController = TextEditingController();
  final _skinColorController = TextEditingController();
  final _policeReportController = TextEditingController();
  final _bonusController = TextEditingController();
  String? _gender;
  String? _location;
  String? _error;
  XFile? _image;
  bool _isLoading = false;
  final _apiService = ApiService();
  Map<String, dynamic>? _existingReport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      _existingReport = args?['report'];
      if (_existingReport != null) {
        _nameController.text = _existingReport!['name'] ?? '';
        _ageController.text = _existingReport!['age']?.toString() ?? '';
        _phoneController.text = _existingReport!['phone'] ?? '';
        _gender = _existingReport!['gender'];
        _descriptionController.text = _existingReport!['description'] ?? '';
        _weightController.text = _existingReport!['weight']?.toString() ?? '';
        _heightController.text = _existingReport!['height']?.toString() ?? '';
        _hairColorController.text = _existingReport!['hairColor'] ?? '';
        _eyeColorController.text = _existingReport!['eyeColor'] ?? '';
        _markupController.text = _existingReport!['markup'] ?? '';
        _skinColorController.text = _existingReport!['skinColor'] ?? '';
        _policeReportController.text =
            _existingReport!['policeReportNumber'] ?? '';
        _bonusController.text = _existingReport!['bonus']?.toString() ?? '';
        final coordinates =
            _existingReport!['lastSeen']?['coordinates']?['coordinates'];
        _location =
            coordinates != null ? '${coordinates[1]},${coordinates[0]}' : '0,0';
      }
      print('ReportFormPage initialized with existingReport: $_existingReport');
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = pickedFile;
      _error = null;
    });
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(
          () => _error = 'Location services are disabled. Please enable them.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _error = 'Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(
          () =>
              _error =
                  'Location permissions are permanently denied. Please enable them in settings.',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _location = '${position.latitude},${position.longitude}';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        // Parse coordinates into [longitude, latitude]
        final coordinates = _location?.split(',') ?? ['0', '0'];
        final latitude = double.tryParse(coordinates[0]) ?? 0.0;
        final longitude = double.tryParse(coordinates[1]) ?? 0.0;

        final reportData = {
          if (_existingReport == null)
            'reportId': const Uuid().v4(), // Generate reportId for new reports
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'phone': _phoneController.text,
          'gender': _gender,
          'description': _descriptionController.text,
          'lastSeen': {
            'dateTime': DateTime.now().toIso8601String(),
            'address': _location ?? 'Unknown',
            'coordinates': {
              'type': 'Point',
              'coordinates': [
                longitude,
                latitude,
              ], // GeoJSON format: [longitude, latitude]
            },
          },
          'media':
              _image != null ? [_image!.name] : _existingReport?['media'] ?? [],
          'weight':
              _weightController.text.isNotEmpty
                  ? double.parse(_weightController.text)
                  : null,
          'height':
              _heightController.text.isNotEmpty
                  ? double.parse(_heightController.text)
                  : null,
          'hairColor': _hairColorController.text,
          'eyeColor': _eyeColorController.text,
          'markup': _markupController.text,
          'skinColor': _skinColorController.text,
          'policeReportNumber': _policeReportController.text,
          if (_bonusController.text.isNotEmpty)
            'bonus': double.parse(_bonusController.text),
        };
        print('Submitting report: $reportData');

        // Check if this is an update or a new report
        if (_existingReport != null && _existingReport!['_id'] != null) {
          print('Updating report with ID: ${_existingReport!['_id']}');
          await _apiService.updateReport(
            _existingReport!['_id'],
            reportData,
            context,
          );
        } else {
          print('Creating new report');
          await _apiService.submitReport(reportData, context);
        }

        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        print('Submit report error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title:
          _existingReport == null
              ? 'Add Missing Person'
              : 'Update Missing Person',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        _image == null
                            ? (_existingReport != null &&
                                    _existingReport!['media']?.isNotEmpty ==
                                        true
                                ? Image.network(
                                  _existingReport!['media'][0],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Image load error: $error');
                                    return const Icon(
                                      Icons.camera_alt,
                                      size: 50,
                                    );
                                  },
                                )
                                : const Icon(Icons.camera_alt, size: 50))
                            : Image.network(
                              _image!.path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Image load error: $error');
                                return const Icon(Icons.camera_alt, size: 50);
                              },
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Full name is required'
                            : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Age is required'
                            : int.tryParse(value) == null
                            ? 'Age must be a number'
                            : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Phone is required'
                            : null,
              ),
              const SizedBox(height: 16),
              const Text('Gender', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  Radio<String>(
                    value: 'Male',
                    groupValue: _gender,
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const Text('Male'),
                  Radio<String>(
                    value: 'Female',
                    groupValue: _gender,
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const Text('Female'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Locate Me'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.map),
                    label: const Text('Set on Map'),
                  ),
                ],
              ),
              if (_location != null) Text('Location: $_location'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  prefixIcon: Icon(Icons.fitness_center),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    return double.tryParse(value) == null
                        ? 'Weight must be a number'
                        : null;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  prefixIcon: Icon(Icons.height),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    return double.tryParse(value) == null
                        ? 'Height must be a number'
                        : null;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hairColorController,
                decoration: const InputDecoration(
                  labelText: 'Hair Color',
                  prefixIcon: Icon(Icons.color_lens),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eyeColorController,
                decoration: const InputDecoration(
                  labelText: 'Eye Color',
                  prefixIcon: Icon(Icons.remove_red_eye),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _markupController,
                decoration: const InputDecoration(
                  labelText: 'Markup',
                  prefixIcon: Icon(Icons.bookmark),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _skinColorController,
                decoration: const InputDecoration(
                  labelText: 'Skin Color',
                  prefixIcon: Icon(Icons.colorize),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _policeReportController,
                decoration: const InputDecoration(
                  labelText: 'Police Report Number',
                  prefixIcon: Icon(Icons.report),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bonusController,
                decoration: const InputDecoration(
                  labelText: 'Reward (Optional)',
                  prefixIcon: Icon(Icons.monetization_on),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    return double.tryParse(value) == null
                        ? 'Reward must be a number'
                        : null;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _submitReport,
                          child: Text(
                            _existingReport == null ? 'Post' : 'Update',
                          ),
                        ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _hairColorController.dispose();
    _eyeColorController.dispose();
    _markupController.dispose();
    _skinColorController.dispose();
    _policeReportController.dispose();
    _bonusController.dispose();
    super.dispose();
  }
}
