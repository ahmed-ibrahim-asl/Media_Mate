//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:media_mate/theme/colors.dart';
import 'package:provider/provider.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import '/app_state.dart';
//----------------------------------------------------------------------

class SignUpScreenWidget extends StatefulWidget {
  const SignUpScreenWidget({super.key});

  static String routeName = 'signUp_screen';
  static String routePath = '/signUpScreen';

  @override
  State<SignUpScreenWidget> createState() => _SignUpScreenWidgetState();
}

class _SignUpScreenWidgetState extends State<SignUpScreenWidget> {
  // form & ui
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  // controllers
  late final TextEditingController fullNameController;
  late final TextEditingController phoneController;
  late final TextEditingController dobController;
  late final TextEditingController specialtyController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  late final TextEditingController confirmPasswordController;

  // focus nodes
  late final FocusNode fullNameFocus;
  late final FocusNode phoneFocus;
  late final FocusNode dobFocus;
  late final FocusNode specialtyFocus;
  late final FocusNode emailFocus;
  late final FocusNode passwordFocus;
  late final FocusNode confirmPasswordFocus;

  // masks
  late final MaskTextInputFormatter dobMask;
  late final MaskTextInputFormatter phoneMask;

  // small ui states
  bool passwordVisible1 = false;
  bool passwordVisible2 = false;
  String gender = 'Female'; // default

  @override
  void initState() {
    super.initState();

    // controllers
    fullNameController = TextEditingController();
    phoneController = TextEditingController();
    dobController = TextEditingController();
    specialtyController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();

    // focuses
    fullNameFocus = FocusNode();
    phoneFocus = FocusNode();
    dobFocus = FocusNode();
    specialtyFocus = FocusNode();
    emailFocus = FocusNode();
    passwordFocus = FocusNode();
    confirmPasswordFocus = FocusNode();

    // masks
    dobMask = MaskTextInputFormatter(mask: '##/##/####');
    phoneMask = MaskTextInputFormatter(mask: '+## ### ### #######');
  }

  @override
  void dispose() {
    // dispose controllers
    fullNameController.dispose();
    phoneController.dispose();
    dobController.dispose();
    specialtyController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    // dispose focuses
    fullNameFocus.dispose();
    phoneFocus.dispose();
    dobFocus.dispose();
    specialtyFocus.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();

    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<void> _onSignUpPressed() async {
    final userType =
        context.read<AppState>().userType; // 'doctor' | 'patient' | ''
    if (userType.isEmpty) {
      _snack('Please choose Doctor or Patient first.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Parse DOB safely
    DateTime dob;
    try {
      dob = DateFormat('dd/MM/yyyy').parseStrict(dobController.text);
    } catch (_) {
      _snack('Invalid Date of Birth. Use DD/MM/YYYY.');
      return;
    }
    final dobTs = Timestamp.fromDate(dob);

    final email = emailController.text.trim();
    final password = passwordController.text;
    final name = fullNameController.text.trim();
    final phone = _digits(phoneController.text);
    final g = gender; // 'Male' or 'Female'
    final specialty = specialtyController.text.trim();

    setState(() => _busy = true);
    try {
      // 1) Create auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // Update displayName (optional)
      await cred.user!.updateDisplayName(name);

      // 2) Write Firestore: users + role doc (idempotent)
      final db = FirebaseFirestore.instance;

      await db.collection('users').doc(uid).set({
        'display_name': name,
        'email': email,
        'phone_number': phone,
        'date_of_birth': dobTs,
        'gender': g,
        'user_type': userType,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final roleColl = userType == 'doctor' ? 'doctors' : 'patients';
      final roleData = <String, dynamic>{
        'display_name': name,
        'email': email,
        'phone_number': phone,
        'date_of_birth': dobTs,
        'gender': g,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (userType == 'doctor') {
        roleData['specialty'] = specialty;
      }

      await db
          .collection(roleColl)
          .doc(uid)
          .set(roleData, SetOptions(merge: true));

      // 3) Navigate to your app shell (uses existing route from main.dart)
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/main-nav-bar', (_) => false);
    } on FirebaseAuthException catch (e) {
      // friendlier messages
      switch (e.code) {
        case 'email-already-in-use':
          _snack('This email is already in use.');
          break;
        case 'invalid-email':
          _snack('That email address looks invalid.');
          break;
        case 'weak-password':
          _snack('Password is too weak (min 6 characters).');
          break;
        default:
          _snack(e.message ?? 'Could not create account.');
      }
    } on FirebaseException catch (e) {
      _snack('Database error: ${e.message}');
    } catch (e) {
      _snack('Sign up failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<AppState>().userType; // listen to app state
    final isDoctor = userType == 'doctor';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.fill,
                image: AssetImage('assets/images/Background_image.png'),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  children:
                      [
                        // Back
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF62686D),
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/media_app_icon.png',
                            width: 200,
                            height: 156.2,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Warn if userType not set
                        if (userType.isEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFEEBA),
                              ),
                            ),
                            child: const Text(
                              'Please pick Doctor or Patient first.',
                              style: TextStyle(color: Color(0xFF856404)),
                            ),
                          ),

                        // Full Name
                        _Input(
                          controller: fullNameController,
                          focusNode: fullNameFocus,
                          hint: 'Full Name',
                          keyboardType: TextInputType.name,
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty)
                              return 'Full name is required';
                            return null;
                          },
                        ),

                        // Phone
                        _Input(
                          controller: phoneController,
                          focusNode: phoneFocus,
                          hint: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [phoneMask],
                          validator: (v) {
                            final raw = _digits(v ?? '');
                            if (raw.length < 8) return 'Enter a valid phone';
                            return null;
                          },
                        ),

                        // DOB
                        _Input(
                          controller: dobController,
                          focusNode: dobFocus,
                          hint: 'Date of Birth (DD/MM/YYYY)',
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [dobMask],
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.length != 10) return 'Use DD/MM/YYYY';
                            try {
                              DateFormat('dd/MM/yyyy').parseStrict(t);
                              return null;
                            } catch (_) {
                              return 'Invalid date';
                            }
                          },
                        ),

                        // Specialty (doctor only)
                        if (isDoctor)
                          _Input(
                            controller: specialtyController,
                            focusNode: specialtyFocus,
                            hint: 'Specialty',
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty)
                                return 'Specialty is required';
                              return null;
                            },
                          ),

