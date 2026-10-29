import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  IconData get _icon {
    switch (icon) {
      case 'explore':
        return Icons.explore_outlined;
      case 'saved':
        return Icons.bookmark_border_rounded;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(_icon, size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                'We’ll build this feature in a later stage.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
