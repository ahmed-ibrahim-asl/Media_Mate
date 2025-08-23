//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import 'package:media_mate/Doctor_Screens/patient_info_screen.dart';
import 'package:media_mate/theme/colors.dart';
//----------------------------------------------------------------------

class HomeDoctorScreenWidget extends StatefulWidget {
  const HomeDoctorScreenWidget({super.key});

  // Keep these names so your existing navigation keeps working
  static const String routeName = 'HomeDoctor_screen';
  static const String routePath = '/homeDoctor';

  @override
  State<HomeDoctorScreenWidget> createState() => _HomeDoctorScreenWidgetState();
}

class _HomeDoctorScreenWidgetState extends State<HomeDoctorScreenWidget> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _searchTerm = '';
  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final next = _searchCtrl.text;
      if (next != _searchTerm) setState(() => _searchTerm = next);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Stream of this doctor's patients (requires patients.assigned_doctor_id)
  Stream<QuerySnapshot<Map<String, dynamic>>> _patientsStream() {
    final uid = _user?.uid;
    final base = FirebaseFirestore.instance.collection('patients');
    if (uid == null) {
      // empty stream if not signed in
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return base.where('assigned_doctor_id', isEqualTo: uid).snapshots();
  }

  int _ageFrom(dynamic rawDob) {
    DateTime? dob;
    if (rawDob is Timestamp) {
      dob = rawDob.toDate();
    } else if (rawDob is DateTime) {
      dob = rawDob;
    } else if (rawDob is String) {
      dob = DateTime.tryParse(rawDob);
    }
    if (dob == null) return 0;

    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(title: const Text('Doctor Home')),
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

    return GestureDetector(
      onTap: () {
        _searchFocus.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.surface,
        body: SafeArea(
          top: true,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                // Header + Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Doctor!',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF668393),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.search,
                                color: Color(0xFFB1B1B1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  decoration: InputDecoration(
                                    hintText: 'Search Patients...',
                                    hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFF626262),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Patients list
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _patientsStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Error loading patients:\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(),
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: Text('No assigned patients found.'),
                        ),
                      );
                    }

                    final term = _searchTerm.trim().toLowerCase();
                    final items =
                        snap.data!.docs
                            .map((d) {
                              final m = d.data();
                              final displayName =
                                  (m['display_name'] ?? m['full_name'] ?? '')
                                      .toString();
                              final gender = (m['gender'] ?? 'N/A').toString();
                              final photoUrl =
                                  (m['photo_url'] ?? '').toString();
                              final age = _ageFrom(m['date_of_birth']);
                              return _PatientVM(
                                id: d.id,
                                name: displayName,
                                gender: gender,
                                ageText: '$age years old',
                                photoUrl: photoUrl,
                              );
                            })
                            .where((p) {
                              if (term.isEmpty) return true;
                              return p.name.toLowerCase().contains(term);
                            })
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = items[i];
                          return Container(
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: AppColors.chip,
                                  backgroundImage:
                                      p.photoUrl.isNotEmpty
                                          ? NetworkImage(p.photoUrl)
                                          : null,
                                  child:
                                      p.photoUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Color(0xFF8A9AA7),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name.isEmpty
                                            ? 'Unnamed Patient'
                                            : p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${p.gender}, ${p.ageText}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSubtle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          PatientInfoScreen.routePath,
                                          arguments: {
                                            'patientId': p.id,
                                            'displayName': p.name,
                                          },
                                        );

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Open ${p.name} details',
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: AppColors.primary,

                                        foregroundColor: AppColors.surface,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'More',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientVM {
  final String id;
  final String name;
  final String gender;
  final String ageText;
  final String photoUrl;
  _PatientVM({
    required this.id,
    required this.name,
    required this.gender,
    required this.ageText,
    required this.photoUrl,
  });
}
