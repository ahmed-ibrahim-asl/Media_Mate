// lib/widgets/async/loading_scaffold.dart
import 'package:flutter/material.dart';

/// Simple scaffold with a centered progress indicator.
/// Optionally show a message under the spinner.
class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key, this.message, this.backgroundColor});

  /// Optional text shown under the spinner.
  final String? message;

  /// Optional background color. Defaults to theme scaffold color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