                        // Email
                        _Input(
                          controller: emailController,
                          focusNode: emailFocus,
                          hint: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return 'Email is required';
                            final ok = RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(val);
                            if (!ok) return 'Enter a valid email';
                            return null;
                          },
                        ),

                        // Password
                        _Input(
                          controller: passwordController,
                          focusNode: passwordFocus,
                          hint: 'Password',
                          obscure: !passwordVisible1,
                          suffix: IconButton(
                            icon: Icon(
                              passwordVisible1
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed:
                                () => setState(() {
                                  passwordVisible1 = !passwordVisible1;
                                }),
                          ),
                          validator: (v) {
                            if ((v ?? '').length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),

                        // Confirm Password
                        _Input(
                          controller: confirmPasswordController,
                          focusNode: confirmPasswordFocus,
                          hint: 'Confirm Password',
                          obscure: !passwordVisible2,
                          suffix: IconButton(
                            icon: Icon(
                              passwordVisible2
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed:
                                () => setState(() {
                                  passwordVisible2 = !passwordVisible2;
                                }),
                          ),
                          validator: (v) {
                            if (v != passwordController.text) {
                              return 'Passwords don’t match';
                            }
                            return null;
                          },
                        ),

                        // Gender
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gender',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF83868D),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ToggleButtons(
                              isSelected: [
                                gender == 'Male',
                                gender == 'Female',
                              ],
                              onPressed: (i) {
                                setState(() {
                                  gender = (i == 0) ? 'Male' : 'Female';
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              constraints: const BoxConstraints(
                                minWidth: 100,
                                minHeight: 32,
                              ),
                              children: const [Text('Male'), Text('Female')],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Sign Up button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _onSignUpPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAlt,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _busy
                                    ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      'Sign Up',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Already have an account?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.inter(
                                  color: AppColors.primaryAlt,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ].expand((w) sync* {
                        yield w;
                        yield const SizedBox(height: 10);
                      }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.obscure = false,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF327BF1), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.all(16),
        suffixIcon: suffix,
      ),
      style: GoogleFonts.inter(fontSize: 15),
      validator: validator,
    );
  }
}
