import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF223026) : AdminTheme.kSoftGreen;
    final borderCol = isDark ? const Color(0xFF2E3D34) : AdminTheme.kLightGreen;
    final iconBg = isDark ? const Color(0xFF2B3E31) : AdminTheme.kLightGreen;
    final primaryCol = isDark ? const Color(0xFF81C784) : AdminTheme.kPrimary;
    final valueColor = isDark ? AdminTheme.kWhite : AdminTheme.kTextPrimary;
    final subColor = isDark ? Colors.white70 : AdminTheme.kTextSecondary;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryCol, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: valueColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: subColor),
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

class AdminMainMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimaryVariant;
  final VoidCallback onTap;

  const AdminMainMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimaryVariant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1E2822)
        : (isPrimaryVariant ? AdminTheme.kLightGreen : AdminTheme.kSoftGreen);
    final titleCol = isDark ? AdminTheme.kWhite : AdminTheme.kTextPrimary;
    final subCol = isDark ? Colors.white70 : AdminTheme.kTextSecondary;
    final accentCol = isPrimaryVariant
        ? AdminTheme.kSecondary.withValues(alpha: 0.15)
        : AdminTheme.kPrimary.withValues(alpha: 0.10);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 98,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E3D34)
                  : (isPrimaryVariant
                        ? AdminTheme.kSecondary.withValues(alpha: 0.25)
                        : AdminTheme.kPrimary.withValues(alpha: 0.15)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: isPrimaryVariant ? -20 : null,
                  top: isPrimaryVariant ? null : -20,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: accentCol,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isPrimaryVariant
                              ? AdminTheme.kPrimary
                              : AdminTheme.kSecondary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: AdminTheme.kWhite, size: 23),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: titleCol,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                color: subCol,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : AdminTheme.kPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminArchiveActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final bool isPrimary;
  final VoidCallback onTap;

  const AdminArchiveActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A241E) : AdminTheme.kWhite;
    final titleColor = isDark ? AdminTheme.kWhite : AdminTheme.kTextPrimary;
    final subColor = isDark ? Colors.white70 : AdminTheme.kTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimary
              ? AdminTheme.kPrimary.withValues(alpha: 0.25)
              : AdminTheme.kSecondary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.kPrimary.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF24382B)
                  : (isPrimary
                        ? AdminTheme.kLightGreen
                        : AdminTheme.kSoftGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark
                  ? const Color(0xFF81C784)
                  : (isPrimary ? AdminTheme.kPrimary : AdminTheme.kSecondary),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, height: 1.35, color: subColor),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? AdminTheme.kPrimary
                    : AdminTheme.kLightGreen,
                foregroundColor: isPrimary
                    ? AdminTheme.kWhite
                    : AdminTheme.kPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      buttonText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderPillBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const HeaderPillBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class UserMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;
  final Color iconColor;

  const UserMetaItem({
    super.key,
    required this.icon,
    required this.text,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: textColor)),
        ),
      ],
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  final String status;

  const AdminStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'Selesai' || 'Aktif' => (AdminTheme.kLightGreen, AdminTheme.kPrimary),
      'Diproses' ||
      'Terjadwal' => (const Color(0xFFFFF4E5), const Color(0xFFB26A00)),
      _ => (const Color(0xFFECEFF1), const Color(0xFF546E7A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class AdminForestHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backHillPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final backHillPath = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.35,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(backHillPath, backHillPaint);

    final midHillPaint = Paint()
      ..color = const Color(0xFF387A4D).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final midHillPath = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.48,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(midHillPath, midHillPaint);

    final frontHillPaint = Paint()
      ..color = const Color(0xFF1B4B2A).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final frontHillPath = Path()
      ..moveTo(size.width * 0.55, size.height)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.68,
        size.width,
        size.height * 0.82,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(frontHillPath, frontHillPaint);

    _drawPineTree(
      canvas,
      Offset(size.width * 0.58, size.height * 0.82),
      26,
      const Color(0xFF1B4B2A),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.65, size.height * 0.75),
      36,
      const Color(0xFF163D22),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.72, size.height * 0.78),
      30,
      const Color(0xFF245C3A),
    );
    _drawPineTree(
      canvas,
      Offset(size.width * 0.88, size.height * 0.72),
      38,
      const Color(0xFF163D22),
    );
  }

  void _drawPineTree(
    Canvas canvas,
    Offset baseCenter,
    double height,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = height * 0.55;
    final path = Path()
      ..moveTo(baseCenter.dx, baseCenter.dy - height)
      ..lineTo(baseCenter.dx - width / 2, baseCenter.dy)
      ..lineTo(baseCenter.dx + width / 2, baseCenter.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
