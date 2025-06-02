import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  final _apiService = ApiService();

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final email = _emailController.text.trim().toLowerCase();
        print('Attempting login with email: $email');
        await _apiService.login(email, _passwordController.text);
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (errorMessage.contains('Invalid email or password')) {
          errorMessage = 'Incorrect email or password. Please try again.';
        } else if (errorMessage.contains('Not authenticated')) {
          errorMessage = 'Session expired. Please log in again.';
        }
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
        print('Login error: $errorMessage');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Login',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                        value == null || value.trim().isEmpty
                            ? 'Password is required'
                            : null,
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Don\'t have an account? Register'),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
