import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_mate/theme/colors.dart';

// custom widget that displays (label, value, optional: edit icon)
class Field extends StatelessWidget {
  const Field({
    required this.label,
    required this.value,
    this.onTap,
    this.editable = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF7A7B82);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value.isEmpty ? '—' : value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A7B82),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (editable) const SizedBox(width: 6),
                  if (editable)
                    const Icon(Icons.edit, size: 16, color: Color(0xFF7A7B82)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
