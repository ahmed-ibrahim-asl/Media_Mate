//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import 'package:media_mate/theme/colors.dart';
import 'package:media_mate/widgets/async/loading_scaffold.dart';
//----------------------------------------------------------------------

class TrackingMedicineScreen extends StatefulWidget {
  const TrackingMedicineScreen({
    super.key,
    this.medicineId,
    this.title,
    this.patientId,
  });

  static const String routePath = '/trackingMedicine';

  final String? medicineId;
  final String? title;
  final String? patientId;

  @override
  State<TrackingMedicineScreen> createState() => _TrackingMedicineScreenState();
}

class _TrackingMedicineScreenState extends State<TrackingMedicineScreen> {
  late DateTime _visibleMonth;

  // Inputs resolved from constructor/route (set in didChangeDependencies)
  String? _effectiveMedId;
  String? _effectivePatientId;
  String _screenTitle = 'Medicine';

  bool _didInitDeps = false;

  // Assignment gating
  Set<String> _assignedPatientIds = {};
  bool _loadingPatients = true;

  // Medicine meta
  List<int> _scheduledTimes = [];
  String? _medicinePatientId;
  bool _loadingMedMeta = true;

  // Course window
  bool _longTerm = true;
  DateTime? _courseStart; // date-only
  DateTime? _courseEnd; // date-only (null if long-term)
  DateTime? _createdAt; // date-only (fallback if no start_date)

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _loadAssignedPatients();
    // DO NOT access ModalRoute here.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitDeps) return;
    _didInitDeps = true;

    // Safely read route args here
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;

    _effectiveMedId = widget.medicineId ?? args['medicineId'] as String?;
    _effectivePatientId = widget.patientId ?? args['patientId'] as String?;
    _screenTitle = widget.title ?? (args['title'] as String?) ?? 'Medicine';

