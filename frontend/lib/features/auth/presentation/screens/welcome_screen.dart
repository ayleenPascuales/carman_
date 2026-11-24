import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/carman_button.dart';
import '../../../../shared/widgets/carman_image.dart';
import '../../../../shared/widgets/carman_logo.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_badge.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Center(
                child: MaxWidthContent(
                  maxWidth: 1180,
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    children: [
                      Expanded(child: _Intro(centered: false, large: true)),
                      const SizedBox(width: 48),
                      const Expanded(child: _HeroCar()),
                    ],
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: MaxWidthContent(
                maxWidth: 520,
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CarmanLogo(size: 34),
                      const SizedBox(height: 30),
                      _Intro(centered: false),
                      const SizedBox(height: 24),
                      const _HeroCar(),
                      const SizedBox(height: 24),
                      _Actions(expanded: true),
                      const SizedBox(height: 24),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({this.centered = false, this.large = false});

  final bool centered;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (large) const CarmanLogo(size: 40),
        if (large) const SizedBox(height: 38),
        Text(
          'Tu próximo coche,\na un toque.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: AppTheme.display.copyWith(
            fontSize: large ? 46 : 34,
            height: 1.08,
            letterSpacing: large ? -1.8 : -1.2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Reserva, abre y conduce. Sin llaves, sin filas.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: AppTheme.bodyMd.copyWith(
            color: AppColors.secondaryText,
            fontSize: large ? 15 : 13.5,
          ),
        ),
        if (large) ...[
          const SizedBox(height: 30),
          _Actions(expanded: false),
          const SizedBox(height: 18),
          const _Footer(),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: expanded
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: expanded ? null : 230,
          child: CarmanButton(
            label: 'Empezar',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => context.push('/register'),
          ),
        ),
        if (expanded) const SizedBox(height: 4),
        TextButton(
          onPressed: () => context.push('/login'),
          child: const Text('Ya tengo cuenta'),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 12,
          color: AppColors.tertiaryText,
        ),
        const SizedBox(width: 5),
        Text(
          'Coches verificados · Pago protegido',
          style: AppTheme.bodySm.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

class _HeroCar extends StatelessWidget {
  const _HeroCar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/login'),
      child: AspectRatio(
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CarmanImage(
                'assets/images/cars/hero_porsche.jpg',
                fit: BoxFit.cover,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xC4000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              const Positioned(
                right: 14,
                top: 14,
                child: RatingBadge(rating: 4.98, dark: true),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Porsche 911',
                            style: AppTheme.headlineSm.copyWith(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Desde \$189 / día',
                            style: AppTheme.bodySm.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
