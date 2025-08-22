import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // orientation lock

//------------------------ third_part_packages -------------------------
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//----------------------------------------------------------------------

//--------------------------- common_shared ---------------------------
import '/app_state.dart';
import '/profile_screen.dart';
import 'package:media_mate/theme/colors.dart';
//----------------------------------------------------------------------

//--------------------------- authentication ---------------------------
import '/authentication/select_user_screen.dart';
import '/authentication/signIn_screen.dart';
import '/authentication/signUp_screen.dart';
//----------------------------------------------------------------------

//--------------------------- doctor_screens ---------------------------
import '/Doctor_Screens/home_doctor_screen.dart';
import '/Doctor_Screens/patient_info_screen.dart';
import '/Doctor_Screens/tracking_medicine.dart';
//----------------------------------------------------------------------

//-------------------------- patient_screens ---------------------------
import '/Patient_Screens/home_patient_screen.dart';
import '/Patient_Screens/medcine_patient_screen.dart';
import '/Patient_Screens/searching_for_doctor_screen.dart';
import '/Patient_Screens/settings_screen.dart';
import '/Patient_Screens/alert_settings_screen.dart';
import '/Patient_Screens/notifications/notification_service.dart';
//----------------------------------------------------------------------

//------------------------------ services ------------------------------
import 'services/bluetooth_service.dart';
//----------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BluetoothService().init();

  await Firebase.initializeApp();

  // Lock app to portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize local notifications
  await NotificationService.instance.init();

  // make sure all screens can share the same app state
  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,

        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.surface,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF195E99),
            foregroundColor: AppColors.surface,
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      home: const AuthGate(),

      // This is a map of all screens in your app
      routes: {
        SelectUserScreenWidget.routePath: (_) => const SelectUserScreenWidget(),
        SignInScreenWidget.routePath: (_) => const SignInScreenWidget(),
        MainNavBarPage.routeName: (_) => const MainNavBarPage(),
        ProfileScreen.routePath: (_) => const ProfileScreen(),
        SearchingForDoctorScreenWidget.routePath:
            (_) => const SearchingForDoctorScreenWidget(),
        SignUpScreenWidget.routePath: (_) => const SignUpScreenWidget(),
        SettingsScreen.routePath: (_) => const SettingsScreen(),
        MedicinePatientScreen.routePath: (_) => const MedicinePatientScreen(),
        HomePatientScreen.routePath: (_) => const HomePatientScreen(),
        HomeDoctorScreenWidget.routePath: (_) => const HomeDoctorScreenWidget(),
        AlertSettingsScreen.routePath: (_) => const AlertSettingsScreen(),
        PatientInfoScreen.routePath: (_) => const PatientInfoScreen(),
        TrackingMedicineScreen.routePath:
            (context) => const TrackingMedicineScreen(),
      },
    );
  }
}

// Should i show the login screen, or should i take the user into the app
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder: listens to changes over time
    // authStateChanges: tells us if the user is logged in or not

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const SelectUserScreenWidget();
        return const RoleGate();
      },
    );
  }
}

/// Ensures each signed-in user has a Firestore `users` document (create if missing).
/// Then checks their role (doctor/patient) and directs them to the right page.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  // usersRef: reference to the user's document 'users/<uid>'
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadOrCreateUserDoc(
    DocumentReference<Map<String, dynamic>> usersRef,
    User u,
  ) async {
    final doc = await usersRef.get();
    if (!doc.exists) {
      await usersRef.set({
        'email': u.email,
        'display_name': u.displayName,

        // FieldValue.delete(): leave this blank for now, user will fill it in later.
        // if we don't use it we will end up storing "unkown"
        'user_type': FieldValue.delete(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return await usersRef.get();
    }
    return doc;
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const SelectUserScreenWidget();

    final usersRef = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final future = _loadOrCreateUserDoc(usersRef, u);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load your profile.'),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const SelectUserScreenWidget(),
                            ),
                            (r) => false,
                          );
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snap.data?.data();
        final role = (data?['user_type'] as String? ?? '').trim();

        // Update Provider after this frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final appState = context.read<AppState>();
          if (appState.userType != role) {
            appState.userType = role;
          }
        });

        if (role != 'doctor' && role != 'patient') {
          return const SelectUserScreenWidget();
        }

        return const MainNavBarPage();
      },
    );
  }
}

/// ******************** handle_bottom_navigation *********************
class MainNavBarPage extends StatefulWidget {
  const MainNavBarPage({super.key});
  static const String routeName = '/main-nav-bar';

  @override
  State<MainNavBarPage> createState() => _MainNavBarPageState();
}

class _MainNavBarPageState extends State<MainNavBarPage> {
  int _selectedIndex = 0;

  // Doctor pages
  static const List<Widget> _doctorPages = [
    HomeDoctorScreenWidget(),
    ProfileScreen(),
  ];

  // Patient pages
  static const List<Widget> _patientPages = [
    HomePatientScreen(),
    MedicinePatientScreen(),
    ProfileScreen(),
    SettingsScreen(),
  ];

  static const List<BottomNavigationBarItem> _doctorNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  static const List<BottomNavigationBarItem> _patientNavItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(
      icon: Icon(Icons.medication_rounded),
      label: 'Medications',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_rounded),
      label: 'Settings',
    ),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final userType = context.watch<AppState>().userType;
    final isDoctor = userType == 'doctor';

    // if doctor: show doctor pages + nav bar items
    // if patient: show patient pages + nav bar items
    final currentPages = isDoctor ? _doctorPages : _patientPages;
    final currentNavItems = isDoctor ? _doctorNavItems : _patientNavItems;

    if (_selectedIndex >= currentPages.length) _selectedIndex = 0;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: currentPages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: currentNavItems,
        backgroundColor: AppColors.bgBottom,
        selectedItemColor: const Color(0xFF4589FB),
        unselectedItemColor: const Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 5.0,
      ),
    );
  }
}
