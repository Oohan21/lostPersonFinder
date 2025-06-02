import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  final _apiService = ApiService();

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        print(
          'Registering with name: ${_nameController.text}, email: ${_emailController.text}, password: ${_passwordController.text}',
        );
        await _apiService.register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        print('Registration error: $_error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Register',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Password is required'
                            : null,
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _register,
                    child: const Text('Register'),
                  ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Already have an account? Login'),
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
    _passwordController.dispose();
    super.dispose();
  }
}
