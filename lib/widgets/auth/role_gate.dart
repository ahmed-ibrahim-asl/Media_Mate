import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:media_mate/app_state.dart';
import 'package:media_mate/authentication/select_user_screen.dart';
import 'package:media_mate/widgets/nav/main_nav_bar.dart';
import 'package:provider/provider.dart';

/// Ensures each signed-in user has a Firestore `users` document (create if missing).
/// Then checks their role (doctor/patient) and directs them to the right page.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  // usersRef: reference to the user's document 'users/<uid>'
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadOrCreateUserDoc(
    DocumentReference<Map<String, dynamic>> usersRef,
    User u,
  ) async {
    final doc = await usersRef.get();
    if (!doc.exists) {
      await usersRef.set({
        'email': u.email,
        'display_name': u.displayName,

        // FieldValue.delete(): leave this blank for now, user will fill it in later.
        // if we don't use it we will end up storing "unkown"
        'user_type': FieldValue.delete(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return await usersRef.get();
    }
    return doc;
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const SelectUserScreenWidget();

    final usersRef = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final future = _loadOrCreateUserDoc(usersRef, u);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load your profile.'),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const SelectUserScreenWidget(),
                            ),
                            (r) => false,
                          );
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snap.data?.data();
        final role = (data?['user_type'] as String? ?? '').trim();

        // Update Provider after this frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final appState = context.read<AppState>();
          if (appState.userType != role) {
            appState.userType = role;
          }
        });

        if (role != 'doctor' && role != 'patient') {
          return const SelectUserScreenWidget();
        }

        return const MainNavBarPage();
      },
    );
  }
}
