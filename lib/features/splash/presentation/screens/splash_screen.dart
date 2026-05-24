import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Brief bilingual welcome shown on every cold launch.
///
/// Animates in, holds for ~1.5s, then redirects based on onboarding state.
/// Crash-safe: any failure reading profile state falls back to onboarding,
/// matching the router's defensive redirect logic.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    // Hold the welcome for ~1.5s total, then route based on onboarding state.
    Future.delayed(const Duration(milliseconds: 1500), _route);
  }

  void _route() {
    if (!mounted) return;
    try {
      final profileService = ref.read(profileServiceProvider);
      if (!profileService.isOnboardingDone) {
        context.go('/onboarding');
        return;
      }
      final profile = profileService.load();
      if (profile.nationality == null) {
        // Corrupt-state recovery, same as router fallback.
        profileService.resetOnboarding();
        context.go('/onboarding');
        return;
      }
      context.go('/main/radar');
    } catch (_) {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withAlpha(24),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandTeal.withAlpha(70),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: AppColors.brandTeal,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to VisaRadar',
                    style: AppTextStyles.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "VisaRadar'a Hoşgeldiniz",
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
