import 'package:flutter/material.dart';
import 'package:media_mate/Doctor_Screens/home_doctor_screen.dart';
import 'package:media_mate/Patient_Screens/home_patient_screen.dart';
import 'package:media_mate/Patient_Screens/medcine_patient_screen.dart';
import 'package:media_mate/Patient_Screens/settings_screen.dart';
import 'package:media_mate/app_state.dart';
import 'package:media_mate/profile_screen.dart';
import 'package:media_mate/theme/colors.dart';
import 'package:provider/provider.dart';

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
