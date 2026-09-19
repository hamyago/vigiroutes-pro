import '../models/ct_mission_model.dart';
import 'api_service.dart';

class CtMissionService {
  static final CtMissionService instance = CtMissionService._();
  CtMissionService._();

  Future<List<CtMissionModel>> getMissions() async {
    final response = await ApiService.instance.get('/provider/ct/missions');
    final data = response.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
    } else {
      list = [];
    }
    return list
        .map((e) => CtMissionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CtMissionModel> getMission(String id) async {
    final response = await ApiService.instance.get('/provider/ct/missions/$id');
    final data = response.data;
    final missionData = data is Map && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return CtMissionModel.fromJson(missionData);
  }

  Future<CtMissionModel> updateStatus(String id, String status) async {
    final response = await ApiService.instance.post(
      '/provider/ct/missions/$id/status',
      data: {'status': status},
    );
    final data = response.data;
    final missionData = data is Map && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return CtMissionModel.fromJson(missionData);
  }

  Future<void> submitReport(String id, Map<String, dynamic> reportData) async {
    await ApiService.instance.post(
      '/provider/ct/missions/$id/report',
      data: reportData,
    );
  }
}
