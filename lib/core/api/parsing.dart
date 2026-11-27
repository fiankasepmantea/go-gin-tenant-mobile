import 'api_exception.dart';

/// Runs [parse] and turns a body that does not look as expected into an [ApiException], so screens never see a
/// raw `TypeError`.
T parseBody<T>(T Function() parse) {
  try {
    return parse();
  } on ApiException {
    rethrow;
  } on TypeError {
    throw const ApiException.unexpected();
  } on FormatException {
    throw const ApiException.unexpected();
  }
}

/// `body['data']` of a success envelope `{"success": true, "code": 200, "data": ...}`.
Object? envelopeData(Object? body) {
  if (body is Map<String, dynamic>) return body['data'];
  throw const ApiException.unexpected();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const ApiException.unexpected();
}

List<dynamic> asList(Object? value) {
  if (value is List<dynamic>) return value;
  throw const ApiException.unexpected();
}

/// A paginated list: `{"total_data", "total_pages", "curr_page", "next_page"?, "data_per_page", "data": [...]}`.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.totalData,
    required this.currentPage,
    required this.totalPages,
  });

  final List<T> items;
  final int totalData;
  final int currentPage;
  final int totalPages;

  bool get hasMore => currentPage < totalPages;

  factory PagedResult.fromEnvelope(Object? body, T Function(Map<String, dynamic>) parseItem) {
    return parseBody<PagedResult<T>>(() {
      final page = asMap(envelopeData(body));
      return PagedResult<T>(
        items: <T>[for (final item in asList(page['data'])) parseItem(asMap(item))],
        totalData: (page['total_data'] as num?)?.toInt() ?? 0,
        currentPage: (page['curr_page'] as num?)?.toInt() ?? 1,
        totalPages: (page['total_pages'] as num?)?.toInt() ?? 1,
      );
    });
  }
}
