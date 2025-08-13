// lib/Patient_Screens/home_patient_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    // If viewing today, prefer the next upcoming time; otherwise show the first
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

  // ---------- Calendar ----------
  DateTime _startOfWeek(DateTime d) {
    // Monday as start
    final int weekday = d.weekday; // Mon=1 ... Sun=7
    return DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: weekday - 1));
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

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

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

                // Calendar card
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
                    color: const Color(0xFF222B32),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Medicines list
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

                              // Filter active for selected date and having at least one time
                              final items = <_MedView>[];
                              for (final d in all) {
                                final m = d.data();
                                if (!_isActiveForDate(m, _selectedDate))
                                  continue;
                                final nextTime = _timeForDay(
                                  m['times'] as List<dynamic>?,
                                  _selectedDate,
                                );
                                if (nextTime == null) continue;

                                items.add(
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
                                  ),
                                );
                              }

                              // Sort by time in the selected day
                              items.sort((a, b) {
                                int pa = _parseMinutes(a.timeLabel);
                                int pb = _parseMinutes(b.timeLabel);
                                return pa.compareTo(pb);
                              });

                              if (items.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No medicines scheduled for this day.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF606C77),
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: items.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 16),
                                itemBuilder: (_, i) {
                                  final it = items[i];
                                  final bg =
                                      i.isEven
                                          ? const Color(0xFFFEE0E0) // soft red
                                          : const Color(
                                            0xFFE7F0FE,
                                          ); // soft blue
                                  final meal = _mealHint(it.instruction);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(12),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name.isEmpty
                                              ? 'Unnamed medicine'
                                              : it.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF222B32),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          [
                                            it.timeLabel,
                                            if (it.pillsPerDay > 0)
                                              '${it.pillsPerDay} Pill${it.pillsPerDay == 1 ? '' : 's'}',
                                            if (it.dose.isNotEmpty) it.dose,
                                            if (meal.isNotEmpty) meal,
                                          ].join(' · '),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF222B32),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          it.instruction.isEmpty
                                              ? '—'
                                              : it.instruction,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: const Color(0xFF757575),
                                          ),
                                        ),
                                      ],
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
    );
  }

  // Parses a "h:mm AM/PM" into minutes since midnight for sorting
  int _parseMinutes(String label) {
    // Very small parser based on what _formatTime produces
    // Example: "2:30 PM"
    try {
      final parts = label.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final pm = parts[1].toUpperCase() == 'PM';
      if (h == 12) h = 0;
      return (pm ? (h + 12) : h) * 60 + m;
    } catch (_) {
      return 0;
    }
  }
}

// Simple data holder for the list
class _MedView {
  _MedView({
    required this.id,
    required this.name,
    required this.dose,
    required this.pillsPerDay,
    required this.instruction,
    required this.timeLabel,
  });

  final String id;
  final String name;
  final String dose;
  final int pillsPerDay;
  final String instruction;
  final String timeLabel;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
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
                  color: const Color(0xFF222B32),
                ),
              ),
              const Spacer(),

              // Today (text-only)
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7A5AF5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                child: const Text('Today'),
              ),
              const SizedBox(width: 6),

              // Single calendar icon for date picker
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: onOpenPicker,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  color: const Color(0xFF7A5AF5),
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
            color: selected ? const Color(0xFF7A5AF5) : const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(18),
            boxShadow:
                selected
                    ? const [
                      BoxShadow(
                        color: Color(0x33000000),
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
              color: selected ? Colors.white : const Color(0xFF222B32),
            ),
          ),
        ),
      ),
    );
  }
}
