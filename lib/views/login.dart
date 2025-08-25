import 'package:aerohealth/views/dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final TextEditingController _emailCreateController = TextEditingController();
  final TextEditingController _passwordCreateController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _emailLoginController = TextEditingController();
  final TextEditingController _passwordLoginController = TextEditingController();

  // State variables
  bool _showCreatePassword = false;
  bool _showConfirmPassword = false;
  bool _showLoginPassword = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _acceptTerms = false;

  Future<void> _initializeFirebase() async {
    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp();

      // Wait for Firebase Auth to be ready
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if Firebase Auth is ready
      final auth = FirebaseAuth.instance;
      debugPrint("Firebase Auth initialized: ${auth.currentUser?.uid ?? 'No user'}");

    } catch (e) {
      debugPrint("Firebase initialization error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeFirebase();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        _emailLoginController.text = prefs.getString('savedEmail') ?? '';
        _passwordLoginController.text = prefs.getString('savedPassword') ?? '';
      }
    });
  }

  @override
  void dispose() {
    _emailCreateController.dispose();
    _passwordCreateController.dispose();
    _confirmPasswordController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 32, 0, 16),
                child: Text(
                  'AeroHealth',
                  style: GoogleFonts.roboto(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF101213),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 530),
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE0E3E7),
                            width: 2,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: const Color(0xFF101213),
                          unselectedLabelColor: const Color(0xFF57636C),
                          labelStyle: GoogleFonts.roboto(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          unselectedLabelStyle: GoogleFonts.roboto(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          tabs: const [
                            Tab(text: 'Create Account'),
                            Tab(text: 'Log In'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Create Account Tab
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create Account',
                                      style: GoogleFonts.roboto(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF101213),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Let\'s get started by filling out the form below.',
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF57636C),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildEmailField(
                                      _emailCreateController,
                                      'Email',
                                      isLogin: false,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildPasswordField(
                                      controller: _passwordCreateController,
                                      label: 'Password',
                                      showPassword: _showCreatePassword,
                                      onToggle: () => setState(
                                            () => _showCreatePassword = !_showCreatePassword,
                                      ),
                                      isLogin: false,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPasswordStrengthIndicator(_passwordCreateController.text),
                                    const SizedBox(height: 8),
                                    _buildPasswordField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirm Password',
                                      showPassword: _showConfirmPassword,
                                      onToggle: () => setState(
                                            () => _showConfirmPassword = !_showConfirmPassword,
                                      ),
                                      isLogin: false,
                                      validator: (value) {
                                        if (value != _passwordCreateController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _acceptTerms,
                                          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'I agree to the Terms and Conditions',
                                            style: GoogleFonts.roboto(
                                              fontSize: 14,
                                              color: const Color(0xFF57636C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _createAccount,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4B39EF),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const CircularProgressIndicator(color: Colors.white)
                                            : Text(
                                          'Get Started',
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSocialLoginButtons(),
                                  ],
                                ),
                              ),
                            ),

                            // Login Tab
                            SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Back',
                                    style: GoogleFonts.roboto(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF101213),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fill out the information below to access your account.',
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF57636C),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildEmailField(
                                    _emailLoginController,
                                    'Email',
                                    isLogin: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPasswordField(
                                    controller: _passwordLoginController,
                                    label: 'Password',
                                    showPassword: _showLoginPassword,
                                    onToggle: () => setState(
                                          () => _showLoginPassword = !_showLoginPassword,
                                    ),
                                    isLogin: true,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) async {
                                          setState(() => _rememberMe = value ?? false);
                                          final prefs = await SharedPreferences.getInstance();
                                          await prefs.setBool('rememberMe', _rememberMe);
                                        },
                                      ),
                                      Text(
                                        'Remember me',
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          color: const Color(0xFF57636C),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _resetPassword,
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.roboto(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF101213),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4B39EF),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : Text(
                                        'Sign In',
                                        style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSocialLoginButtons(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(TextEditingController controller, String label, {required bool isLogin}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          color: const Color(0xFF57636C),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4B39EF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      style: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: const Color(0xFF101213),
        fontSize: 16,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
    required bool isLogin,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          color: const Color(0xFF57636C),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4B39EF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF57636C),
          ),
          onPressed: onToggle,
        ),
      ),
      style: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        color: const Color(0xFF101213),
        fontSize: 16,
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: strength / 4,
          backgroundColor: Colors.grey[200],
          color: strength < 2
              ? Colors.red
              : strength < 4
              ? Colors.orange
              : Colors.green,
        ),
        const SizedBox(height: 4),
        Text(
          strength < 2
              ? 'Weak password'
              : strength < 4
              ? 'Good password'
              : 'Strong password',
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: strength < 2
                ? Colors.red
                : strength < 4
                ? Colors.orange
                : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Or continue with',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w500,
            color: const Color(0xFF57636C),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red),
              onPressed: _isLoading ? null : _signInWithGoogle,
            ),
            const SizedBox(width: 16),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showSnackBar('Please accept the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailCreateController.text.trim();
    final password = _passwordCreateController.text;

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user?.sendEmailVerification();

      _showSnackBar('Account created! Please verify your email.');
      _tabController.animateTo(1);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailLoginController.text.trim();
      final password = _passwordLoginController.text;

      // Verify Firebase is initialized
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint("Firebase already initialized");
      }

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Check email verification
      if (!userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
        throw FirebaseAuthException(
          code: 'unverified-email',
          message: 'Please verify your email first',
        );
      }

      // Save credentials if remember me is checked
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedEmail', email);
        await prefs.setString('savedPassword', password);
      }

      _navigateToDashboard();

    } on FirebaseAuthException catch (e) {
      _showSnackBar(_getFirebaseErrorMessage(e));
    } catch (e) {
      _showSnackBar('Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      print("Starting Google sign-in...");

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showSnackBar('Sign-in aborted by user.');
        return;
      }

      print("Google user: ${googleUser.email}");

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print("Access token: ${googleAuth.accessToken}");
      print("ID token: ${googleAuth.idToken}");

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      print("Signed in successfully!");
      _navigateToDashboard();
    } catch (e, st) {
      print("Google sign-in error: $e");
      print("Stack trace: $st");
      _showSnackBar('Google sign in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      // Implement Facebook login logic
      // Note: Requires additional setup with Facebook Developer account
      _showSnackBar('Facebook login not yet implemented');
    } catch (e) {
      _showSnackBar('Facebook login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailLoginController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email first');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Error: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred');
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    final navigatorContext = _scaffoldKey.currentContext ?? context;
    if (!mounted) return;

    Navigator.of(navigatorContext).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}



