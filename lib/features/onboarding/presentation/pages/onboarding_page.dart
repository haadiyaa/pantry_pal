import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../notifications/domain/services/notification_scheduler.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

/// Landing onboarding carousel shown on first app launch.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(
        onboardingRepository: context.read<OnboardingRepository>(),
        notificationScheduler: context.read<NotificationScheduler>(),
      ),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish(BuildContext context) {
    context.read<OnboardingCubit>().complete().then((_) {
      if (context.mounted) {
        try {
          context.go('/');
        } catch (_) {
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('onboarding_skip_button'),
            onPressed: () => _finish(context),
            child: const Text('Skip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  context.read<OnboardingCubit>().pageChanged(index);
                },
                children: [
                  _OnboardingSlide(
                    icon: Icons.kitchen_outlined,
                    iconColor: Colors.green.shade600,
                    title: 'Smart Pantry Tracking',
                    description:
                        'Keep track of shelf life, categories, and quantities effortlessly. Reduce food waste and save money with timely expiry tracking.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.document_scanner_outlined,
                    iconColor: Colors.teal.shade600,
                    title: 'Barcode & Receipt OCR',
                    description:
                        'Add items in seconds. Scan barcodes with Open Food Facts integration or photograph grocery receipts to auto-extract items locally on device.',
                  ),
                  _OnboardingSlide(
                    icon: Icons.restaurant_menu_outlined,
                    iconColor: Colors.orange.shade700,
                    title: 'Zero-Waste Recipes',
                    description:
                        'Get delicious recipe suggestions ranked by ingredients expiring soon in your kitchen. Maximize what you have before shopping.',
                  ),
                  const _NotificationSlide(),
                ],
              ),
            ),

            // Bottom Navigation & Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: BlocBuilder<OnboardingCubit, OnboardingState>(
                builder: (context, state) {
                  final isLastPage = state.pageIndex == OnboardingCubit.totalPages - 1;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots Indicator
                      Row(
                        children: List.generate(
                          OnboardingCubit.totalPages,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: state.pageIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: state.pageIndex == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next or Get Started Button
                      FilledButton(
                        key: const Key('onboarding_next_button'),
                        onPressed: () {
                          if (isLastPage) {
                            _finish(context);
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Text(isLastPage ? 'Get Started' : 'Next'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 36),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSlide extends StatelessWidget {
  const _NotificationSlide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.blue.shade600.withValues(alpha: 0.12),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 56,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Timely Expiry Alerts',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We can gently remind you when pantry items are about to expire. All notification scheduling runs completely on-device without remote servers.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          BlocBuilder<OnboardingCubit, OnboardingState>(
            builder: (context, state) {
              if (state.permissionGranted) {
                return OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: const Text('Notifications Enabled'),
                );
              }

              return OutlinedButton.icon(
                key: const Key('enable_notifications_button'),
                onPressed: () {
                  context
                      .read<OnboardingCubit>()
                      .requestNotificationPermission();
                },
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Enable Expiry Reminders'),
              );
            },
          ),
        ],
      ),
    );
  }
}
