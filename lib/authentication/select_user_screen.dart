//-------------------------- flutter_core ------------------------------
import 'package:flutter/material.dart';
//----------------------------------------------------------------------

//-------------------------- flutter_packages --------------------------
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
//----------------------------------------------------------------------

//----------------------------- app_local ------------------------------
import '/app_state.dart';
import '/authentication/signIn_screen.dart'; // for SignInScreenWidget.routePath
//----------------------------------------------------------------------

class SelectUserScreenWidget extends StatefulWidget {
  const SelectUserScreenWidget({super.key});

  // Keep the same naming pattern
  static String routeName = 'Select_user_screen';
  static String routePath = '/selectUserScreen';

  @override
  State<SelectUserScreenWidget> createState() => _SelectUserScreenWidgetState();
}

class _SelectUserScreenWidgetState extends State<SelectUserScreenWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _navigating = false;

  void _pickType(String type) {
    context.read<AppState>().userType = type;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goToSignIn() async {
    if (_navigating) return;
    final selected = context.read<AppState>().userType;
    if (selected.isEmpty) {
      _showSnack('Please choose Doctor or Patient first.');
      return;
    }

    setState(() => _navigating = true);
    try {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(SignInScreenWidget.routePath);
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDoctor = appState.userType == 'doctor';
    final isPatient = appState.userType == 'patient';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.fill,
                image: AssetImage('assets/images/Background_image.png'),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // allow scroll on small screens / landscape
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Logo
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              0,
                              50,
                              0,
                              0,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.asset(
                                'assets/images/media_app_icon.png',
                                width: 200.0,
                                height: 200.0,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          // Doctor card
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              0,
                              30,
                              0,
                              0,
                            ),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () => _pickType('doctor'),
                              child: Container(
                                width: 319.0,
                                height: 105.0,
                                decoration: BoxDecoration(
                                  color:
                                      isDoctor
                                          ? const Color(0xFF56C9FF)
                                          : Colors.white,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(14.0),
                                  ),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Align(
                                      alignment: const AlignmentDirectional(
                                        -1.0,
                                        0.0,
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                              10.0,
                                              13.0,
                                              0.0,
                                              0.0,
                                            ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                          child: Image.asset(
                                            'assets/images/Doctors_image.png',
                                            width: 116.6,
                                            height: 193.6,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: const AlignmentDirectional(
                                        0.0,
                                        0.0,
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.fromSTEB(
                                              12.0,
                                              0.0,
                                              0.0,
                                              0.0,
                                            ),
                                        child: Text(
                                          'I am a Doctor',
                                          style: GoogleFonts.inter(
                                            fontSize: 25.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Patient card
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              0,
                              50,
                              0,
                              0,
                            ),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () => _pickType('patient'),
                              child: Container(
                                width: 319.0,
                                height: 105.0,
                                decoration: BoxDecoration(
                                  color:
                                      isPatient
                                          ? const Color(0xFF56C9FF)
                                          : Colors.white,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(14.0),
                                  ),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                            10.0,
                                            13.0,
                                            0.0,
                                            0.0,
                                          ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        child: Image.asset(
                                          'assets/images/patient_image.png',
                                          width: 109.29,
                                          height: 200.0,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                            12.0,
                                            0.0,
                                            0.0,
                                            0.0,
                                          ),
                                      child: Text(
                                        'I am a Patient',
                                        style: GoogleFonts.inter(
                                          fontSize: 25.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Push the action button area to the bottom when space allows
                          const Spacer(),

                          // Forward button (bottom-right look)
                          Align(
                            alignment: const AlignmentDirectional(1.0, 0.0),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                65.0,
                                30.0,
                                0.0,
                              ),
                              child: Opacity(
                                opacity:
                                    (isDoctor || isPatient) && !_navigating
                                        ? 1.0
                                        : 0.6,
                                child: IgnorePointer(
                                  ignoring:
                                      !(isDoctor || isPatient) || _navigating,
                                  child: Container(
                                    width: 75.0,
                                    height: 75.0,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF499EE2),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 4.0,
                                          color: Color(0x33000000),
                                          offset: Offset(0.0, 2.0),
                                        ),
                                      ],
                                      shape: BoxShape.circle,
                                    ),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: _goToSignIn,
                                      child: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white,
                                        size: 45.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_navigating)
                            Padding(
                              padding: const EdgeInsets.only(right: 30.0),
                              child: Text(
                                'Opening sign-in…',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Color(0xFF62686D),
                                ),
                              ),
                            ),

                          // Bottom padding so the circle button isn't flush with nav bars
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