    // Now that we have IDs, load medicine meta
    _loadMedicineMeta();
  }

  Future<void> _loadAssignedPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _assignedPatientIds = {};
        _loadingPatients = false;
      });
      return;
    }
    final snap =
        await FirebaseFirestore.instance
            .collection('patients')
            .where('assigned_doctor_id', isEqualTo: user.uid)
            .get();

    setState(() {
      _assignedPatientIds = snap.docs.map((d) => d.id).toSet();
      _loadingPatients = false;
    });
  }

  Future<void> _loadMedicineMeta() async {
    final medId = _effectiveMedId;
    if (medId == null || medId.isEmpty) {
      setState(() {
        _scheduledTimes = [];
        _medicinePatientId = null;
        _loadingMedMeta = false;
      });
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('Medicine')
              .doc(medId)
              .get();
      final data = doc.data();

      final times =
          (data?['times'] as List<dynamic>? ?? const [])
              .whereType<int>()
              .toList()
            ..sort();

      final pid = (data?['patient_id'] ?? '').toString().trim();

      // load course window
      final longTerm = data?['long_term'] == true;

      DateTime? start;
      final rawStart = data?['start_date'];
      if (rawStart is Timestamp) start = rawStart.toDate();
      if (rawStart is DateTime) start = rawStart;

      DateTime? end;
      final rawEnd = data?['end_date'];
      if (rawEnd is Timestamp) end = rawEnd.toDate();
      if (rawEnd is DateTime) end = rawEnd;

      DateTime? created;
      final rawCreated = data?['created_at'];
      if (rawCreated is Timestamp) created = rawCreated.toDate();
      if (rawCreated is DateTime) created = rawCreated;

      setState(() {
        _scheduledTimes = times;
        _medicinePatientId = pid.isEmpty ? null : pid;

        _longTerm = longTerm;
        _courseStart =
            start != null
                ? _dateOnly(start)
                : (created != null ? _dateOnly(created) : null);
        _courseEnd = longTerm ? null : (end != null ? _dateOnly(end) : null);
        _createdAt = created != null ? _dateOnly(created) : null;

        _loadingMedMeta = false;
      });
    } catch (_) {
      setState(() {
        _scheduledTimes = [];
        _medicinePatientId = null;
        _loadingMedMeta = false;
      });
    }
  }

  // Month helpers
  DateTime _monthStart(DateTime m) => DateTime(m.year, m.month, 1);
  DateTime _monthEndExclusive(DateTime m) => DateTime(m.year, m.month + 1, 1);
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

  Stream<QuerySnapshot<Map<String, dynamic>>>? _logsStreamForMonth() {
    final medId = _effectiveMedId;
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

  Future<String> _getPatientName(String patientId) async {
    try {
      if (patientId.isEmpty) return '';
      final doc =
          await FirebaseFirestore.instance
              .collection('patients')
              .doc(patientId)
              .get();
      if (doc.exists) {
        final data = doc.data();
        final dn = (data?['display_name'] ?? '').toString().trim();
        if (dn.isNotEmpty) return dn;
        final em = (data?['email'] ?? '').toString();
        if (em.isNotEmpty) return em;
      }
    } catch (_) {}
    return patientId;
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  bool _doctorCanView() {
    // Prefer the owner on the medicine doc; fall back to the patientId passed in
    final effectivePid = _medicinePatientId ?? _effectivePatientId;
    if (effectivePid == null || effectivePid.isEmpty)
      return true; // be permissive
    if (_assignedPatientIds.isEmpty)
      return true; // if not loaded, don't hard-block
    return _assignedPatientIds.contains(effectivePid);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPatients || _loadingMedMeta) {
      return const LoadingScaffold(message: 'Loading your profile…');
    }

    if (!_doctorCanView()) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'This medicine belongs to a patient who is not assigned to you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    final stream = _logsStreamForMonth();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.bgTop, AppColors.bgBottom],
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
                              _screenTitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textMuted,
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

              if (stream == null)
                _calendarCard(const [])
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
    );
  }

  /// Calendar card where every scheduled slot in the **active window**
  /// is red by default, and flips to green when a taken:true log exists.
  Widget _calendarCard(List<QueryDocumentSnapshot<Map<String, dynamic>>> logs) {
    final takenMap = <int, Map<int, List<Map<String, dynamic>>>>{};
    final missedMap = <int, Map<int, List<Map<String, dynamic>>>>{};

    final daysInMonth = _daysInMonth(_visibleMonth);
    final first = _monthStart(_visibleMonth);
    final weekdayMonBased = first.weekday; // 1=Mon ... 7=Sun
    final offset = (weekdayMonBased + 5) % 7; // Sat=0, Fri=6

    // Active window boundaries for prefill
    final today = _dateOnly(DateTime.now());
    final startBoundary = _courseStart; // may be null
    // If no explicit end, cap at today; otherwise also cap at today
    final endBoundary = () {
      final e = _courseEnd ?? today;
      return e.isAfter(today) ? today : e;
    }();

    // Prefill MISSED (red) ONLY for days within active window
    final defaultEntry = {'patient_id': _medicinePatientId ?? ''};
    if (_scheduledTimes.isNotEmpty && startBoundary != null) {
      for (var day = 1; day <= daysInMonth; day++) {
        final dayDate = DateTime(_visibleMonth.year, _visibleMonth.month, day);
        final dayOnly = _dateOnly(dayDate);
        final inWindow =
            !dayOnly.isBefore(startBoundary) && !dayOnly.isAfter(endBoundary);
        if (!inWindow) continue;

        for (final t in _scheduledTimes) {
          missedMap.putIfAbsent(day, () => {});
          missedMap[day]!.putIfAbsent(t, () => []);
          missedMap[day]![t] = [defaultEntry];
        }
      }
    }

    // Apply logs to flip red -> green
    for (final doc in logs) {
      final data = doc.data();
      final ts = data['date'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.month != _visibleMonth.month || dt.year != _visibleMonth.year) {
        continue;
      }

      final day = dt.day;
      final isTaken = data['taken'] == true;
      final logPatientId = (data['patient_id'] ?? '').toString();
      final scheduledTime = data['scheduled_time'] as int? ?? 0;

      // If medicine doc has an owner, keep only their logs
      if ((_medicinePatientId ?? '').isNotEmpty &&
          logPatientId != _medicinePatientId) {
        continue;
      }

      if (isTaken) {
        takenMap.putIfAbsent(day, () => {});
        takenMap[day]!.putIfAbsent(scheduledTime, () => []);
        takenMap[day]![scheduledTime]!.add({'patient_id': logPatientId});

        if (missedMap[day]?.containsKey(scheduledTime) ?? false) {
          missedMap[day]!.remove(scheduledTime);
          if (missedMap[day]!.isEmpty) missedMap.remove(day);
        }
      } else {
        if (!(takenMap[day]?.containsKey(scheduledTime) ?? false)) {
          missedMap.putIfAbsent(day, () => {});
          missedMap[day]!.putIfAbsent(scheduledTime, () => []);
          if (missedMap[day]![scheduledTime]!.isEmpty) {
            missedMap[day]![scheduledTime]!.add({'patient_id': logPatientId});
          }
        }
      }
    }

    // Adherence by slot: only consider days within the active window
    int totalSlots = 0;
    int takenCount = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final dayDate = _dateOnly(
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
      );
      final inWindow =
          startBoundary != null &&
          !dayDate.isBefore(startBoundary) &&
          !dayDate.isAfter(endBoundary);

      if (!inWindow) continue;
      totalSlots += _scheduledTimes.length;
      takenCount += (takenMap[day]?.length ?? 0);
    }
    final missedCount = totalSlots - takenCount;
    final adherence = totalSlots == 0 ? 0.0 : takenCount / totalSlots;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          children: [
            // Calendar
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
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
                  const _WeekHeader(),
                  const SizedBox(height: 8),
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
                      if (index < offset) return const SizedBox.shrink();
                      final dayNum = index - offset + 1;
                      final isTaken = takenMap.containsKey(dayNum);
                      final isMissed = missedMap.containsKey(dayNum);

                      Color? bubble;
                      if (_scheduledTimes.isEmpty) {
                        bubble = null;
                      } else if (isMissed) {
                        bubble = AppColors.error; // red by default
                      } else if (isTaken) {
                        bubble = AppColors.success; // green
                      }

                      return GestureDetector(
                        onTap: () {
                          final takenForDay = takenMap[dayNum] ?? {};
                          final missedForDay = missedMap[dayNum] ?? {};
                          if (takenForDay.isEmpty && missedForDay.isEmpty) {
                            return;
                          }
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            builder:
                                (_) => Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Day $dayNum — ${_monthLabel(_visibleMonth)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 10),
                                        ..._buildDoseTimeSections(
                                          takenForDay,
                                          missedForDay,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                        child: Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: bubble,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNum',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    bubble == null
                                        ? AppColors.text
                                        : AppColors.surface,
                              ),
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

            // Adherence
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
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
                      const _LegendDot(color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Taken: $takenCount',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 18),
                      const _LegendDot(color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        'Missed: $missedCount',
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
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

  List<Widget> _buildDoseTimeSections(
    Map<int, List<Map<String, dynamic>>> takenForDay,
    Map<int, List<Map<String, dynamic>>> missedForDay,
  ) {
    final allTimes =
        <int>{...takenForDay.keys, ...missedForDay.keys}.toList()..sort();

    final widgets = <Widget>[];
    for (var time in allTimes) {
      widgets.add(
        Text(
          'Scheduled time: ${_formatTime(time)}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );

      final takenPatients = takenForDay[time] ?? [];
      final missedPatients = missedForDay[time] ?? [];

      if (takenPatients.isNotEmpty) {
        widgets.add(
          Text(
            'Taken:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        );
        widgets.addAll(
          takenPatients.map(
            (p) => FutureBuilder<String>(
              future: _getPatientName((p['patient_id'] ?? '').toString()),
              builder: (context, snap) {
                final name = (snap.data ?? p['patient_id'] ?? '').toString();
                return ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                  title: Text(name, style: GoogleFonts.inter()),
                  subtitle: const Text('Took medicine'),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        );
      }

      if (missedPatients.isNotEmpty) {
        widgets.add(
          Text(
            'Missed:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        );
        widgets.addAll(
          missedPatients.map(
            (p) => FutureBuilder<String>(
              future: _getPatientName((p['patient_id'] ?? '').toString()),
              builder: (context, snap) {
                final name = (snap.data ?? p['patient_id'] ?? '').toString();
                return ListTile(
                  leading: const Icon(Icons.cancel, color: AppColors.error),
                  title: Text(name, style: GoogleFonts.inter()),
                  subtitle: const Text('Missed medicine'),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _Dow('Sat'),
        _Dow('Sun'),
        _Dow('Mon'),
        _Dow('Tue'),
        _Dow('Wed'),
        _Dow('Thu'),
        _Dow('Fri'),
      ],
    );
  }
}

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
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

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
