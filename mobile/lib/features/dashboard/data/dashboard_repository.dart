import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../domain/dashboard.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => ApiDashboardRepository(ref.watch(dioProvider)),
);

final dashboardProvider = FutureProvider<DashboardSummary>(
  (ref) => ref.watch(dashboardRepositoryProvider).summary(),
);

abstract class DashboardRepository {
  Future<DashboardSummary> summary();
}

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository(this._dio);

  final Dio _dio;

  @override
  Future<DashboardSummary> summary() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/dashboard',
        // Day buckets follow the phone's time zone.
        queryParameters: {'tzOffset': DateTime.now().timeZoneOffset.inMinutes},
      );
      return DashboardSummary.fromJson(res.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
