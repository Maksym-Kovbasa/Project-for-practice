import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'demo.dart';
import 'auth/firestore_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE8EEF8),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialSignIn = true});

  final bool initialSignIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignIn = true;
  bool _isSubmitting = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _authService = FirestoreAuthService.instance;

  static const Color _background = Color(0xFFE8EEF8);
  static const Color _cardBackground = Color(0xFFEAF0F8);
  static const Color _accent = Color(0xFF1EC8B5);
  static const Color _textPrimary = Color(0xFF22344A);
  static const Color _textHint = Color(0xFF7B8A9F);
  static const Color _fieldHint = Color(0xFF8A9AAF);
  static const Duration _switchDuration = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    _isSignIn = widget.initialSignIn;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setMode(bool isSignIn) {
    if (_isSignIn == isSignIn) {
      return;
    }
    setState(() {
      _isSignIn = isSignIn;
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _hidePassword = true;
      _hideConfirmPassword = true;
    });
  }

  void _toggleMode() {
    _setMode(!_isSignIn);
  }

  Future<void> _handleAuthAction() async {
    if (_isSubmitting) {
      return;
    }
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username and password are required.');
      return;
    }
    if (!_isSignIn) {
      if (email.isEmpty) {
        _showMessage('Email address is required.');
        return;
      }
      if (!_isValidEmail(email)) {
        _showMessage('Please enter a valid email address.');
        return;
      }
      if (password != confirmPassword) {
        _showMessage('Passwords do not match.');
        return;
      }
      if (password.length < 6) {
        _showMessage('Password must be at least 6 characters.');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isSignIn) {
        final user = await _authService.login(
          username: username,
          password: password,
        );
        if (!mounted) {
          return;
        }
        _goToDashboard();
      } else {
        final user = await _authService.register(
          username: username,
          email: email,
          password: password,
        );
        if (!mounted) {
          return;
        }
        _goToRegistrationSuccess(user.username);
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goToRegistrationSuccess(String username) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RegistrationSuccessScreen(username: username),
      ),
    );
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DemoScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String email) {
    const emailPattern = r'^[\w\.\-]+@[\w\-]+\.[A-Za-z]{2,}$';
    return RegExp(emailPattern).hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2F7FF), Color(0xFFE3EBF7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 402),
                child: _buildCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-8, -8),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Color(0xB5C8D5EA),
            offset: Offset(8, 8),
            blurRadius: 18,
          ),
        ],
        border: Border.all(color: const Color(0xFFD6E0EE)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: _switchDuration,
            child: Text(
              _isSignIn ? 'Sign In' : 'Sign Up',
              key: ValueKey<String>('title-$_isSignIn'),
              style: const TextStyle(
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: _switchDuration,
            child: Text(
              _isSignIn ? 'Welcome back' : 'Create your account',
              key: ValueKey<String>('subtitle-$_isSignIn'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textHint,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _modeSwitch(),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: _switchDuration,
            curve: Curves.easeInOut,
            child: Column(
              children: [
                _inputField(
                  icon: Icons.person_outline_rounded,
                  hint: 'username',
                  controller: _usernameController,
                ),
                if (!_isSignIn) ...[
                  const SizedBox(height: 14),
                  _inputField(
                    icon: Icons.mail_outline_rounded,
                    hint: 'email address',
                    controller: _emailController,
                  ),
                ],
                const SizedBox(height: 14),
                _inputField(
                  icon: Icons.lock_outline_rounded,
                  hint: 'password',
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _fieldHint,
                    ),
                  ),
                ),
                if (!_isSignIn) ...[
                  const SizedBox(height: 14),
                  _inputField(
                    icon: Icons.lock_outline_rounded,
                    hint: 'confirm password',
                    controller: _confirmPasswordController,
                    obscureText: _hideConfirmPassword,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _hideConfirmPassword = !_hideConfirmPassword,
                        );
                      },
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _fieldHint,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: _switchDuration,
            child: _primaryButton(
              _isSignIn ? 'Login' : 'Create Account',
              key: ValueKey<String>('cta-$_isSignIn'),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Or continue with',
            style: TextStyle(
              color: _textHint,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _socialButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Google',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _socialButton(
                  icon: Icons.facebook_rounded,
                  label: 'Facebook',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _toggleMode,
            child: AnimatedSwitcher(
              duration: _switchDuration,
              child: Text(
                _isSignIn
                    ? "Don't have an account? Sign Up"
                    : 'Already have an account? Sign In',
                key: ValueKey<String>('footer-$_isSignIn'),
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-3, -3),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0xB5C8D5EA),
            offset: Offset(3, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _switchItem('Sign In', _isSignIn)),
          Expanded(child: _switchItem('Sign Up', !_isSignIn)),
        ],
      ),
    );
  }

  Widget _switchItem(String label, bool selected) {
    return GestureDetector(
      onTap: () => _setMode(label == 'Sign In'),
      child: AnimatedContainer(
        duration: _switchDuration,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? const [
            BoxShadow(
              color: Color(0x9926D9C5),
              offset: Offset(0, 5),
              blurRadius: 12,
            ),
          ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF39506B),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6DFED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Color(0xB7C6D4E8),
            offset: Offset(4, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: Icon(icon, color: _accent),
          suffixIcon: suffixIcon,
          hintText: hint,
          hintStyle: const TextStyle(color: _fieldHint),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, {Key? key}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleAuthAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: _textPrimary),
        label: Text(
          label,
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCAD8EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: _background,
        ),
      ),
    );
  }
}

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF2F7FF), Color(0xFFE3EBF7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 402),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0F8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD6E0EE)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFFFFFFF),
                        offset: Offset(-8, -8),
                        blurRadius: 18,
                      ),
                      BoxShadow(
                        color: Color(0xB5C8D5EA),
                        offset: Offset(8, 8),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7FBF7),
                          borderRadius: BorderRadius.circular(47),
                          border: Border.all(color: const Color(0xFFC6EEE7)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3620CDBA),
                              offset: Offset(0, 8),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 52,
                          color: Color(0xFF20CDBA),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Registration Successful',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22344A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account "$username" was created.\nPlease sign in to continue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7B8A9F),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => DemoScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20CDBA),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(initialSignIn: true),
                              ),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF3FB),
                            side: const BorderSide(color: Color(0xFFD6DFED)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF39506B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
