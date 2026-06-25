import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

class VSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const VSettingsRow({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: cardBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text(subtitle, style: VTextStyles.caption),
                ],
              ),
            ),

            if (trailing != null)
              trailing!
            else
              const Icon(Icons.chevron_right, size: 12, color: secondary),
          ],
        ),
      ),
    );
  }
}
