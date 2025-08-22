//----------------------------- dart_core ------------------------------
import 'dart:math' as math;
//----------------------------------------------------------------------

//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import 'package:media_mate/Doctor_Screens/tracking_medicine.dart';
//----------------------------------------------------------------------

class PatientInfoScreen extends StatefulWidget {
  const PatientInfoScreen({super.key, this.patientId, this.displayName});

  static const String routePath = '/patientInfo';

  final String? patientId; // You can also pass via Navigator arguments
  final String? displayName;

  @override
  State<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  // ----------------- Format helpers -----------------
  int _ageFrom(dynamic rawDob) {
    DateTime? dob;
    if (rawDob is Timestamp) dob = rawDob.toDate();
    if (rawDob is DateTime) dob = rawDob;
    if (rawDob is String) dob = DateTime.tryParse(rawDob);
    if (dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

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
    return minutes.map(_formatTime).join(' · ');
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

  String _dateOnly(dynamic ts) {
    if (ts == null) return '';
    final d = ts is Timestamp ? ts.toDate() : (ts as DateTime);
    return '${_mon[d.month]} ${d.day}, ${d.year}';
  }

  static const _mon = {
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };

  @override
  Widget build(BuildContext context) {
    // Read navigation arguments (if not passed via constructor)
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;
    final patientId = widget.patientId ?? args['patientId'] as String?;
    final displayNameArg = widget.displayName ?? args['displayName'] as String?;
    if (patientId == null || patientId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient')),
        body: const Center(child: Text('Missing patientId')),
      );
    }

    final patients = FirebaseFirestore.instance.collection('patients');
    final medsCol = FirebaseFirestore.instance.collection('Medicine');

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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: patients.doc(patientId).snapshots(),
            builder: (context, pSnap) {
              final patient = pSnap.data?.data();
              final name =
                  (patient?['display_name'] ??
                          patient?['full_name'] ??
                          displayNameArg ??
                          'Patient')
                      .toString();
              final gender = (patient?['gender'] ?? '').toString();
              final age = _ageFrom(patient?['date_of_birth']);
              final phone = (patient?['phone'] ?? '').toString();
              final email = (patient?['email'] ?? '').toString();
              final photoUrl = (patient?['photo_url'] ?? '').toString();

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: Color(0xFF4B5563),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: const Color(0xFFE9EEF2),
                                  backgroundImage:
                                      photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                  child:
                                      photoUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            size: 42,
                                            color: Color(0xFF8A9AA7),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (gender.isNotEmpty) gender,
                                          if (age > 0) '$age years old',
                                        ].join(', '),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          phone,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Patient Medications',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Meds list
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        medsCol
                            .where('patient_id', isEqualTo: patientId)
                            // no .orderBy(...) per your request
                            .snapshots(),
                    builder: (context, mSnap) {
                      if (mSnap.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ),
                        );
                      }
                      if (mSnap.hasError) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Failed to load medications:\n${mSnap.error}',
                              style: GoogleFonts.inter(),
                            ),
                          ),
                        );
                      }
                      final meds = mSnap.data?.docs ?? const [];

                      if (meds.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: Text(
                              'No medications found.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        sliver: SliverList.separated(
                          itemCount: meds.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, i) {
                            final doc = meds[i];
                            final data = doc.data();
                            final name =
                                (data['name'] ?? 'Medication').toString();
                            final pills =
                                data['pills_per_day'] is int
                                    ? data['pills_per_day'] as int
                                    : int.tryParse(
                                          '${data['pills_per_day'] ?? 0}',
                                        ) ??
                                        0;
                            final timesText = _formatTimes(
                              data['times'] as List<dynamic>?,
                            );
                            final doseText = _composeDoseFromDoc(data);
                            final instruction =
                                (data['instruction'] ?? '').toString();
                            final longTerm = (data['long_term'] == true);
                            final start = data['start_date'];
                            final end = data['end_date'];

                            // Primary line like: 2:30 PM · 3 Pills · 500 mg | After Meal
                            final primaryBits = <String>[
                              if (timesText != '—') timesText,
                              if (pills > 0)
                                '${pills} Pill${pills == 1 ? '' : 's'}',
                              if (doseText.isNotEmpty) doseText,
                              if (instruction.isNotEmpty) ' | $instruction',
                            ];
                            final primary = primaryBits.join('  ·  ');

                            // Secondary line: Long-Term Medication OR From: ... To: ...
                            final secondary =
                                longTerm
                                    ? 'Long-Term Medication'
                                    : 'From: ${_dateOnly(start)}  ·  To:  ${_dateOnly(end)}';

                            // Tertiary/footnote
                            final footnote =
                                (data['note'] ?? '').toString().isNotEmpty
                                    ? (data['note'] as String)
                                    : (instruction.isNotEmpty
                                        ? instruction.toLowerCase()
                                        : '—');

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                12,
                                12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left block (texts)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          primary,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          secondary,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          footnote,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Right buttons (Edit top, Details bottom)
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await showDialog<void>(
                                              context: context,
                                              barrierDismissible: false,
                                              builder:
                                                  (_) => _EditMedicineDialog(
                                                    collection: medsCol,
                                                    docId: doc.id,
                                                    initial: data,
                                                  ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: const Color(
                                              0xFF1766B9,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pushNamed(
                                              TrackingMedicineScreen.routePath,
                                              arguments: {
                                                'medicineId': doc.id,
                                                'title': name,
                                                'patientId': patientId,
                                              },
                                            );
                                          },

                                          style: ElevatedButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: const Color(
                                              0xFF1766B9,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Details',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
              );
            },
          ),
        ),
      ),

      // Add medicine for this patient (doctor)
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
            onPressed:
                () => _openAddDialog(
                  FirebaseFirestore.instance.collection('Medicine'),
                  patientId,
                ),
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

  Future<void> _openAddDialog(
    CollectionReference<Map<String, dynamic>> medsCol,
    String patientId,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _AddMedicineDialog(collection: medsCol, patientId: patientId),
    );
  }

  void _showMedDetailsDialog(BuildContext context, Map<String, dynamic> m) {
    final dose = _composeDoseFromDoc(m);
    final times = _formatTimes(m['times'] as List<dynamic>?);
    final longTerm = m['long_term'] == true;
    final start = _dateOnly(m['start_date']);
    final end = _dateOnly(m['end_date']);
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text((m['name'] ?? 'Medication').toString()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dose.isNotEmpty) Text('Dose: $dose'),
                if (times.isNotEmpty) Text('Times: $times'),
                Text(longTerm ? 'Long-term' : 'From $start to $end'),
                if ((m['instruction'] ?? '').toString().isNotEmpty)
                  Text('Instruction: ${m['instruction']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

/// ================= Edit Medicine Dialog (Doctor) =================
class _EditMedicineDialog extends StatefulWidget {
  const _EditMedicineDialog({
    required this.collection,
    required this.docId,
    required this.initial,
  });

  final CollectionReference<Map<String, dynamic>> collection;
  final String docId;
  final Map<String, dynamic> initial;

  @override
  State<_EditMedicineDialog> createState() => _EditMedicineDialogState();
}

class _EditMedicineDialogState extends State<_EditMedicineDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _doseValue; // numeric-only
  late final TextEditingController _pillsPerDay;
  late final TextEditingController _instruction;

  late List<int> _times; // minutes since midnight
  bool _longTerm = true;
  DateTime? _startDate;
  DateTime? _endDate;

  // ToggleButtons state (mutually exclusive)
  final List<String> _units = const ['mg', 'g', 'IU'];
  late List<bool> _unitSelected;

  String get _doseUnit {
    final idx = _unitSelected.indexWhere((e) => e);
    return idx >= 0 ? _units[idx] : 'mg';
  }

  @override
  void initState() {
    super.initState();
    final m = widget.initial;

    _name = TextEditingController(text: (m['name'] ?? '').toString());

    final dv =
        (m['dose_value'] is num)
            ? (m['dose_value'] as num).toDouble()
            : double.tryParse('${m['dose_value'] ?? ''}');
    _doseValue = TextEditingController(
      text: dv == null ? '' : (dv % 1 == 0 ? dv.toInt().toString() : '$dv'),
    );

    _pillsPerDay = TextEditingController(
      text: (m['pills_per_day'] ?? '').toString(),
    );
    _instruction = TextEditingController(
      text: (m['instruction'] ?? '').toString(),
    );

    _times =
        (m['times'] as List<dynamic>? ?? const []).whereType<int>().toList()
          ..sort();

    _longTerm = m['long_term'] == true;
    final start = m['start_date'];
    final end = m['end_date'];
    _startDate = start is Timestamp ? start.toDate() : null;
    _endDate = end is Timestamp ? end.toDate() : null;

    final unit = (m['dose_unit'] ?? 'mg').toString();
    final idx = _units.indexOf(unit);
    _unitSelected = List<bool>.generate(
      _units.length,
      (i) => i == (idx < 0 ? 0 : idx),
    );
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
      initialTime: TimeOfDay(
        hour: now.hour,
        minute: now.minute - now.minute % 5,
      ),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time')),
      );
      return;
    }

    final doseValText = _doseValue.text.trim();
    final doseVal = doseValText.isEmpty ? null : double.tryParse(doseValText);
    if (doseValText.isNotEmpty && doseVal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dose must be a number')));
      return;
    }

    try {
      await widget.collection.doc(widget.docId).update({
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
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicine updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
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
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      hintText: 'e.g., 500',
                      border: OutlineInputBorder(),
                    ),
                  );

                  final unitToggle = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ToggleButtons(
                      isSelected: _unitSelected,
                      onPressed: (idx) {
                        setState(() {
                          _unitSelected = List<bool>.generate(
                            _units.length,
                            (i) => i == idx,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      borderWidth: 1.2,
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        minWidth: 64,
                      ),
                      borderColor: const Color(0xFFCBD5E1),
                      selectedBorderColor: const Color(0xFF1766B9),
                      fillColor: const Color(0x1F1766B9),
                      selectedColor: const Color(0xFF1766B9),
                      color: const Color(0xFF374151),
                      children:
                          _units
                              .map(
                                (u) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
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

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Edit Medicine',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: const Color.fromARGB(255, 29, 96, 170),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  unitToggle,
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
                            unitToggle,
                          ],
                        ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _pillsPerDay,
                        keyboardType: TextInputType.number,
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

                      // time chips + button
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
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007800),
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
                          child: const Text('Save Changes'),
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

/// ================= Add Medicine Dialog (Doctor) =================
class _AddMedicineDialog extends StatefulWidget {
  const _AddMedicineDialog({required this.collection, required this.patientId});

  final CollectionReference<Map<String, dynamic>> collection;
  final String patientId;

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _doseValue = TextEditingController(); // numeric-only
  final _pillsPerDay = TextEditingController();
  final _instruction = TextEditingController();

  final List<int> _times = []; // minutes since midnight
  bool _longTerm = true;
  DateTime? _startDate;
  DateTime? _endDate;

  // ToggleButtons state (mutually exclusive)
  final List<String> _units = const ['mg', 'g', 'IU'];
  List<bool> _unitSelected = [true, false, false]; // default mg

  String get _doseUnit {
    final idx = _unitSelected.indexWhere((e) => e);
    return idx >= 0 ? _units[idx] : 'mg';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time')),
      );
      return;
    }

    final doseValText = _doseValue.text.trim();
    final doseVal = doseValText.isEmpty ? null : double.tryParse(doseValText);
    if (doseValText.isNotEmpty && doseVal == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dose must be a number')));
      return;
    }

    try {
      await widget.collection.add({
        'patient_id': widget.patientId,
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
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicine added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  // Reusable, styled unit selector with safe sizing and scrolling
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
        // colors
        borderColor: const Color(0xFFCBD5E1), // slate-300
        selectedBorderColor: const Color(0xFF1766B9),
        fillColor: const Color(0x1F1766B9), // 12% tint
        selectedColor: const Color(0xFF1766B9),
        color: const Color(0xFF374151), // slate-700
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
                  final narrow = constraints.maxWidth < 420; // adaptive
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

                      // ---- Adaptive dose + unit layout ----
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

                      // time chips + button
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
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007800),
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
