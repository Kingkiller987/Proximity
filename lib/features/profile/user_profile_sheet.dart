import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';

/// Displays a bottom modal sheet with public identity projection details
/// and user interaction actions (Send DM, Block, Report).
void showUserProfileSheet(
  BuildContext context, {
  required PublicIdentityProjection projection,
  required String distanceLabel,
  VoidCallback? onSendDm,
  VoidCallback? onBlock,
  VoidCallback? onReport,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.pulseMint.withAlpha(40),
                backgroundImage: projection.avatarBytes != null
                    ? MemoryImage(projection.avatarBytes!)
                    : null,
                child: projection.avatarBytes == null
                    ? const Icon(
                        Icons.person,
                        size: 36,
                        color: AppTheme.pulseMint,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                projection.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppTheme.ghostViolet,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distanceLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.ghostViolet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                projection.bio.isNotEmpty ? projection.bio : 'No bio provided.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSendDm?.call();
                    },
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Send DM'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onBlock?.call();
                    },
                    icon: const Icon(
                      Icons.block,
                      size: 18,
                      color: Colors.orangeAccent,
                    ),
                    label: const Text(
                      'Block',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onReport?.call();
                    },
                    icon: const Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Report',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
