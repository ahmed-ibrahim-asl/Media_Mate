//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import 'package:media_mate/services/bluetooth_service.dart';
import 'package:media_mate/theme/colors.dart';
//----------------------------------------------------------------------

class HomePatientScreen extends StatefulWidget {
  const HomePatientScreen({super.key});

  static const String routeName = 'home_patient_screen';
  static const String routePath = '/homePatient';

  @override
  State<HomePatientScreen> createState() => _HomePatientScreenState();
}

class _HomePatientScreenState extends State<HomePatientScreen> {
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _medsCol =>
      FirebaseFirestore.instance.collection('Medicine');

  DateTime _selectedDate = DateTime.now();

  // Maintain a map of selected medicine IDs to bool
  final Map<String, bool> _selectedMeds = {};

  // Maintain map to store container info of selected medicines
  final Map<String, int> _medContainers = {};

  // ---------- Helpers ----------
  String _greetingName() {
    final user = _auth.currentUser;
    if (user == null) return 'there';
    if ((user.displayName ?? '').trim().isNotEmpty) {
      return user.displayName!.trim().split(' ').first;
    }
    final email = user.email ?? '';
    return email.contains('@') ? email.split('@').first : 'there';
  }

  String _formatTime(int minutesSinceMidnight) {
    final h = minutesSinceMidnight ~/ 60;
    final m = minutesSinceMidnight % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  int? _timeForDay(List<dynamic>? raw, DateTime day) {
    if (raw == null || raw.isEmpty) return null;
    final minutes = raw.whereType<int>().toList()..sort();
    final now = DateTime.now();
    if (_isSameDay(day, now)) {
      final nowMin = now.hour * 60 + now.minute;
      for (final t in minutes) {
        if (t >= nowMin) return t;
      }
    }
    return minutes.first;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isActiveForDate(Map<String, dynamic> m, DateTime day) {
    final bool longTerm = (m['long_term'] == true);
    if (longTerm) return true;

    final tsStart = m['start_date'];
    final tsEnd = m['end_date'];

    DateTime? start;
    DateTime? end;

    if (tsStart is Timestamp) {
      final d = tsStart.toDate();
      start = DateTime(d.year, d.month, d.day);
    }
    if (tsEnd is Timestamp) {
      final d = tsEnd.toDate();
      end = DateTime(d.year, d.month, d.day);
    }

    final dayOnly = DateTime(day.year, day.month, day.day);
    if (start != null && dayOnly.isBefore(start)) return false;
    if (end != null && dayOnly.isAfter(end)) return false;
    return true;
  }

  String _mealHint(String instruction) {
    final lc = instruction.toLowerCase();
    if (lc.contains('before')) return 'Before Meal';
    if (lc.contains('after')) return 'After Meal';
    return '';
  }

  Future<void> _pickAnyDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  void _onCheckboxChanged(String medId, bool? value, int container) {
    print(container);

    setState(() {
      if (value == true) {
        _selectedMeds[medId] = true;
        _medContainers[medId] = container;
      } else {
        _selectedMeds.remove(medId);
        _medContainers.remove(medId);
      }
    });
  }

  // Your provided method with char array and flag 'X'
  Future<void> _onTakeButtonPressed() async {
    if (_selectedMeds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No medicines selected.')));
      return;
    }

    // Bits for your hardware payload: 3 containers + trailing 'X'
    final List<String> containerArray = ['0', '0', '0'];
    final String? patientAuthUid = _auth.currentUser?.uid;
    if (patientAuthUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are signed out.')));
      return;
    }

    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();

    int writtenLogs = 0; // for UX feedback
    int skippedMissingDoc = 0; // med deleted or id invalid
    int skippedNoTimes = 0; // no schedule => nothing to mark

    // Pre-read & validate selected meds, set container bits, and queue logs
    for (final medId in _selectedMeds.keys) {
      if (medId.trim().isEmpty) continue;

      final medRef = FirebaseFirestore.instance
          .collection('Medicine')
          .doc(medId);
      final medSnap = await medRef.get();

      // 1) Parent doc must exist -> otherwise we’d create a “ghost parent”
      if (!medSnap.exists) {
        skippedMissingDoc++;
        continue;
      }

      // 2) Extract & validate times (must be ints: minutes since midnight)
      final times =
          (medSnap.data()?['times'] as List?)?.whereType<int>().toList() ??
          const <int>[];
      if (times.isEmpty) {
        skippedNoTimes++;
        continue;
      }

      // 3) Set hardware container bit if present
      final container = _medContainers[medId];
      if (container != null && container >= 1 && container <= 3) {
        containerArray[container - 1] = '1';
      }

      // 4) Queue one log per scheduled time (taken = true)
      for (final scheduledTime in times) {
        final logRef =
            medRef.collection('logs').doc(); // batch requires doc().set
        batch.set(logRef, {
          'patient_id': patientAuthUid, // patient’s FirebaseAuth UID
          'taken': true,
          'date': Timestamp.fromDate(now),
          'scheduled_time': scheduledTime, // int (minutes since midnight)
          'created_at': FieldValue.serverTimestamp(), // optional: audit
          'source': 'patient_app', // optional: audit
        });
        writtenLogs++;
      }
    }

    // 5) Commit the logs first; only send Bluetooth if DB write succeeded
    try {
      if (writtenLogs > 0) {
        await batch.commit();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save logs: $e')));
      return; // don’t send hardware message if DB failed
    }

    // 6) Build & send the hardware message
    containerArray.add('X');
    final String messageToSend = containerArray.join();
    try {
      await BluetoothService().send(messageToSend);
      final parts = <String>[
        if (writtenLogs > 0)
          'Logged $writtenLogs time${writtenLogs == 1 ? '' : 's'}',
        if (skippedMissingDoc > 0)
          'Skipped $skippedMissingDoc deleted/unknown medicine${skippedMissingDoc == 1 ? '' : 's'}',
        if (skippedNoTimes > 0)
          'Skipped $skippedNoTimes medicine${skippedNoTimes == 1 ? '' : 's'} with no times',
        'Sent code: $messageToSend',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join(' • '))));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending to device: $e')));
    }

    // 7) Reset selection
    setState(() {
      _selectedMeds.clear();
      _medContainers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.bgTop, AppColors.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Welcome ${_greetingName()}!',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF668393),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _CalendarCard(
                  date: _selectedDate,
                  onToday: () => setState(() => _selectedDate = DateTime.now()),
                  onOpenPicker: _pickAnyDate,
                  onDayTap: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: 20),
                Text(
                  'Medicines Today',
                  style: GoogleFonts.inter(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      uid == null
                          ? Center(
                            child: Text(
                              'You are signed out.',
                              style: GoogleFonts.inter(),
                            ),
                          )
                          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                      'Error: ${snap.error}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              if (!snap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                );
                              }
                              final all = snap.data!.docs;
                              final meds = <_MedView>[];
                              for (final d in all) {
                                final m = d.data();
                                if (!_isActiveForDate(m, _selectedDate))
                                  continue;
                                final nextTime = _timeForDay(
                                  m['times'] as List<dynamic>?,
                                  _selectedDate,
                                );
                                if (nextTime == null) continue;

                                meds.add(
                                  _MedView(
                                    id: d.id,
                                    name: (m['name'] ?? '').toString(),
                                    dose: (m['dose'] ?? '').toString(),
                                    pillsPerDay:
                                        (m['pills_per_day'] is int)
                                            ? m['pills_per_day'] as int
                                            : int.tryParse(
                                                  '${m['pills_per_day'] ?? 0}',
                                                ) ??
                                                0,
                                    instruction:
                                        (m['instruction'] ?? '').toString(),
                                    timeLabel: _formatTime(nextTime),
                                    container: m['container_number'],
                                  ),
                                );
                              }
                              meds.sort(
                                (a, b) => _parseMinutes(
                                  a.timeLabel,
                                ).compareTo(_parseMinutes(b.timeLabel)),
                              );
                              if (meds.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No medicines scheduled for this day.',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      itemCount: meds.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 16),
                                      itemBuilder: (context, i) {
                                        final med = meds[i];
                                        final bg =
                                            i.isEven
                                                ? const Color(0xFFFEE0E0)
                                                : const Color(0xFFE7F0FE);
                                        final meal = _mealHint(med.instruction);
                                        final checked =
                                            _selectedMeds[med.id] ?? false;
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x22000000),
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            14,
                                            16,
                                            14,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      med.name.isEmpty
                                                          ? 'Unnamed medicine'
                                                          : med.name,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                          0xFF222B32,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      [
                                                        med.timeLabel,
                                                        if (med.pillsPerDay > 0)
                                                          '${med.pillsPerDay} Pill${med.pillsPerDay == 1 ? '' : 's'}',
                                                        if (med.dose.isNotEmpty)
                                                          med.dose,
                                                        if (meal.isNotEmpty)
                                                          meal,
                                                        'Container ${med.container}',
                                                      ].join(' · '),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                          0xFF222B32,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      med.instruction.isEmpty
                                                          ? '—'
                                                          : med.instruction,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        color: const Color(
                                                          0xFF757575,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Checkbox(
                                                value: checked,
                                                onChanged:
                                                    (v) => _onCheckboxChanged(
                                                      med.id,
                                                      v,
                                                      med.container,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                activeColor: const Color(
                                                  0xFF7A5AF5,
                                                ),
                                                checkColor: AppColors.surface,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _onTakeButtonPressed,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFF7A5AF5,
                                        ),
                                      ),
                                      child: Text(
                                        'Take',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.surface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _parseMinutes(String label) {
    try {
      // Expect things like: "2:30 PM", "12:05 am"
      final parts = label.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) return 0;

      final timePart = parts[0]; // "2:30"
      final amPm = parts[1].toUpperCase(); // "PM"

      final hm = timePart.split(':');
      if (hm.length < 2) return 0;

      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);

      // Normalize to 24h
      if (amPm == 'PM' && h != 12) {
        h += 12;
      } else if (amPm == 'AM' && h == 12) {
        h = 0;
      }

      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }
}

// Simple data holder for medicines with container info
class _MedView {
  _MedView({
    required this.id,
    required this.name,
    required this.dose,
    required this.pillsPerDay,
    required this.instruction,
    required this.timeLabel,
    required this.container,
  });

  final String id;
  final String name;
  final String dose;
  final int pillsPerDay;
  final String instruction;
  final String timeLabel;
  final int container;
}

// ---------- Calendar card widget ----------
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.date,
    required this.onToday,
    required this.onOpenPicker,
    required this.onDayTap,
  });

  final DateTime date;
  final VoidCallback onToday;
  final VoidCallback onOpenPicker;
  final ValueChanged<DateTime> onDayTap;

  DateTime _startOfWeek(DateTime d) {
    final int weekday = d.weekday; // Mon=1..Sun=7
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(date);
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
    );
    final monthTitle = '${_monthName(date.month)} ${date.year}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                monthTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                child: const Text('Today'),
              ),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: onOpenPicker,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  color: AppColors.secondary,
                  tooltip: 'Pick a date',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri'),
              _WeekdayLabel('Sat'),
              _WeekdayLabel('Sun'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children:
                days
                    .map(
                      (d) => Expanded(
                        child: _DayCell(
                          date: d,
                          selected: _isSameDay(d, date),
                          onTap: () => onDayTap(d),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFF7B8994),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayNum = date.day.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(18),
            boxShadow:
                selected
                    ? const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            dayNum,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.surface : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
