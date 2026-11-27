import '../../core/api/api_client.dart';
import '../../core/api/parsing.dart';
import 'update_info.dart';

/// docs/app-versions.md in the backend. The public routes need no token and no tenant.
class AppVersionRepository {
  AppVersionRepository(this._api);

  final ApiClient _api;

  Future<UpdateInfo> check({required String platform, required String version}) async {
    final body = await _api.get(
      '/public/app-versions/check',
      authenticated: false,
      query: <String, dynamic>{'platform': platform, 'version': version},
    );
    return parseBody<UpdateInfo>(() => UpdateInfo.fromJson(asMap(envelopeData(body))));
  }
}
