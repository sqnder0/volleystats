import 'package:flutter/material.dart';
import 'colors.dart';

class VToggleSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool>? onChanged;

  const VToggleSwitch({super.key, this.isOn = true, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!isOn),
      child: Container(
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: isOn ? accentYellow : secondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: light,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
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
