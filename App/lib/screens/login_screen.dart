import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';




class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _emailController.text.trim(); // email OR phone
    final password = _passwordController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logging in...")),
    );

    try {
      final result = await AuthService.login(
        identifier: identifier,
        password: password,
      );

      final token = result['access_token'] as String;
      await TokenStorage.saveToken(token);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logoPath = isDark
        ? 'assets/images/khaadim_logo_dark.png'
        : 'assets/images/khaadim_logo_light.png';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /////// LOGO /////
              Image.asset(
                logoPath,
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 16),
              Text(
                "Welcome Back",
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Login to your Khaadim account",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              /////// FORM ///////
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /////// EMAIL FIELD ///////
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email or Phone",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter email or phone";
                        }
                        if (value.contains("@")) {
                          if (!value.contains(".")) return "Enter a valid email address";
                        } else {
                          if (value.length < 8) return "Enter a valid phone number";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    /////// PASSWORD FIELD ///////
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your password";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    /////// LOGIN BUTTON ///////
                    ElevatedButton(
                      onPressed: _handleLogin,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text("Login"),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /////// SIGNUP LINK ///////
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "Sign Up",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
}
