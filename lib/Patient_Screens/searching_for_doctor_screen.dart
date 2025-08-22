//-------------------------- flutter_core ----------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
//----------------------------------------------------------------------

import 'package:media_mate/theme/colors.dart';

class SearchingForDoctorScreenWidget extends StatefulWidget {
  const SearchingForDoctorScreenWidget({super.key});

  static String routeName = 'searchingForDoctor_screen';
  static String routePath = '/searchingForDoctorScreen';

  @override
  State<SearchingForDoctorScreenWidget> createState() =>
      _SearchingForDoctorScreenWidgetState();
}

class _SearchingForDoctorScreenWidgetState
    extends State<SearchingForDoctorScreenWidget> {
  static const String kDoctorsCollection = 'doctors';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  int? _ageFrom(dynamic rawDob) {
    DateTime? dob;
    if (rawDob is Timestamp) {
      dob = rawDob.toDate();
    } else if (rawDob is DateTime) {
      dob = rawDob;
    } else if (rawDob is String) {
      dob = DateTime.tryParse(rawDob);
    }
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String _doctorName(String raw) {
    final n = raw.trim();
    final lower = n.toLowerCase();
    if (lower.startsWith('dr/') || lower.startsWith('dr ') || lower == 'dr') {
      return n;
    }

    return 'Dr/ $n'; // keep as-is; your docs use `display_name`
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocus.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
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
                // Header
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Color(0xFF62686D),
                            size: 28,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Searching for Doctor',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF668393),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          const Icon(Icons.search, color: Color(0xFFB1B1B1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              decoration: const InputDecoration(
                                hintText: 'Search doctors...',
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // Clear assignment card
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _NoDoctorCard(
                      onSelect: () {
                        Navigator.pop(context, {
                          'clear': true,
                          'id': null,
                          'name': null,
                          'photoUrl': null,
                        });
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // Doctors list (from /doctors)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection(kDoctorsCollection)
                          .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Text(
                            'Can’t load doctors (permissions or schema).',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final q = _searchCtrl.text.trim().toLowerCase();
                    final items =
                        snap.data!.docs
                            .map((d) {
                              final m = d.data();
                              final rawName =
                                  (m['display_name'] ??
                                          m['name'] ??
                                          m['full_name'] ??
                                          '')
                                      .toString();
                              final phone =
                                  (m['phone_number'] ?? m['phone'] ?? '')
                                      .toString();
                              final gender = (m['gender'] ?? 'N/A').toString();
                              final age = _ageFrom(
                                m['date_of_birth'] ?? m['dateOfBirth'],
                              );
                              final photoUrl =
                                  (m['photo_url'] ?? '').toString();

                              return _DoctorVM(
                                id: d.id,
                                name: _doctorName(rawName),
                                phone: phone,
                                gender: gender,
                                ageText:
                                    (age != null) ? '$age years old' : 'N/A',
                                photoUrl: photoUrl,
                              );
                            })
                            .where((e) {
                              if (q.isEmpty) return true;
                              return e.name.toLowerCase().contains(q) ||
                                  e.phone.toLowerCase().contains(q);
                            })
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));

                    if (items.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Text(
                            'No matching doctors.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    return SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final doc = items[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFFE9EEF2),
                                  backgroundImage:
                                      (doc.photoUrl.isNotEmpty)
                                          ? NetworkImage(doc.photoUrl)
                                          : null,
                                  child:
                                      (doc.photoUrl.isEmpty)
                                          ? const Icon(
                                            Icons.person,
                                            size: 30,
                                            color: Color(0xFF8A9AA7),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.name.isEmpty
                                            ? 'Dr/ Unnamed'
                                            : doc.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF222B32),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${doc.gender}, ${doc.ageText}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF606C77),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        doc.phone.isEmpty ? '—' : doc.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF606C77),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 12,
                                    top: 12,
                                    bottom: 12,
                                  ),
                                  child: SizedBox(
                                    height: 28,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context, {
                                          'id': doc.id,
                                          'name': doc.name,
                                          'photoUrl': doc.photoUrl,
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: const Color(
                                          0xFF327BF1,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        minimumSize: const Size(74, 28),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Select',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoDoctorCard extends StatelessWidget {
  const _NoDoctorCard({required this.onSelect});
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE9EEF2),
            child: Icon(Icons.person_off, size: 30, color: Color(0xFF8A9AA7)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No doctor (I’ll assign later)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222B32),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Choose this to remove current assignment.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF606C77),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
            child: SizedBox(
              height: 28,
              child: OutlinedButton(
                onPressed: onSelect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF327BF1),
                  side: const BorderSide(color: Color(0xFF327BF1)),
                  minimumSize: const Size(74, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Select',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorVM {
  final String id;
  final String name;
  final String phone;
  final String gender;
  final String ageText;
  final String photoUrl;
  _DoctorVM({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.ageText,
    required this.photoUrl,
  });
}
