import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrackingMedicineScreen extends StatefulWidget {
  const TrackingMedicineScreen({
    super.key,
    this.medicineId,
    this.title, // e.g. "Panadol 500 mg"
  });

  static const String routePath = '/trackingMedicine';

  final String? medicineId;
  final String? title;

  @override
  State<TrackingMedicineScreen> createState() => _TrackingMedicineScreenState();
}

class _TrackingMedicineScreenState extends State<TrackingMedicineScreen> {
  late DateTime _visibleMonth; // normalized to first day of month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  // ---- Month helpers ----
  DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _monthEndExclusive(DateTime m) =>
      DateTime(m.year, m.month + 1, 1); // exclusive upper bound
  int _daysInMonth(DateTime m) => DateUtils.getDaysInMonth(m.year, m.month);

  String _monthLabel(DateTime m) {
    const mon = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${mon[m.month - 1]} ${m.year}';
  }

  // ---- Firestore stream for this month (optional) ----
  Stream<QuerySnapshot<Map<String, dynamic>>>? _logsStreamForMonth() {
    final medId =
        widget.medicineId ??
        ((ModalRoute.of(context)?.settings.arguments as Map?)?['medicineId']
            as String?);
    if (medId == null || medId.isEmpty) return null;

    final start = _monthStart(_visibleMonth);
    final end = _monthEndExclusive(_visibleMonth);

    return FirebaseFirestore.instance
        .collection('Medicine')
        .doc(medId)
        .collection('logs')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;
    final screenTitle =
        widget.title ?? (args['title'] as String?) ?? 'Medicine';

    final stream = _logsStreamForMonth();

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
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 4),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Medication Tracker',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4B6B7D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              screenTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Calendar card with monthly stats
              if (stream == null)
                _calendarCard(const [] /* no logs */)
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? const [];
                    return _calendarCard(docs);
                  },
                ),
            ],
          ),
        ),
      ),

      // Static bottom bar (visual only, per your mock)
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: BottomNavigationBar(
            currentIndex: 0,
            onTap: (_) {},
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Renders the calendar and the "Monthly Adherence" card
  Widget _calendarCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    // Build sets of taken/missed day numbers for the visible month
    final taken = <int>{};
    final missed = <int>{};

    for (final d in logs) {
      final data = d.data();
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.month != _visibleMonth.month || dt.year != _visibleMonth.year) {
        continue;
      }
      final day = dt.day;
      final isTaken = data['taken'] == true;
      if (isTaken) {
        taken.add(day);
        missed.remove(day); // prefer taken if both somehow exist
      } else {
        if (!taken.contains(day)) missed.add(day);
      }
    }

    final daysInMonth = _daysInMonth(_visibleMonth);
    final first = _monthStart(_visibleMonth);
    // We’ll show the week starting on Saturday (to match your mock).
    // Flutter’s weekday: Mon=1 ... Sun=7. We compute a Saturday-based offset.
    final weekdayMonBased = first.weekday; // 1..7
    // Convert to Saturday=0..Friday=6
    final offset = (weekdayMonBased % 7 + 1) % 7; // small tweak to start Sat

    final totalMarked = taken.length + missed.length;
    final adherence =
        totalMarked == 0 ? 0.0 : (taken.length / totalMarked.toDouble());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          children: [
            // Calendar card
            Container(
              width: double.infinity,
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month - 1,
                              1,
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _monthLabel(_visibleMonth),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _visibleMonth = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                              1,
                            );
                          });
                        },
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Weekday row (Sat .. Fri to match your mock)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _Dow('Sat'),
                      _Dow('Mon'),
                      _Dow('Tue'),
                      _Dow('Wen'),
                      _Dow('Thur'),
                      _Dow('Fri'),
                      _Dow('Sat'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Calendar grid
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: offset + daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisExtent: 38,
                        ),
                    itemBuilder: (_, index) {
                      if (index < offset) {
                        return const SizedBox.shrink();
                      }
                      final day = index - offset + 1;
                      final isTaken = taken.contains(day);
                      final isMissed = missed.contains(day);

                      Color? bubble;
                      if (isTaken) bubble = const Color(0xFF22C55E); // green
                      if (isMissed) bubble = const Color(0xFFEF4444); // red

                      return Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: bubble,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  bubble == null
                                      ? const Color(0xFF111827)
                                      : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Monthly adherence card
            Container(
              width: double.infinity,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Adherence',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const _LegendDot(color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text(
                        'Taken: ${taken.length}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 18),
                      const _LegendDot(color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(
                        'Missed: ${missed.length}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: adherence.clamp(0.0, 1.0),
                      minHeight: 16,
                      backgroundColor: const Color(0xFFD1D5DB),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF22C55E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small weekday label
class _Dow extends StatelessWidget {
  const _Dow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// Little colored dot for legend
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
