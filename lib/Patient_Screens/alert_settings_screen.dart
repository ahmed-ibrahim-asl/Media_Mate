//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import '../Patient_Screens/notifications/notification_service.dart';
//----------------------------------------------------------------------

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  static const String routeName = 'alert_settings_screen';
  static const String routePath = '/alertSettings';

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  static const _prefsKeyEnabled = 'alerts_enabled_v1';
  static const _primary = Color(0xFF327BF1);

  bool _enabled = false;
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>> get _medsCol =>
      FirebaseFirestore.instance.collection('Medicine');

  @override
  void initState() {
    super.initState();
    _loadEnabled();
  }

  Future<void> _loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKeyEnabled) ?? false;
    if (!mounted) return;
    setState(() => _enabled = saved);
  }

  Future<void> _setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, v);
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Requests notification permissions and initializes the plugin.
  Future<bool> _ensureInitAndPerms() async {
    await NotificationService.instance.init(); // idempotent

    // Android 13+ needs POST_NOTIFICATIONS permission declared in the manifest.
    // Make sure AndroidManifest.xml has:
    // <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    final granted = await NotificationService.instance.requestPermissions();
    if (!granted) {
      _snack('Notification permission was not granted.');
      return false;
    }
    _snack('Notifications enabled.');
    return true;
  }

  /// Read medicines and schedule daily reminders. Falls back to inexact alarms.
  Future<void> _scheduleFromFirestore() async {
    final uid = _uid;
    if (uid == null) {
      _snack('Please sign in first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final q = await _medsCol.where('patient_id', isEqualTo: uid).get();
      int scheduled = 0;

      final now = DateTime.now();

      for (final doc in q.docs) {
        final data = doc.data();
        final name = (data['name'] ?? 'Medicine').toString();
        final dose = (data['dose'] ?? '').toString();
        final times = (data['times'] as List?)?.whereType<int>().toList() ?? [];

        // Optional date range
        final bool longTerm = (data['long_term'] == true);
        final DateTime? start =
            (data['start_date'] is Timestamp)
                ? (data['start_date'] as Timestamp).toDate()
                : null;
        final DateTime? end =
            (data['end_date'] is Timestamp)
                ? (data['end_date'] as Timestamp).toDate()
                : null;

        // Skip if not long-term and today is outside the window
        if (!longTerm && !_dateIsWithin(now, start, end)) continue;

        for (final m in times) {
          final title = 'Time to take $name';
          final body = dose.isEmpty ? 'Medication reminder' : 'Dose: $dose';
          await NotificationService.instance.scheduleDailyReminderForDoc(
            uid: uid,
            docId: doc.id,
            minutesSinceMidnight: m,
            title: title,
            body: body,
          );
          scheduled++;
        }
      }
      _snack('Scheduled $scheduled reminder(s).');
    } catch (e) {
      _snack('Failed to schedule: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// True if [date] is within [start]..[end] inclusive (dates only)
  bool _dateIsWithin(DateTime date, DateTime? start, DateTime? end) {
    final d = DateTime(date.year, date.month, date.day);
    final s =
        (start == null) ? null : DateTime(start.year, start.month, start.day);
    final e = (end == null) ? null : DateTime(end.year, end.month, end.day);
    if (s != null && d.isBefore(s)) return false;
    if (e != null && d.isAfter(e)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF222B32),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Settings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF222B32),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Medication Alerts', style: titleStyle),
            const SizedBox(height: 12),
            Text(
              'Enable reminders and sync from your medicines list. '
              'We will schedule daily notifications at your chosen times.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF606C77),
              ),
            ),
            const SizedBox(height: 16),

            // Enable switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: _primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Enable medication reminders',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF222B32),
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _enabled,
                    onChanged: (v) async {
                      if (v) {
                        final ok = await _ensureInitAndPerms();
                        if (!ok) {
                          await _setEnabled(false);
                          return;
                        }
                        await _setEnabled(true);
                      } else {
                        await NotificationService.instance.cancelAll();
                        await _setEnabled(false);
                        _snack('All reminders canceled.');
                      }
                    },
                    activeColor: const Color(0xFF3688F3),
                    activeTrackColor: const Color(0xFF3688F3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Schedule button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy || !_enabled ? null : _scheduleFromFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.sync_rounded),
                label:
                    _busy
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Sync reminders from my medicines'),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed:
                    _busy
                        ? null
                        : () async {
                          await NotificationService.instance.cancelAll();
                          _snack('All reminders canceled.');
                        },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.notifications_off_rounded),
                label: const Text('Cancel all reminders'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
