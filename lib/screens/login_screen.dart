import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum _LoginView { roleSelection, admin, judge }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navy = Color(0xFF10183E);
  static const _indigo = Color(0xFF3034A8);
  static const _indigoLight = Color(0xFF4B50D7);
  static const _coral = Color(0xFFD92D38);
  static const _coralLight = Color(0xFFE8515A);
  static const _mutedText = Color(0xFF69709A);
  static const _fieldFill = Color(0xFFF8F9FF);
  static const _fieldBorder = Color(0xFFD5D9EE);

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  _LoginView _view = _LoginView.roleSelection;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _selectView(_LoginView view) {
    setState(() {
      _view = view;
      _usernameController.clear();
      _passwordController.clear();
      _obscurePassword = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _usernameFocusNode.requestFocus();
    });
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    setState(() {
      _view = _LoginView.roleSelection;
      _usernameController.clear();
      _passwordController.clear();
      _obscurePassword = true;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _loginAsHardcodedAdmin() {
    FocusScope.of(context).unfocus();
    if (_usernameController.text.trim() == 'admin' &&
        _passwordController.text == 'admin123') {
      Navigator.pushReplacementNamed(context, '/admin_home');
    } else {
      _showMessage('Invalid admin credentials');
    }
  }

  Future<void> _loginAsJudge() async {
    FocusScope.of(context).unfocus();
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showMessage('Please enter a username');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final snapshot = await _database.child('judges/$username').get();
      if (!mounted) return;

      if (snapshot.exists) {
        Navigator.pushNamed(context, '/judge_home', arguments: username);
      } else {
        _showMessage('Invalid username. Please contact the admin.');
      }
    } catch (error) {
      debugPrint('Error validating judge username: $error');
      if (mounted) {
        _showMessage('An error occurred. Please try again later.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            right: -120,
            child: _BackgroundOrb(size: 430),
          ),
          const Positioned(
            bottom: -210,
            left: -170,
            child: _BackgroundOrb(size: 470),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth < 600 ? 20.0 : 36.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 56,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildLoginCard(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F43528A),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            const Positioned(
              top: -74,
              right: -74,
              child: _CardDecoration(size: 168),
            ),
            const Positioned(
              bottom: -82,
              left: -82,
              child: _CardDecoration(size: 175),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 42, 38, 34),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLockMark(),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to Judging App',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _navy,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        _subtitle,
                        key: ValueKey(_view),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 38),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.03, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _view == _LoginView.roleSelection
                          ? _buildRoleSelection()
                          : _buildLoginForm(
                              isAdmin: _view == _LoginView.admin,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    switch (_view) {
      case _LoginView.admin:
        return 'Log in to your admin account';
      case _LoginView.judge:
        return 'Log in to your judge account';
      case _LoginView.roleSelection:
        return 'Choose how you want to sign in.';
    }
  }

  Widget _buildLockMark() {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143034A8),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_outline_rounded,
        color: _indigo,
        size: 47,
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      key: const ValueKey('role-selection'),
      children: [
        _GradientActionButton(
          label: 'Admin Login',
          leadingIcon: Icons.manage_accounts_rounded,
          colors: const [_indigoLight, _indigo],
          onPressed: () => _selectView(_LoginView.admin),
        ),
        const SizedBox(height: 20),
        _GradientActionButton(
          label: 'Judge Login',
          leadingIcon: Icons.person_rounded,
          colors: const [_coralLight, _coral],
          onPressed: () => _selectView(_LoginView.judge),
        ),
      ],
    );
  }

  Widget _buildLoginForm({required bool isAdmin}) {
    return Column(
      key: ValueKey(isAdmin ? 'admin-form' : 'judge-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Username'),
        const SizedBox(height: 9),
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          textInputAction:
              isAdmin ? TextInputAction.next : TextInputAction.done,
          autofillHints: const [AutofillHints.username],
          onSubmitted: (_) {
            if (isAdmin) {
              _passwordFocusNode.requestFocus();
            } else if (!_isLoading) {
              _loginAsJudge();
            }
          },
          decoration: _fieldDecoration(
            hint: 'Enter Username',
            icon: Icons.person_rounded,
          ),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 22),
          _buildFieldLabel('Password'),
          const SizedBox(height: 9),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _loginAsHardcodedAdmin(),
            decoration: _fieldDecoration(
              hint: 'Enter Password',
              icon: Icons.lock_rounded,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _mutedText,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        _GradientActionButton(
          label: isAdmin ? 'Login as Admin' : 'Login as Judge',
          leadingIcon: Icons.login_rounded,
          colors: const [_indigoLight, _indigo],
          showTrailingArrow: false,
          isLoading: _isLoading,
          onPressed: _isLoading
              ? null
              : (isAdmin ? _loginAsHardcodedAdmin : _loginAsJudge),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: _isLoading ? null : _goBack,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: _indigo,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _navy,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF858BAD),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: _mutedText, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(_fieldBorder, 1.4),
      enabledBorder: border(_fieldBorder, 1.4),
      focusedBorder: border(_indigoLight, 2),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.leadingIcon,
    required this.colors,
    required this.onPressed,
    this.showTrailingArrow = true,
    this.isLoading = false,
  });

  final String label;
  final IconData leadingIcon;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool showTrailingArrow;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            width: double.infinity,
            height: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Icon(leadingIcon, color: Colors.white, size: 25),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (showTrailingArrow)
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 27,
                          )
                        else
                          const SizedBox(width: 27),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  const _BackgroundOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x6698A7FF),
      ),
    );
  }
}

class _CardDecoration extends StatelessWidget {
  const _CardDecoration({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x7FE9EDFF),
      ),
    );
  }
}
