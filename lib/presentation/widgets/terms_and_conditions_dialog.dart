import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';
import 'bouncing_scale_button.dart';

/// Unskippable First-Run Terms & Conditions Modal Dialog.
/// Enforces user agreement before allowing access to the application.
class TermsAndConditionsDialog extends StatefulWidget {
  final VoidCallback onAccepted;

  const TermsAndConditionsDialog({
    super.key,
    required this.onAccepted,
  });

  static Future<void> showIfNeeded({
    required BuildContext context,
    required Future<bool> Function() isTermsAccepted,
    required Future<void> Function() onTermsAccepted,
  }) async {
    final accepted = await isTermsAccepted();
    if (!accepted && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: TermsAndConditionsDialog(
            onAccepted: () async {
              await onTermsAccepted();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  State<TermsAndConditionsDialog> createState() => _TermsAndConditionsDialogState();
}

class _TermsAndConditionsDialogState extends State<TermsAndConditionsDialog> {
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(tokens.radiusXl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon & Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: tokens.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Softify',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Terms & Educational Usage Agreement',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Terms Content in Scrollable View
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceElevated.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            title: '1. Personal & Educational Purpose',
                            body:
                                'Softify is developed strictly as an open-source, non-commercial media aggregation client for personal education and research. It is completely free, ad-free, and account-free.',
                          ),
                          _buildSection(
                            title: '2. No Copyrighted Media Stored',
                            body:
                                'Softify does not host, store, cache on remote servers, or distribute copyrighted media files. All playback streams and lyrics are resolved client-side directly from third-party public network endpoints.',
                          ),
                          _buildSection(
                            title: '3. Compliance & User Responsibility',
                            body:
                                'By using this application, you agree to comply with your local jurisdiction’s copyright and telecommunications laws. You acknowledge that Softify is not affiliated with, endorsed by, or connected to Spotify, YouTube, or JioSaavn.',
                          ),
                          _buildSection(
                            title: '4. Privacy & Offline Local-First Design',
                            body:
                                'Softify enforces zero telemetry. Your listening history, playlists, cached lyrics, and taste profiles remain 100% offline in your local device SQLite storage.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Agreement Checkbox
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _agreedToTerms = !_agreedToTerms;
                    });
                  },
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: tokens.accent,
                          checkColor: Colors.black,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _agreedToTerms = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'I have read and unconditionally agree to these Terms of Use & Disclaimers.',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Agree & Continue Action Button
                BouncingScaleButton(
                  scaleFactor: 0.95,
                  onTap: _agreedToTerms
                      ? () {
                          HapticFeedback.mediumImpact();
                          widget.onAccepted();
                        }
                      : () {
                          HapticFeedback.vibrate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please check the box to agree to the terms.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _agreedToTerms
                          ? tokens.accent
                          : tokens.surfaceHighlight,
                      borderRadius: BorderRadius.circular(tokens.radiusFull),
                      boxShadow: _agreedToTerms
                          ? [
                              BoxShadow(
                                color: tokens.accent.withValues(alpha: 0.40),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Agree & Continue',
                        style: TextStyle(
                          color: _agreedToTerms ? Colors.black : tokens.textMuted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}
