import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/constants/app_version.dart';

void main() {
  test('kAppVersion matches pubspec version', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final pubspecVersion = line.split(':')[1].split('+').first.trim();

    expect(
      kAppVersion,
      pubspecVersion,
      reason: 'lib/constants/app_version.dart is stale — the Manage screen '
          'would show $kAppVersion while the build is $pubspecVersion',
    );
  });
}
