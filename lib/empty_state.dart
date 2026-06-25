import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const VEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 48, color: secondary),
          const SizedBox(height: 16),
          Text(title, style: VTextStyles.bodyBold, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: VTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accentYellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, size: 14, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      actionLabel!,
                      style: VTextStyles.bodyBold.copyWith(color: primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
