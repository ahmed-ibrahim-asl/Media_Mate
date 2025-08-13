// lib/authentication/signIn_screen.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:media_mate/authentication/signUp_screen.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/app_state.dart';

class SignInScreenWidget extends StatefulWidget {
  const SignInScreenWidget({super.key});

  static String routeName = 'signIn_screen';
  static String routePath = '/signInScreen';

  @override
  State<SignInScreenWidget> createState() => _SignInScreenWidgetState();
}

class _SignInScreenWidgetState extends State<SignInScreenWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;

  bool _passwordVisible = false;
  bool _loading = false;

  static const String _usersCollection = 'users';
  static const String _userTypeField = 'user_type';

  // keep one instance to control sign-out/chooser
  final _gsi = gsi.GoogleSignIn(scopes: const ['email']);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------- Role helpers ----------

  String _roleCollection(String type) =>
      type == 'doctor' ? 'doctors' : 'patients';

  Future<bool> _ensureAccountForRole(User user, String expectedType) async {
    final db = FirebaseFirestore.instance;
    final uid = user.uid;

    final usersRef = db.collection(_usersCollection).doc(uid);
    final roleRef = db.collection(_roleCollection(expectedType)).doc(uid);
    final otherRef = db
        .collection(
          _roleCollection(expectedType == 'doctor' ? 'patient' : 'doctor'),
        )
        .doc(uid);

    final results = await Future.wait([
      usersRef.get(),
      roleRef.get(),
      otherRef.get(),
    ]);
    final userDoc = results[0];
    final roleDoc = results[1];
    final otherDoc = results[2];

    if (otherDoc.exists) {
      _showSnack(
        'This Google account is already registered as '
        '${expectedType == "doctor" ? "patient" : "doctor"}.',
      );
      return false;
    }

    // Backfill and normalize when the role doc already exists
    if (roleDoc.exists) {
      final Map<String, dynamic> userUpdates = {};
      if (!userDoc.exists ||
          (userDoc.data()?[_userTypeField] != expectedType)) {
        userUpdates[_userTypeField] = expectedType;
      }
      final dn = (user.displayName ?? '').trim();
      final currentUserDN =
          (userDoc.data()?['display_name'] ?? '').toString().trim();
      if (dn.isNotEmpty && currentUserDN.isEmpty) {
        userUpdates['display_name'] = dn;
      }
      if (userUpdates.isNotEmpty) {
        await usersRef.set(userUpdates, SetOptions(merge: true));
      }

      final currentRoleDN =
          (roleDoc.data()?['display_name'] ?? '').toString().trim();
      if (dn.isNotEmpty && currentRoleDN.isEmpty) {
        await roleRef.set({'display_name': dn}, SetOptions(merge: true));
      }
      return true;
    }

    // Create missing docs using display_name
    final batch = db.batch();
    final displayName = user.displayName ?? '';
    final email = user.email ?? '';

    if (!userDoc.exists) {
      batch.set(usersRef, {
        _userTypeField: expectedType,
        'email': email,
        'display_name': displayName,
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(usersRef, {
        _userTypeField: expectedType,
        'display_name': displayName, // ensure it exists for existing users
      }, SetOptions(merge: true));
    }

    batch.set(roleRef, {
      'display_name': displayName,
      'email': email,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return true;
  }

  // ---------- Google helpers ----------

  Future<void> _forceGoogleChooser() async {
    // On mobile, ensure no cached account remains selected
    try {
      await _gsi.disconnect();
    } catch (_) {
      // disconnect can throw if not signed in – fall back
      await _gsi.signOut();
    }
  }

  Future<void> _fullSignOutGoogleAndFirebase() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _forceGoogleChooser();
    } catch (_) {}
  }

  // ---------- Email & Google sign-in ----------

  Future<void> _signInWithEmail(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final expectedType = context.read<AppState>().userType;
    if (expectedType.isEmpty) {
      _showSnack('Please select user type first.');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final ok = await _ensureAccountForRole(cred.user!, expectedType);
      if (!ok) {
        await _fullSignOutGoogleAndFirebase();
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main-nav-bar');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Authentication failed.');
    } catch (e) {
      _showSnack('Sign-in error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final expectedType = context.read<AppState>().userType;
    if (expectedType.isEmpty) {
      _showSnack('Please select user type first.');
      return;
    }

    setState(() => _loading = true);
    try {
      UserCredential cred;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        // Always show the chooser on web
        provider.setCustomParameters({'prompt': 'select_account'});
        cred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Ensure chooser appears on mobile by clearing previous selection
        await _forceGoogleChooser();

        final account = await _gsi.signIn();
        if (account == null) {
          if (mounted) setState(() => _loading = false);
          return; // user cancelled
        }

        final auth = await account.authentication;
        final oAuthCred = GoogleAuthProvider.credential(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
        cred = await FirebaseAuth.instance.signInWithCredential(oAuthCred);
      }

      final ok = await _ensureAccountForRole(cred.user!, expectedType);
      if (!ok) {
        await _fullSignOutGoogleAndFirebase();
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main-nav-bar');
    } on FirebaseAuthException catch (e) {
      // If this fails, clear sessions so next attempt shows chooser
      await _fullSignOutGoogleAndFirebase();
      _showSnack(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      await _fullSignOutGoogleAndFirebase();
      _showSnack('Google sign-in error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Misc ----------

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Email required to reset password!');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Could not send reset email.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<AppState>().userType;
    final description =
        userType == 'doctor'
            ? 'Sign in to your Doctor account'
            : 'Sign in to your Patient account';

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        resizeToAvoidBottomInset: true,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24.0,
                    0.0,
                    24.0,
                    (bottomInset > 0 ? bottomInset : 32.0) + 16.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: 15.0,
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  splashColor: Colors.transparent,
                                  onTap: () async {
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );
                                    if (!mounted) return;
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/selectUserScreen');
                                  },
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF62686D),
                                    size: 36.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(
                              'assets/images/media_app_icon.png',
                              width: 200.0,
                              height: 156.2,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280),
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  autofocus: true,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'Email address',
                                    hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFF6B7280),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Color(0xFF327BF1),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    contentPadding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          16.0,
                                          16.0,
                                          16.0,
                                          16.0,
                                        ),
                                  ),
                                  style: GoogleFonts.inter(fontSize: 15.0),
                                  validator: (v) {
                                    final val = v?.trim() ?? '';
                                    if (val.isEmpty) return 'Email is required';
                                    if (!RegExp(
                                      r'^[^@]+@[^@]+\.[^@]+',
                                    ).hasMatch(val)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20.0),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  obscureText: !_passwordVisible,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFF6B7280),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE5E7EB),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Color(0xFF327BF1),
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FAFB),
                                    contentPadding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          16.0,
                                          16.0,
                                          16.0,
                                          16.0,
                                        ),
                                    suffixIcon: InkWell(
                                      onTap:
                                          () => setState(
                                            () =>
                                                _passwordVisible =
                                                    !_passwordVisible,
                                          ),
                                      child: Icon(
                                        _passwordVisible
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  style: GoogleFonts.inter(fontSize: 15.0),
                                  validator: (v) {
                                    if ((v ?? '').isEmpty) {
                                      return 'Password is required';
                                    }
                                    if ((v ?? '').length < 6) {
                                      return 'Min 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: _sendPasswordReset,
                              child: Text(
                                'Forgot Password?',
                                textAlign: TextAlign.end,
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          SizedBox(
                            width: double.infinity,
                            height: 52.0,
                            child: ElevatedButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : () => _signInWithEmail(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF327BF1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child:
                                  _loading
                                      ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                      : Text(
                                        'Sign In',
                                        style: GoogleFonts.inter(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1.0,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  'or',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 14.0,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1.0,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            height: 52.0,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _loading
                                      ? null
                                      : () => _signInWithGoogle(context),
                              icon: Padding(
                                padding: const EdgeInsets.only(left: 2.0),
                                child: Image.asset(
                                  'assets/images/google_g.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF9FAFB),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              label: Text(
                                'Continue with Google',
                                style: GoogleFonts.inter(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 14.0,
                                  ),
                                ),
                                const SizedBox(width: 4.0),
                                InkWell(
                                  onTap: () async {
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );
                                    if (!mounted) return;
                                    Navigator.of(
                                      context,
                                    ).pushNamed('/signUpScreen');
                                  },
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF327BF1),
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
