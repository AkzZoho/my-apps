// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../theme.dart';

class IosInstallBanner extends StatefulWidget {
  const IosInstallBanner({super.key});

  @override
  State<IosInstallBanner> createState() => _IosInstallBannerState();
}

class _IosInstallBannerState extends State<IosInstallBanner> {
  bool _dismissed = false;

  bool get _shouldShow {
    if (_dismissed) return false;
    try {
      final ua = html.window.navigator.userAgent.toLowerCase();
      final isIos = ua.contains('iphone') ||
          ua.contains('ipad') ||
          ua.contains('ipod');
      if (!isIos) return false;
      if (html.window.matchMedia('(display-mode: standalone)').matches) {
        return false;
      }
      try {
        // ignore: avoid_dynamic_calls
        if ((html.window.navigator as dynamic).standalone == true) return false;
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    final c = context.colors;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.primary.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.phone_iphone_rounded,
                        color: c.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Home Screen',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Install this app on your iPhone for quick access',
                          style:
                              TextStyle(color: c.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: c.textMuted),
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  _Step(
                    number: '1',
                    icon: Icons.ios_share_rounded,
                    text: 'Tap the Share button in Safari\'s toolbar',
                    c: c,
                  ),
                  const SizedBox(height: 8),
                  _Step(
                    number: '2',
                    icon: Icons.add_box_outlined,
                    text: 'Scroll down and tap "Add to Home Screen"',
                    c: c,
                  ),
                  const SizedBox(height: 8),
                  _Step(
                    number: '3',
                    icon: Icons.check_circle_outline_rounded,
                    text: 'Tap "Add" to confirm',
                    c: c,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;
  final AppColors c;

  const _Step({
    required this.number,
    required this.icon,
    required this.text,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: c.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: c.primaryFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: c.text, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
