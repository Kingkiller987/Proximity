import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../profile/report_user_dialog.dart';
import '../profile/user_profile_sheet.dart';

class NearbyMembersSidebar extends StatelessWidget {
  const NearbyMembersSidebar({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final participants = controller.visibleNearbyParticipants;
    final c = controller;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.people_outline, color: AppTheme.pulseMint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nearby Members (${participants.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (participants.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No visible nearby participants.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: participants.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final projection = c.publicProjectionForUser(p.userId);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.pulseMint.withAlpha(35),
                        backgroundImage: projection.avatarBytes != null
                            ? MemoryImage(projection.avatarBytes!)
                            : null,
                        child: projection.avatarBytes == null
                            ? const Icon(
                                Icons.person,
                                size: 20,
                                color: AppTheme.pulseMint,
                              )
                            : null,
                      ),
                      title: Text(
                        projection.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${projection.bio} • ${p.distanceLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        showUserProfileSheet(
                          context,
                          projection: projection,
                          distanceLabel: p.distanceLabel,
                          onSendDm: () {
                            c.sendDmRequest(
                              toUserId: p.userId,
                              toDisplayName: projection.displayName,
                              introMessage: 'Hello!',
                            );
                          },
                          onBlock: () => c.blockUser(
                            p.userId,
                            label: projection.displayName,
                          ),
                          onReport: () => ReportUserDialog.show(
                            context,
                            controller: c,
                            targetId: p.userId,
                            targetLabel: projection.displayName,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
