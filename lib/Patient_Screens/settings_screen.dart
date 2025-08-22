//----------------------------- dart_core ------------------------------
import 'dart:async';
import 'dart:ui' as ui; // for the subtle blur effect
//----------------------------------------------------------------------

//----------------------------- flutter_core ----------------------------
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:media_mate/theme/colors.dart';
//----------------------------------------------------------------------

//-------------------------- project_imports ----------------------------
import '../services/bluetooth_service.dart'; // Your Bluetooth singleton service
import 'alert_settings_screen.dart'; // Alert settings navigation
//----------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String routeName = 'settings_screen';
  static const String routePath = '/settingsScreen';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alzheimersMode = false;

  final BluetoothService _bt = BluetoothService();
  List<BluetoothDiscoveryResult> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _discovering = false;
  bool _connecting = false;
  String _log = '';

  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  // Firebase for fetching medicines for emergency dialog
  final _auth = FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _medsCol =>
      FirebaseFirestore.instance.collection('Medicine');

  // Store medicines fetched for emergency popup
  List<_MedView> _allMedsForEmergency = [];

  // UI theme colors
  static const _title = Color(0xFF668393);
  static const _subtitle = Color(0xFF979BA1);
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
    color: AppColors.textDark,
  );

  TextStyle get _rowHintStyle => GoogleFonts.inter(
    fontSize: 12,
    color: const Color(0xFF606C77),
    fontWeight: FontWeight.w500,
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _border.withOpacity(0.25)),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onUpdateFingerprint() async {
    if (_connectedDevice == null) {
      _snack('No device connected');
      return;
    }
    try {
      await _bt.send('F');
      _snack('command has been sent successfully.');
    } catch (e) {
      _snack('Failed to send command: $e');
    }
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
          backgroundColor: AppColors.primary.withOpacity(.1),
          child: Icon(leading, color: AppColors.primary),
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
        if (trailing != null)
          trailing
        else
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

  // ---------- Emergency Code Sending ----------

  void _sendEmergencyCommand(int container) async {
    final String messageToSend = '${container}E';
    try {
      await _bt.send(messageToSend);
      _snack('Sent emergency code: $messageToSend');
    } catch (e) {
      _snack('Error sending emergency: $e');
    }
  }

  Future<void> _showEmergencyDialog() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _snack('User not signed in.');
      return;
    }

    final snapshot = await _medsCol.where('patient_id', isEqualTo: uid).get();
    final medicines = <_MedView>[];
    for (final d in snapshot.docs) {
      final m = d.data();
      medicines.add(
        _MedView(
          id: d.id,
          name: (m['name'] ?? '').toString(),
          container: m['container_number'] ?? 0,
        ),
      );
    }

    if (medicines.isEmpty) {
      _snack('No medicines available for emergency.');
      return;
    }

    _allMedsForEmergency = medicines;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Medicine for Emergency'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allMedsForEmergency.length,
              itemBuilder: (context, index) {
                final med = _allMedsForEmergency[index];
                return ListTile(
                  title: Text(med.name.isEmpty ? 'Unnamed medicine' : med.name),
                  subtitle: Text('Container ${med.container}'),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (med.container >= 1 && med.container <= 3) {
                      _sendEmergencyCommand(med.container);
                    } else {
                      _snack('Invalid container for medicine ${med.name}');
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // ---------- Bluetooth Discovery ----------

  Future<void> _startDiscovery() async {
    if (_discovering) return;

    setState(() {
      _discoveredDevices.clear();
      _discovering = true;
      _log = 'Starting discovery...';
    });

    _discoveryStreamSubscription = FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen(
          (BluetoothDiscoveryResult result) {
            setState(() {
              final index = _discoveredDevices.indexWhere(
                (d) => d.device.address == result.device.address,
              );
              if (index >= 0) {
                _discoveredDevices[index] = result;
              } else {
                _discoveredDevices.add(result);
              }
            });
          },
          onDone: () {
            setState(() {
              _discovering = false;
              _log =
                  'Discovery finished. Found ${_discoveredDevices.length} devices.';
            });
          },
          onError: (e) {
            setState(() {
              _discovering = false;
              _log = 'Discovery error: $e';
            });
            _snack('Discovery error: $e');
          },
        );
  }

  Future<void> _stopDiscovery() async {
    await _discoveryStreamSubscription?.cancel();
    setState(() {
      _discovering = false;
      _log = 'Discovery stopped';
    });
  }

  // ---------- Connect / Disconnect ----------

  Future<void> _onConnect(BluetoothDevice d) async {
    setState(() => _connecting = true);
    try {
      await _bt.connect(d.address);
      setState(() {
        _connecting = false;
        _connectedDevice = d;
        _log = "Connected to ${d.name ?? d.address}";
      });
    } catch (e) {
      _snack('Failed to connect: $e');
      setState(() => _connecting = false);
    }
  }

  Future<void> _onDisconnect() async {
    await _bt.disconnect();
    setState(() {
      _connectedDevice = null;
      _log = "Disconnected";
    });
    _snack("Disconnected from device");
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  // ---------- UI Widgets ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.surface.withOpacity(.6),
                      ),
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
                                'Every time one Time',
                                style: _subtitleStyle,
                              ),
                            ],
                          ),
                        ),
                        // New Emergency Button here
                        ElevatedButton(
                          onPressed: _showEmergencyDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Box Emergency',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _sectionLabel('Device'),
              _settingsTile(
                leading: Icons.fingerprint,
                title: 'Update Fingerprint',
                hint: 'Use biometrics to secure access',
                onTap: _onUpdateFingerprint,
              ),
              const SizedBox(height: 16),
              _sectionLabel('Accessibility'),
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
              _settingsTile(
                leading: Icons.notifications_active_rounded,
                title: 'Alert Settings',
                hint: 'Reminders for taking your medicines',
                onTap: _openAlertSettings,
              ),
              const SizedBox(height: 16),
              _sectionLabel('Bluetooth Devices'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: _cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discovery Control Row
                    Row(
                      children: [
                        Icon(Icons.search, color: AppColors.primary, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _discovering
                                ? 'Discovering devices...'
                                : 'Search for new Bluetooth devices',
                            style: _rowTitleStyle,
                          ),
                        ),
                        if (!_discovering)
                          IconButton(
                            icon: Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Start Scan',
                            onPressed: _startDiscovery,
                          ),
                        if (_discovering)
                          IconButton(
                            icon: Icon(
                              Icons.stop_rounded,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Stop Scan',
                            onPressed: _stopDiscovery,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child:
                          _discoveredDevices.isEmpty
                              ? Center(
                                child: Text(
                                  _discovering
                                      ? 'Scanning for devices...'
                                      : 'No devices found',
                                  style: _rowHintStyle,
                                ),
                              )
                              : ListView.separated(
                                itemCount: _discoveredDevices.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final r = _discoveredDevices[i];
                                  final d = r.device;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.devices),
                                    title: Text(d.name ?? 'Unknown Device'),
                                    subtitle: Text(d.address),
                                    trailing: ElevatedButton(
                                      onPressed:
                                          (_connecting ||
                                                  _connectedDevice != null)
                                              ? null
                                              : () {
                                                _stopDiscovery();
                                                _onConnect(d);
                                              },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.surface,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Connect',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _connectedDevice != null
                                ? "Connected: ${_connectedDevice!.name ?? _connectedDevice!.address}"
                                : 'Not connected',
                            style: _rowTitleStyle,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.link_off,
                            color:
                                _connectedDevice != null
                                    ? AppColors.primary
                                    : Colors.grey,
                          ),
                          tooltip: 'Disconnect',
                          onPressed:
                              _connectedDevice != null ? _onDisconnect : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _log,
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple medicine data holder for emergency popup
class _MedView {
  _MedView({required this.id, required this.name, required this.container});

  final String id;
  final String name;
  final int container;
}
