// lib/Patient_Screens/settings_screen.dart
import 'dart:ui' as ui; // for the subtle blur in the header card
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'alert_settings_screen.dart'; // <-- NEW: navigate to alert settings

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings_screen';
  static const String routePath = '/settingsScreen';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alzheimersMode = false;

  // Brand colors
  static const _primary = Color(0xFF327BF1);
  static const _title = Color(0xFF668393);
  static const _subtitle = Color(0xFF979BA1);
  static const _rowText = Color(0xFF222B32);
  static const _border = Color(0xFF7A7B82);

  TextStyle get _titleStyle => GoogleFonts.inter(
    color: _title,
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  TextStyle get _subtitleStyle => GoogleFonts.inter(
    color: _subtitle,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  TextStyle get _rowTitleStyle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _rowText,
  );

  TextStyle get _rowHintStyle => GoogleFonts.inter(
    fontSize: 12,
    color: const Color(0xFF606C77),
    fontWeight: FontWeight.w500,
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _border.withOpacity(0.25)),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Now shows "coming soon" immediately (no bottom sheet)
  void _onUpdateFingerprint() {
    _snack('Fingerprint enrollment coming soon.');
  }

  void _openAlertSettings() {
    Navigator.of(context).pushNamed(AlertSettingsScreen.routePath);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF95A1AC),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData leading,
    required String title,
    String? hint,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final content = Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _primary.withOpacity(.1),
          child: Icon(leading, color: _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                hint == null
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: _rowTitleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: _rowHintStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (trailing != null) trailing,
        if (trailing == null)
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFB3BAC2)),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF9FF), Color(0xFFFDFEFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // Decorative header (soft blur over gradient)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(.6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Box Settings', style: _titleStyle),
                              const SizedBox(height: 4),
                              Text(
                                'Every time one Time ',
                                style: _subtitleStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              _sectionLabel('Device'),

              // Update Fingerprint (instant toast)
              _settingsTile(
                leading: Icons.fingerprint,
                title: 'Update Fingerprint',
                hint: 'Use biometrics to secure access',
                onTap: _onUpdateFingerprint,
              ),

              const SizedBox(height: 16),
              _sectionLabel('Accessibility'),

              // Alzheimer’s Mode toggle
              _settingsTile(
                leading: Icons.psychology_alt_rounded,
                title: "Enable Alzheimer's Mode",
                hint: "Larger text & simplified flows",
                trailing: Switch.adaptive(
                  value: _alzheimersMode,
                  onChanged: (val) {
                    setState(() => _alzheimersMode = val);
                    _snack(
                      _alzheimersMode
                          ? "Alzheimer's Mode enabled"
                          : "Alzheimer's Mode disabled",
                    );
                  },
                  activeColor: const Color(0xFF3688F3),
                  activeTrackColor: const Color(0xFF3688F3),
                ),
              ),

              const SizedBox(height: 16),
              _sectionLabel('Notifications'),

              // Alert Settings -> navigates to a real screen
              _settingsTile(
                leading: Icons.notifications_active_rounded,
                title: 'Alert Settings',
                hint: 'Reminders for taking your medicines',
                onTap: _openAlertSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
