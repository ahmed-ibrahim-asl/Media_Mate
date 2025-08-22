//---------------------------- flutter_core ----------------------------
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//----------------------------------------------------------------------

//------------------------------ firebase ------------------------------
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//----------------------------------------------------------------------

//-------------------------- google_packages ---------------------------
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
//----------------------------------------------------------------------

//-------------------------- state_management --------------------------
import 'package:provider/provider.dart';
//----------------------------------------------------------------------

//--------------------------- local_imports ----------------------------
import '/app_state.dart';
import '/Patient_Screens/searching_for_doctor_screen.dart';
//----------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = 'profile_screen';
  static const String routePath = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // palette to match your design
  static const _blue = Color(0xFF195E99);
  static const _orange = Color(0xFFD93C00);

  bool _busy = false;
  Map<String, dynamic>? _userDoc; // /users/{uid}
  Map<String, dynamic>? _roleDoc; // /patients or /doctors/{uid}

  User? get _user => FirebaseAuth.instance.currentUser;
  String get _uid => _user?.uid ?? '';
  String get _email => _user?.email ?? '—';
  String get _displayName => _user?.displayName ?? '—';

  // age bucket (not used for images anymore, but kept for display)
  static const int _oldAgeThreshold = 55;

  String _roleCollection(String role) =>
      role == 'doctor' ? 'doctors' : 'patients';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = _user;
    if (u == null) return; // signed out

    try {
      final appState = context.read<AppState>();

      // Always read /users first to discover role if app state doesn't have it
      final usersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid);
      final userSnap = await usersRef.get();
      final userData = userSnap.data();

      var role = appState.userType;
      final roleFromDb = (userData?['user_type'] as String?)?.trim() ?? '';
      if (role.isEmpty && roleFromDb.isNotEmpty) {
        appState.userType = roleFromDb; // hydrate app state
        role = roleFromDb;
      }

      Map<String, dynamic>? roleData;
      if (role.isNotEmpty) {
        final roleSnap =
            await FirebaseFirestore.instance
                .collection(_roleCollection(role))
                .doc(u.uid)
                .get();
        roleData = roleSnap.data();
      }

      if (!mounted) return;
      setState(() {
        _userDoc = userData;
        _roleDoc = roleData;
      });
    } catch (e) {
      _snack('Failed to load profile');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _updateUsers(Map<String, dynamic> data) async {
    if (_user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .set(data, SetOptions(merge: true));
    await _load();
  }

  Future<void> _updateRole(Map<String, dynamic> data) async {
    if (_user == null) return;
    var role = context.read<AppState>().userType;
    if (role.isEmpty) {
      // fall back to user document if needed
      role = ((_userDoc?['user_type'] as String?) ?? '').trim();
      if (role.isEmpty) return;
    }
    await FirebaseFirestore.instance
        .collection(_roleCollection(role))
        .doc(_uid)
        .set(data, SetOptions(merge: true));
    await _load();
  }

  // ---------------- Editors ----------------

  String _normalizedGender(String? g) {
    final v = (g ?? '').trim();
    if (v == 'Male' || v == 'Female') return v;
    return 'N/A';
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    TextInputType? keyboardType,
  }) async {
    final c = TextEditingController(text: initial);
    final isMultiline = keyboardType == TextInputType.multiline;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final base = Theme.of(dialogCtx);

        return Theme(
          data: base.copyWith(
            textTheme: GoogleFonts.interTextTheme(base.textTheme),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: BorderSide(color: _blue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
              labelStyle: GoogleFonts.inter(color: const Color(0xFF6B7280)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF222B32),
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TextField(
                controller: c,
                keyboardType: keyboardType,
                autofocus: true,
                textInputAction:
                    isMultiline
                        ? TextInputAction.newline
                        : TextInputAction.done,
                minLines: isMultiline ? 3 : 1,
                maxLines: isMultiline ? 4 : 1,
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(hintText: 'Enter $title'),
                onSubmitted: (_) async {
                  Navigator.pop(dialogCtx);
                  await onSave(c.text.trim());
                },
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await onSave(c.text.trim());
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editGender() async {
    // Only Male/Female allowed. Default to current if valid; otherwise Female.
    String current = _normalizedGender((_userDoc?['gender'] as String?));
    if (current != 'Male' && current != 'Female') current = 'Female';
    String temp = current;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final base = Theme.of(dialogCtx);
        final scheme = base.colorScheme.copyWith(
          primary: const Color(0xFF1766B9), // brand blue
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF222B32),
        );

        return Theme(
          data: base.copyWith(
            colorScheme: scheme,
            textTheme: GoogleFonts.interTextTheme(base.textTheme),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1766B9),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          child: StatefulBuilder(
            builder: (ctx, setSB) {
              Widget genderTile(String value, IconData icon) {
                final selected = temp == value;
                return InkWell(
                  onTap: () => setSB(() => temp = value),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0x141766B9) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected
                                ? const Color(0xFF1766B9)
                                : const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color:
                              selected
                                  ? const Color(0xFF1766B9)
                                  : const Color(0xFF9AA3AF),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            value,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF222B32),
                            ),
                          ),
                        ),
                        // custom radio indicator (matching app style)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected
                                      ? const Color(0xFF1766B9)
                                      : const Color(0xFF9AA3AF),
                              width: 2,
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  selected
                                      ? const Color(0xFF1766B9)
                                      : Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Text(
                  'Select gender',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222B32),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    genderTile('Male', Icons.male_rounded),
                    const SizedBox(height: 10),
                    genderTile('Female', Icons.female_rounded),
                    const SizedBox(height: 10),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1766B9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final gender =
                          (temp == 'Male' || temp == 'Female')
                              ? temp
                              : 'Female';
                      await _updateUsers({'gender': gender});
                      await _updateRole({'gender': gender});
                      _snack('Gender updated');
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editAgeViaDob() async {
    // derive age from DOB; let user pick DOB
    final ts =
        (_roleDoc?['date_of_birth'] ??
                _roleDoc?['dob'] ??
                _userDoc?['date_of_birth'] ??
                _userDoc?['dob'])
            as Timestamp?;

    final now = DateTime.now();
    final initial =
        ts != null ? ts.toDate() : DateTime(now.year - 30, now.month, now.day);
    final firstDate = DateTime(now.year - 120, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date of birth',
      confirmText: 'Save',
      cancelText: 'Cancel',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        final base = Theme.of(context);
        final scheme = base.colorScheme.copyWith(
          primary: const Color(0xFF1766B9), // header & selected day
          onPrimary: Colors.white, // text on primary
          surface: Colors.white, // dialog background
          onSurface: const Color(0xFF222B32),
        );

        return Theme(
          data: base.copyWith(
            colorScheme: scheme,
            textTheme: GoogleFonts.interTextTheme(base.textTheme),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1766B9),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            datePickerTheme: const DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              headerBackgroundColor: Color(0xFF1766B9),
              headerForegroundColor: Colors.white,
              dayShape: MaterialStatePropertyAll(CircleBorder()),
              todayForegroundColor: MaterialStatePropertyAll(Color(0xFF1766B9)),
              todayBackgroundColor: MaterialStatePropertyAll(Color(0x1A1766B9)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    await _updateUsers({'date_of_birth': Timestamp.fromDate(picked)});
    await _updateRole({'date_of_birth': Timestamp.fromDate(picked)});
    _snack('Date of birth updated');
  }

  // ---------------- Assign caregiver/doctor ----------------
  Future<void> _chooseDoctor() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(SearchingForDoctorScreenWidget.routePath);
    if (!mounted) return;

    if (result is Map) {
      // Clear selection
      if (result['clear'] == true) {
        await _updateRole({
          'assigned_doctor_id': FieldValue.delete(),
          'assigned_doctor_name': FieldValue.delete(),
          'assigned_doctor_photo_url': FieldValue.delete(),
        });
        _snack('Doctor assignment cleared.');
        return;
      }

      // Assign
      final id = result['id'] as String?;
      if (id != null && id.isNotEmpty) {
        await _updateRole({
          'assigned_doctor_id': id,
          'assigned_doctor_name': (result['name'] as String?) ?? '',
          'assigned_doctor_photo_url': (result['photoUrl'] as String?) ?? '',
        });
        _snack('Doctor assigned: ${result['name'] ?? ''}');
      }
    }
  }

  // ---------------- Logout & Deactivate ----------------
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!kIsWeb) {
        try {
          final g = gsi.GoogleSignIn();
          await g.disconnect();
          await g.signOut();
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        context.read<AppState>().userType = '';
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/selectUserScreen', (r) => false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => _DeactivateDialog(blue: _blue, orange: _orange),
        ) ??
        false;
    if (!ok) return;

    try {
      setState(() => _busy = true);
      final role =
          (context.read<AppState>().userType.isNotEmpty)
              ? context.read<AppState>().userType
              : ((_userDoc?['user_type'] as String?) ?? '');

      // Firestore best-effort cleanup
      if (role.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(_roleCollection(role))
            .doc(_uid)
            .delete()
            .catchError((_) {});
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .delete()
          .catchError((_) {});

      // Auth delete (may require recent login)
      final u = _user;
      if (u != null) {
        await u.delete();
      }

      if (!kIsWeb) {
        try {
          final g = gsi.GoogleSignIn();
          await g.disconnect();
          await g.signOut();
        } catch (_) {}
      }

      if (!mounted) return;
      context.read<AppState>().userType = '';
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/selectUserScreen', (r) => false);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _snack('Please sign out, sign in again, then retry account deletion.');
      } else {
        _snack('Failed to delete account: ${e.message}');
      }
    } catch (e) {
      _snack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------- Helpers ----------------

  int? _ageYears() {
    final ts =
        (_roleDoc?['date_of_birth'] ??
                _roleDoc?['dob'] ??
                _userDoc?['date_of_birth'] ??
                _userDoc?['dob'])
            as Timestamp?;
    if (ts == null) return null;
    final dob = ts.toDate();
    final now = DateTime.now();

    var age = now.year - dob.year;
    final hadBirthday =
        (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    return age;
  }

  String _ageText() {
    final age = _ageYears();
    final bucket =
        (age != null && age >= _oldAgeThreshold) ? ' (older adult)' : '';
    return age == null ? 'N/A' : '$age years old$bucket';
  }

  String _initials() {
    final name =
        ((_userDoc?['display_name'] as String?) ?? _displayName).trim();
    if (name.isEmpty || name == '—') return '';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // If there is no signed-in user, show a light "signed out" screen instead of crashing
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You are signed out.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).pushNamed('/signInScreen'),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    final role = context.watch<AppState>().userType; // 'doctor' or 'patient'
    final initials = _initials();

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF9FF), Color(0xFFFDFEFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                // Avatar: initials only (no images)
                Center(
                  child: CircleAvatar(
                    radius: 70,
                    backgroundColor: const Color(0xFF195E99),
                    child:
                        initials.isNotEmpty
                            ? Text(
                              initials,
                              style: GoogleFonts.inter(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 56,
                            ),
                  ),
                ),
                const SizedBox(height: 10),

                // Name + role
                Center(
                  child: Text(
                    (_userDoc?['display_name'] as String?) ?? _displayName,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(
                    (role == 'doctor'
                        ? 'Doctor'
                        : role == 'patient'
                        ? 'Patient'
                        : '—'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF979BA1),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Fields
                _Field(
                  label: 'Age',
                  value: _ageText(),
                  editable: true,
                  onTap: _editAgeViaDob,
                ),
                _Field(
                  label: 'Gender',
                  value: _normalizedGender((_userDoc?['gender'] as String?)),
                  editable: true,
                  onTap: _editGender,
                ),
                _Field(
                  label: 'Phone',
                  value: (_userDoc?['phone_number'] as String?) ?? '',
                  editable: true,
                  onTap: () {
                    _editText(
                      title: 'Phone',
                      initial: (_userDoc?['phone_number'] as String?) ?? '',
                      keyboardType: TextInputType.phone,
                      onSave: (v) => _updateUsers({'phone_number': v}),
                    );
                  },
                ),
                _Field(label: 'Email Address', value: _email),

                if (role == 'patient') ...[
                  _Field(
                    label: 'Assigned Doctor',
                    value:
                        (((_roleDoc?['assigned_doctor_name'] as String?) ?? '')
                                .trim()
                                .isEmpty)
                            ? 'N/A'
                            : (_roleDoc?['assigned_doctor_name'] as String),
                  ),
                  const SizedBox(height: 18),
                  _OutlinedAction(
                    text: 'Assign Caregiver/Doctor',
                    onPressed: _chooseDoctor,
                    blue: _blue,
                  ),
                  const SizedBox(height: 10),
                ] else if (role == 'doctor') ...[
                  _Field(
                    label: 'Specialty',
                    value: (_roleDoc?['specialty'] as String?) ?? 'Not set',
                    editable: true,
                    onTap: () {
                      _editText(
                        title: 'Specialty',
                        initial: (_roleDoc?['specialty'] as String?) ?? '',
                        onSave: (v) => _updateRole({'specialty': v}),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                ],

                _OutlinedAction(
                  text: 'Log out',
                  onPressed: _logout,
                  blue: _blue,
                ),
                const SizedBox(height: 16),
                _OutlinedAction(
                  text: 'Deactivate Account',
                  onPressed: _deleteAccount,
                  blue: _orange,
                  textColor: _orange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//--------------------------- custom_widgets ---------------------------

// custom widget that displays (label, value, optional: edit icon)
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.onTap,
    this.editable = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF7A7B82);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value.isEmpty ? '—' : value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A7B82),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (editable) const SizedBox(width: 6),
                  if (editable)
                    const Icon(Icons.edit, size: 16, color: Color(0xFF7A7B82)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// custom button widget.
class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.text,
    required this.onPressed,
    required this.blue,
    this.textColor,
  });

  final String text;
  final VoidCallback onPressed;
  final Color blue;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: blue, width: 1.2),
          foregroundColor: textColor ?? blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _DeactivateDialog extends StatelessWidget {
  const _DeactivateDialog({required this.blue, required this.orange});
  final Color blue;
  final Color orange;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Are you sure you want\nto deactivate your\naccount ?',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: blue),
            foregroundColor: blue,
          ),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, Deactivate'),
        ),
      ],
    );
  }
}

//----------------------------------------------------------------------
