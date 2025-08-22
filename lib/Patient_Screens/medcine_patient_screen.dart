//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//----------------------------------------------------------------------

//----------------------------- dart_core ------------------------------
import 'dart:math' as math;
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import 'package:media_mate/Patient_Screens/notifications/notification_service.dart';
//----------------------------------------------------------------------

class MedicinePatientScreen extends StatefulWidget {
  const MedicinePatientScreen({super.key});

  static const String routeName = 'medicine_patient_screen';
  static const String routePath = '/medicinePatient';

  @override
  State<MedicinePatientScreen> createState() => _MedicinePatientScreenState();
}

class _MedicinePatientScreenState extends State<MedicinePatientScreen> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _medsCol =>
      FirebaseFirestore.instance.collection('Medicine');

  String _formatTime(int minutesSinceMidnight) {
    final h = minutesSinceMidnight ~/ 60;
    final m = minutesSinceMidnight % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  String _formatTimes(List<dynamic>? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final minutes = raw.whereType<int>().toList()..sort();
    return minutes.map(_formatTime).join(', ');
  }

  String _composeDoseFromDoc(Map<String, dynamic> m) {
    final dv =
        (m['dose_value'] is num)
            ? (m['dose_value'] as num).toDouble()
            : double.tryParse('${m['dose_value'] ?? ''}');
    final du = (m['dose_unit'] ?? '').toString();
    if (dv != null && dv > 0 && du.isNotEmpty) {
      final asStr = (dv % 1 == 0) ? dv.toInt().toString() : dv.toString();
      return '$asStr $du';
    }
    final legacy = (m['dose'] ?? '').toString().trim();
    return legacy;
  }

  Future<void> _delete(String docId) async {
    try {
      await _medsCol.doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _openAddDialog() async {
    final uid = _uid;
    if (uid == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddMedicineDialog(collection: _medsCol),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Medications')),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Medications',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF668393),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        _medsCol
                            .where('patient_id', isEqualTo: uid)
                            .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error loading medications: ${snap.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        );
                      }

                      final docs =
                          snap.data!.docs.toList()..sort((a, b) {
                            final ta =
                                (a.data()['created_at'] as Timestamp?)
                                    ?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            final tb =
                                (b.data()['created_at'] as Timestamp?)
                                    ?.toDate() ??
                                DateTime.fromMillisecondsSinceEpoch(0);
                            return tb.compareTo(ta);
                          });

                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No medications yet.\nTap the + button to add one.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF606C77),
                              fontSize: 15,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                        itemBuilder: (_, i) {
                          final m = docs[i].data();
                          final id = docs[i].id;

                          final name = (m['name'] ?? '').toString();
                          final doseText = _composeDoseFromDoc(m);
                          final pills =
                              m['pills_per_day'] is int
                                  ? m['pills_per_day'] as int
                                  : int.tryParse(
                                        '${m['pills_per_day'] ?? 0}',
                                      ) ??
                                      0;
                          final instruction =
                              (m['instruction'] ?? '').toString();
                          final timesText = _formatTimes(
                            m['times'] as List<dynamic>?,
                          );
                          final container =
                              m['container_number']?.toString() ?? '—';

                          final bg =
                              i.isEven
                                  ? const Color(0xFFFEE0E0)
                                  : const Color(0xFFE7F0FE);

                          return Dismissible(
                            key: ValueKey(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (_) => AlertDialog(
                                          title: const Text('Delete medicine?'),
                                          content: Text(
                                            'This will remove “$name”.',
                                            style: GoogleFonts.inter(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    false,
                                                  ),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    true,
                                                  ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) => _delete(id),
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: const Icon(
                                        Icons.medication,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                name.isEmpty
                                                    ? 'Unnamed medicine'
                                                    : name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF222B32,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(flex: 1),
                                              Text(
                                                'Container: $container',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: const Color(
                                                    0xFF4977B9,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$timesText  ·  ${pills > 0 ? '$pills Pill${pills == 1 ? '' : 's'}' : ''}'
                                            '${doseText.isNotEmpty ? '  ·  $doseText' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF606C77),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            instruction.isEmpty
                                                ? '—'
                                                : instruction,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: const Color(0xFF757575),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            heroTag: 'meds-add',
            onPressed: _openAddDialog,
            backgroundColor: const Color(0xFF499EE2),
            elevation: 0,
            shape: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 35,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Transform.rotate(
                  angle: math.pi / 2,
                  child: Container(
                    width: 35,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Add Medicine Dialog =================
class _AddMedicineDialog extends StatefulWidget {
  const _AddMedicineDialog({required this.collection});
  final CollectionReference<Map<String, dynamic>> collection;

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _doseValue = TextEditingController();
  final _pillsPerDay = TextEditingController();
  final _instruction = TextEditingController();

  final List<int> _times = [];
  bool _longTerm = true;
  DateTime? _startDate;
  DateTime? _endDate;

  int? _containerNumber;
  List<int> _availableContainers = [];
  bool _loadingContainers = true;

  final List<String> _units = const ['mg', 'g', 'IU'];
  List<bool> _unitSelected = [true, false, false];

  String get _doseUnit {
    final idx = _unitSelected.indexWhere((e) => e);
    return idx >= 0 ? _units[idx] : 'mg';
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableContainers();
  }

  Future<void> _loadAvailableContainers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _availableContainers = [];
        _loadingContainers = false;
      });
      return;
    }
    final docs =
        await widget.collection.where('patient_id', isEqualTo: uid).get();
    final used =
        docs.docs
            .map((d) => d.data()['container_number'] as int?)
            .where((x) => x != null)
            .cast<int>()
            .toSet();
    setState(() {
      _availableContainers = [1, 2, 3].where((c) => !used.contains(c)).toList();
      _containerNumber = null;
      _loadingContainers = false;
    });
  }

  void _selectUnit(int index) {
    setState(() {
      _unitSelected = List<bool>.generate(_units.length, (i) => i == index);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _doseValue.dispose();
    _pillsPerDay.dispose();
    _instruction.dispose();
    super.dispose();
  }

  String _formatTimeChip(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 : ${m.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: 0),
    );
    if (t == null) return;
    final minutes = t.hour * 60 + t.minute;
    if (_times.contains(minutes)) return;
    setState(() {
      _times.add(minutes);
      _times.sort();
    });
  }

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 5),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEndDate() async {
    final base = _startDate ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base.add(const Duration(days: 7)),
      firstDate: base,
      lastDate: DateTime(base.year + 5),
    );
    if (d != null) setState(() => _endDate = d);
  }

  Widget _containerSelector() {
    if (_loadingContainers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_availableContainers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'All containers are occupied.\nDelete one first to add another.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(
        labelText: 'Container',
        border: OutlineInputBorder(),
      ),
      value: _containerNumber,
      items:
          _availableContainers
              .map(
                (n) => DropdownMenuItem(value: n, child: Text('Container $n')),
              )
              .toList(),
      onChanged: (val) => setState(() => _containerNumber = val),
      validator: (v) => v == null ? 'Select a container' : null,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _availableContainers.isEmpty ||
        _containerNumber == null)
      return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time')),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doseValText = _doseValue.text.trim();
    final doseVal = doseValText.isEmpty ? null : double.tryParse(doseValText);
    if (doseValText.isNotEmpty && doseVal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dose must be a number')));
      return;
    }

    try {
      final docRef = await widget.collection.add({
        'patient_id': uid,
        'name': _name.text.trim(),
        'dose_value': doseVal,
        'dose_unit': doseVal == null ? null : _doseUnit,
        'dose':
            doseVal == null
                ? ''
                : '${doseVal % 1 == 0 ? doseVal.toInt() : doseVal} $_doseUnit',
        'pills_per_day': int.tryParse(_pillsPerDay.text.trim()) ?? 0,
        'instruction': _instruction.text.trim(),
        'times': _times,
        'long_term': _longTerm,
        'start_date':
            _longTerm || _startDate == null
                ? null
                : Timestamp.fromDate(
                  DateTime(
                    _startDate!.year,
                    _startDate!.month,
                    _startDate!.day,
                  ),
                ),
        'end_date':
            _longTerm || _endDate == null
                ? null
                : Timestamp.fromDate(
                  DateTime(_endDate!.year, _endDate!.month, _endDate!.day),
                ),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'container_number': _containerNumber,
      });

      for (final m in _times) {
        final medName =
            _name.text.trim().isEmpty ? 'Medicine' : _name.text.trim();
        final doseText =
            doseVal == null
                ? 'Medication reminder'
                : 'Dose: ${(doseVal % 1 == 0) ? doseVal.toInt() : doseVal} $_doseUnit';
        await NotificationService.instance.scheduleDailyReminderForDoc(
          uid: uid,
          docId: docRef.id,
          minutesSinceMidnight: m,
          title: 'Time to take $medName',
          body: doseText,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine added and reminders scheduled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  Widget _unitToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ToggleButtons(
        isSelected: _unitSelected,
        onPressed: _selectUnit,
        borderRadius: BorderRadius.circular(10),
        borderWidth: 1.2,
        renderBorder: true,
        constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
        borderColor: const Color(0xFFCBD5E1),
        selectedBorderColor: const Color(0xFF1766B9),
        fillColor: const Color(0x1F1766B9),
        selectedColor: const Color(0xFF1766B9),
        color: const Color(0xFF374151),
        children:
            _units
                .map(
                  (u) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      u,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 420;
                  final doseField = TextFormField(
                    controller: _doseValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      hintText: 'e.g., 500',
                      border: OutlineInputBorder(),
                    ),
                  );

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Add Medicine',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color.fromARGB(255, 29, 96, 170),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _containerSelector(),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Medication Name',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      if (!narrow)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: doseField),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unit',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _unitToggle(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            doseField,
                            const SizedBox(height: 10),
                            Text(
                              'Unit',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _unitToggle(),
                          ],
                        ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _pillsPerDay,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Pills per Day',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _instruction,
                        decoration: const InputDecoration(
                          labelText: 'Timing Instruction',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: -6,
                              children:
                                  _times.isEmpty
                                      ? [
                                        Text(
                                          'No times added',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ]
                                      : _times
                                          .map(
                                            (t) => Chip(
                                              label: Text(_formatTimeChip(t)),
                                              onDeleted:
                                                  () => setState(
                                                    () => _times.remove(t),
                                                  ),
                                            ),
                                          )
                                          .toList(),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _pickTime,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1766B9),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              fixedSize: const Size(120, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Add Time'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Long-term medication',
                          style: TextStyle(fontSize: 15),
                        ),
                        value: _longTerm,
                        onChanged:
                            (v) => setState(() => _longTerm = v ?? _longTerm),
                        controlAffinity: ListTileControlAffinity.trailing,
                        activeColor: const Color(0xFF1766B9),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),

                      if (!_longTerm) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickStartDate,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1766B9),
                                  side: const BorderSide(
                                    color: Color(0xFF1766B9),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size.fromHeight(44),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(
                                  _startDate == null
                                      ? 'Begin Date'
                                      : MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(_startDate!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickEndDate,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1766B9),
                                  side: const BorderSide(
                                    color: Color(0xFF1766B9),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size.fromHeight(44),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(
                                  _endDate == null
                                      ? 'Finish Date'
                                      : MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(_endDate!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (_availableContainers.isEmpty) ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (_availableContainers.isEmpty)
                                    ? Colors.grey
                                    : const Color(0xFF007800),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          child: const Text('Add Medicine'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
