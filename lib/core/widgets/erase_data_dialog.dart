import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../state/app_state_scope.dart';
import '../services/auth_service.dart';

/// Controller for detecting 5 taps within a short window on the Vitaly logo
class VitalyTapDetector {
  static int _tapCount = 0;
  static DateTime _lastTapTime = DateTime(0);

  /// Call this on every tap on the Vitaly icon
  static void onTap(BuildContext context) {
    // Only SuperAdmin has permission for hidden database erase action
    if (!AuthService.instance.isSuperAdmin) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastTapTime) < const Duration(milliseconds: 2200)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    if (_tapCount >= 3 && _tapCount < 5) {
      final remaining = 5 - _tapCount;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tap $remaining more time${remaining > 1 ? 's' : ''} for reset menu'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (_tapCount >= 5) {
      _tapCount = 0;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showEraseDataConfirmationDialog(context);
    }
  }
}


/// Confirmation dialog triggered by 5 taps on the Vitaly logo (SuperAdmin Only)
Future<void> showEraseDataConfirmationDialog(BuildContext context) async {
  // Guard check: strictly SuperAdmin only!
  if (!AuthService.instance.isSuperAdmin) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access Denied: Only Super Admin has permission to erase data.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  final colors = context.colors;
  final appState = AppStateScope.read(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isErasing = false;
      bool isSuccess = false;
      String statusMessage = '';

      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: colors.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.redAccent.withAlpha(90), width: 1.5),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header Icon & Title ─────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? Colors.green.withAlpha(30)
                                  : Colors.redAccent.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSuccess
                                    ? Colors.green.withAlpha(80)
                                    : Colors.redAccent.withAlpha(80),
                              ),
                            ),
                            child: Icon(
                              isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              color: isSuccess ? Colors.greenAccent[700] : Colors.redAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSuccess ? 'Data Erased' : 'Erase All Data?',
                                  style: GoogleFonts.inter(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSuccess
                                      ? 'Database & App Reset Complete'
                                      : 'Vitaly Hidden Admin Action',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSuccess ? Colors.green[600] : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (isSuccess) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withAlpha(50)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.task_alt_rounded, color: Colors.green, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  statusMessage.isNotEmpty
                                      ? statusMessage
                                      : 'All materials, slabs, sales, and customers were successfully wiped from InsForge and app view.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else ...[
                        // ── Description ─────────────────────────────────────────
                        Text(
                          'You triggered the 5-tap hidden action. Do you want to permanently erase all entered data from the application and the InsForge database?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── List of wiped data ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant.withAlpha(120),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            children: [
                              _bulletItem(colors, 'All Stone Inventory & Slabs'),
                              const SizedBox(height: 6),
                              _bulletItem(colors, 'All Entered Materials'),
                              const SizedBox(height: 6),
                              _bulletItem(colors, 'All Customers & Phone Records'),
                              const SizedBox(height: 6),
                              _bulletItem(colors, 'All Sales & Invoices'),
                              const SizedBox(height: 6),
                              _bulletItem(colors, 'All Reservations & Deposits'),
                              const SizedBox(height: 6),
                              _bulletItem(colors, 'All Data Check Physical Audits'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '⚠️ This action cannot be reversed.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Action Buttons ──────────────────────────────────────
                        if (isErasing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Wiping database & local data...',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.textPrimary,
                                    side: BorderSide(color: colors.border),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (!AuthService.instance.isSuperAdmin) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Access Denied: Only Super Admin can erase database.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      isErasing = true;
                                    });

                                    final ok = await appState.eraseAllData();

                                    setState(() {
                                      isErasing = false;
                                      isSuccess = true;
                                      statusMessage = ok
                                          ? 'All entered data was successfully erased from InsForge & frontend.'
                                          : 'Local data was erased. (Verify backend connection).';
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.delete_forever_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Erase Everything',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _bulletItem(AppColorsExtension colors, String text) {
  return Row(
    children: [
      const Icon(Icons.circle, size: 6, color: Colors.redAccent),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
      ),
    ],
  );
}
