//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // orientation lock
//----------------------------------------------------------------------

//------------------------ third_part_packages -------------------------
import 'package:google_fonts/google_fonts.dart';
import 'package:media_mate/widgets/auth/auth_gate.dart';
import 'package:media_mate/widgets/nav/main_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
//----------------------------------------------------------------------

//--------------------------- common_shared ---------------------------
import '/app_state.dart';
import '/profile_screen.dart';
import 'package:media_mate/theme/colors.dart';
//----------------------------------------------------------------------

//--------------------------- authentication ---------------------------
import '/authentication/select_user_screen.dart';
import 'authentication/sign_in_screen.dart';
import 'authentication/sign_up_screen.dart';
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
