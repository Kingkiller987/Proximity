import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive helper for date and time pickers.
/// Uses native Cupertino modal pickers on iOS and macOS, and Material pickers on Android.
class PlatformDateTimePicker {
  const PlatformDateTimePicker._();

  static bool isApplePlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  /// Displays an iOS Cupertino modal date picker on Apple platforms,
  /// or a Material date picker on Android and other platforms.
  static Future<DateTime?> showPlatformDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    if (isApplePlatform(context)) {
      DateTime tempSelected = initialDate;
      return showCupertinoModalPopup<DateTime>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 300,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: <Widget>[
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(tempSelected),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initialDate.isBefore(firstDate)
                          ? firstDate
                          : (initialDate.isAfter(lastDate)
                                ? lastDate
                                : initialDate),
                      minimumDate: firstDate,
                      maximumDate: lastDate,
                      onDateTimeChanged: (d) => tempSelected = d,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  /// Displays an iOS Cupertino modal time picker on Apple platforms,
  /// or a Material time picker on Android and other platforms.
  static Future<TimeOfDay?> showPlatformTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) async {
    if (isApplePlatform(context)) {
      TimeOfDay tempSelected = initialTime;
      final now = DateTime.now();
      final initialDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        initialTime.hour,
        initialTime.minute,
      );

      return showCupertinoModalPopup<TimeOfDay>(
        context: context,
        builder: (ctx) {
          return Container(
            height: 300,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: <Widget>[
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(ctx).pop(tempSelected),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialDateTime,
                      onDateTimeChanged: (d) => tempSelected = TimeOfDay(
                        hour: d.hour,
                        minute: d.minute,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return showTimePicker(context: context, initialTime: initialTime);
  }
}
