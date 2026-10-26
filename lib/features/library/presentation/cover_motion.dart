import 'package:flutter/material.dart';

class CoverMotion extends StatefulWidget {
  const CoverMotion({super.key, required this.child});
  final Widget child;
  @override
  State<CoverMotion> createState() => _CoverMotionState();
}

class _CoverMotionState extends State<CoverMotion> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedScale(
      scale: hover ? 1.025 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hover ? .5 : .15),
              blurRadius: hover ? 24 : 8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: widget.child,
      ),
    ),
  );
}
