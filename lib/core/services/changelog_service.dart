import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/changelog_release.dart';

final changelogServiceProvider = Provider<ChangelogService>((ref) {
  return ChangelogService();
});

final changelogDataProvider = FutureProvider<ChangelogData>((ref) async {
  final service = ref.watch(changelogServiceProvider);
  return service.loadChangelog();
});

class ChangelogService {
  Future<ChangelogData> loadChangelog() async {
    try {
      // Load as bytes and explicitly decode as UTF-8
      final byteData = await rootBundle.load('assets/changelog.json');
      final jsonString = utf8.decode(byteData.buffer.asUint8List());
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return ChangelogData.fromJson(jsonData);
    } catch (e) {
      // Return empty changelog if file doesn't exist or is invalid
      return const ChangelogData(releases: []);
    }
  }

  ChangelogRelease? getLatestRelease(ChangelogData data) {
    if (data.releases.isEmpty) return null;
    return data.releases.first;
  }

  ChangelogRelease? getReleaseByVersion(ChangelogData data, String version) {
    try {
      return data.releases.firstWhere((r) => r.version == version);
    } catch (e) {
      return null;
    }
  }
}
