import 'package:flutter/material.dart';

class AnimatedMenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const AnimatedMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  State<AnimatedMenuCard> createState() =>
      _AnimatedMenuCardState();
}

class _AnimatedMenuCardState extends State<AnimatedMenuCard> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E2822) : widget.background;
    final cardBorder = isDark ? const Color(0xFF2E3D34) : Colors.transparent;
    final titleColor = isDark ? Colors.white : const Color(0xFF202520);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF617064);
    final arrowColor = isDark ? const Color(0xFF81C784) : widget.color;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressing = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          pressing = false;
        });
      },
      onTapCancel: () {
        setState(() {
          pressing = false;
        });
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: pressing ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),

              // ICON
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(height: 12),

              // JUDUL
              Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),

              const SizedBox(height: 5),

              // SUBTITLE
              Expanded(
                child: Center(
                  child: Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ),

              // PANAH
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: arrowColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}