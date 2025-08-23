// Should i show the login screen, or should i take the user into the app
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:media_mate/authentication/select_user_screen.dart';
import 'package:media_mate/widgets/auth/role_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder: listens to changes over time
    // authStateChanges: tells us if the user is logged in or not

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const SelectUserScreenWidget();
        return const RoleGate();
      },
    );
  }
}
