import 'package:flutter/material.dart';

/// Wraps the app to obscure sensitive content when it goes to the
/// background (app switcher, incoming call). Combined with Android
/// FLAG_SECURE in MainActivity, this hides health info from screenshots
/// and screen recordings.
///
/// TODO(security): re-enable the blur overlay before production release.
/// Disabled during testing alongside FLAG_SECURE so screenshots work.
/// To restore: bring back the WidgetsBindingObserver + Stack overlay
/// from git history.
class SecureAppShell extends StatelessWidget {
  const SecureAppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}