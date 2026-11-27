/// The answer of GET /public/app-versions/check.
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.storeUrl,
    required this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?) ?? '';
    return UpdateInfo(
      currentVersion: text('current_version'),
      latestVersion: text('latest_version'),
      updateAvailable: (json['update_available'] as bool?) ?? false,
      forceUpdate: (json['force_update'] as bool?) ?? false,
      releaseNotes: text('release_notes'),
      storeUrl: text('store_url'),
      downloadUrl: text('download_url'),
    );
  }

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final bool forceUpdate;
  final String releaseNotes;
  final String storeUrl;

  /// A path or URL of the package; empty when the release has no package.
  final String downloadUrl;
}
