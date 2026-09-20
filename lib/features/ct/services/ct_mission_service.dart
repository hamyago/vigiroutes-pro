import '../../../core/services/api_service.dart';
import '../../../core/models/ct_mission_model.dart';

class CtMissionService {
  static final CtMissionService instance = CtMissionService._();
  CtMissionService._();

  Future<List<CtMissionModel>> getMissions() async {
    final res = await ApiService.instance.get('/v1/ct/missions');
    final data = res.data;
    final List list = (data is Map ? data['data'] : data) as List? ?? [];
    return list.map((e) => CtMissionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<bool> updateStatus(String id, String status) async {
    await ApiService.instance.patch('/v1/ct/missions/$id/status', data: {'status': status});
    return true;
  }

  Future<CtMissionReportModel> submitReport({
    required String id,
    required String result,
    required String pvNumber,
    String? observations,
    String? nextVisitDate,
  }) async {
    final res = await ApiService.instance.post(
      '/v1/ct/missions/$id/report',
      data: {
        'result': result,
        'pv_number': pvNumber,
        if (observations != null && observations.isNotEmpty) 'observations': observations,
        if (nextVisitDate != null) 'next_visit_date': nextVisitDate,
      },
    );
    final d = res.data;
    final map = (d is Map && d['data'] != null) ? d['data'] : d;
    return CtMissionReportModel.fromJson(map as Map<String, dynamic>);
  }
}
