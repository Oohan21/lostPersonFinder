import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'dart:typed_data';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  _UpdateProfilePageState createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _error;
  XFile? _profilePicture;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _apiService.getProfile(context);
      setState(() {
        _nameController.text = profile['name'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      print('Load profile error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      print('Image picked, bytes length: ${bytes.length}');
      setState(() {
        _profilePicture = pickedFile;
        _imageBytes = bytes;
        _error = null;
      });
    } else {
      setState(() {
        _error = 'No image selected';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        await _apiService.updateProfile(
          _nameController.text,
          _emailController.text,
          _phoneController.text,
          _profilePicture,
          context,
        );
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        print('Update profile error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Profile')),
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
                        _imageBytes == null
                            ? const Icon(Icons.camera_alt, size: 50)
                            : Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading image: $error');
                                return const Icon(
                                  Icons.error,
                                  size: 50,
                                  color: Colors.red,
                                );
                              },
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Name is required'
                            : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Email is required'
                            : !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)
                            ? 'Enter a valid email'
                            : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Phone number is required'
                            : null,
              ),
              const SizedBox(height: 16),
              Center(
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text('Update Profile'),
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
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
