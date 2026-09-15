import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'models.dart';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.status,
    this.fields = const {},
    this.uncertain = false,
  });
  final String message;
  final int? status;
  final Map<String, String> fields;
  final bool uncertain;
  factory ApiFailure.fromDio(DioException e) {
    final j = object(e.response?.data);
    final status = e.response?.statusCode;
    final fields = object(j['errors'])
        .map((k, v) => MapEntry(k, v is List ? v.join('\n') : string(v)));
    return ApiFailure(
      status == 403
          ? 'Bu işlem için yetkin bulunmuyor.'
          : string(j['message']).isNotEmpty
              ? string(j['message'])
              : 'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.',
      status: status,
      fields: fields,
      uncertain: e.response == null && e.type != DioExceptionType.cancel,
    );
  }
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Accept': 'application/json'},
              ),
            );
  final Dio dio;
  String? token;
  void Function()? onUnauthorized;
  Future<Json> request(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? query,
  }) async {
    final requestToken = token;
    try {
      final result = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (requestToken != null) 'Authorization': 'Bearer $requestToken',
          },
        ),
      );
      return object(result.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          token == requestToken &&
          requestToken != null) {
        onUnauthorized?.call();
      }
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Json> get(String path, {Map<String, dynamic>? query}) =>
      request(path, query: query);
  Future<Json> post(String path, dynamic data) =>
      request(path, method: 'POST', data: data);
  Future<Json> put(String path, dynamic data) =>
      request(path, method: 'PUT', data: data);
  Future<Json> delete(String path) => request(path, method: 'DELETE');
}

final apiProvider = Provider<ApiClient>((ref) => ApiClient());

// One revision invalidates active REST providers after authoritative mutations,
// websocket signals and resume. Requests carry a session revision as well.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);

final jsonProvider = FutureProvider.autoDispose.family<Json, String>((
  ref,
  path,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(apiProvider).get(path);
});

final eventProvider = FutureProvider.autoDispose.family<Event, String>(
  (ref, slug) async => Event.fromJson(
    object(
      (await ref.watch(
        jsonProvider('/events/${Uri.encodeComponent(slug)}').future,
      ))['data'],
    ),
  ),
);
final orderProvider = FutureProvider.autoDispose.family<Order, int>(
  (ref, id) async => Order.fromJson(
    object((await ref.watch(jsonProvider('/orders/$id').future))['data']),
  ),
);
final ticketProvider = FutureProvider.autoDispose.family<Ticket, String>(
  (ref, code) async => Ticket.fromJson(
    object(
      (await ref.watch(
        jsonProvider('/tickets/${Uri.encodeComponent(code)}').future,
      ))['data'],
    ),
  ),
);
