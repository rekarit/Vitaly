import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_scope.dart';
import 'core/state/app_state.dart';
import 'core/state/app_state_scope.dart';
import 'modules/navigation/login_screen.dart';
import 'modules/navigation/main_layout_screen.dart';
import 'modules/data_entry/data_entry_screen.dart';

/// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// VITALY APP â€” Entry Point
/// Run:  flutter run -d chrome   â†’ Web
///       flutter run -d windows  â†’ Native Desktop
///       flutter run             â†’ Default connected device
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.initialize();
  final state = AppState();
  final themeCtrl = ThemeController();

  runApp(
    ThemeScope(
      controller: themeCtrl,
      child: AppStateScope(
        state: state,
        child: const VitalyApp(),
      ),
    ),
  );
}

class VitalyApp extends StatelessWidget {
  const VitalyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeScope.of(context);

    return MaterialApp(
      title:                      'Vitaly App — Luxury Stone & Wood ERP',
      theme:                      AppTheme.light,
      darkTheme:                  AppTheme.dark,
      themeMode:                  themeCtrl.themeMode,
      themeAnimationDuration:     Duration.zero,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            // Dismiss keyboard cleanly when user taps on blank / outside areas
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      home:                       const SplashScreen(),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────────
/// SPLASH SCREEN — animated logo reveal, then navigates to MainLayoutScreen
/// ────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 450), _navigateToShell);
  }

  void _navigateToShell() {
    if (!mounted) return;

    try {
      final uri = Uri.base;
      final mat = uri.queryParameters['material'] ?? uri.queryParameters['mat'];
      if (mat != null && mat.isNotEmpty) {
        DataEntryScreen.pendingMaterialCode = mat;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainLayoutScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
        return;
      }
    } catch (_) {}

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // â”€â”€ Animated Gold Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.primaryLight, context.colors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color:      context.colors.primary.withAlpha(115),
                        blurRadius: 36,
                        offset:     const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.diamond_rounded,
                    size:  50,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                  ),
                ),
                const SizedBox(height: 28),

                // â”€â”€ Brand Name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Text(
                  'Vitaly App',
                  style: GoogleFonts.inter(
                    fontSize:     36,
                    fontWeight:   FontWeight.w700,
                    color:        context.colors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LUXURY STONE & WOOD',
                  style: GoogleFonts.inter(
                    fontSize:     12,
                    fontWeight:   FontWeight.w600,
                    color:        context.colors.primary,
                    letterSpacing: 3.5,
                  ),
                ),
                const SizedBox(height: 56),

                // â”€â”€ Progress Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: context.colors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 3,
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 14),
                      Text(
                        'Initializing Vitaly ERP...',
                        style: GoogleFonts.inter(fontSize: 10, color: context.colors.textDisabled),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
