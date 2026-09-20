import 'package:flutter/foundation.dart';
import '../../../core/models/ct_mission_model.dart';
import '../services/ct_mission_service.dart';

class CtController extends ChangeNotifier {
  List<CtMissionModel> _missions = [];
  bool _isLoading = false;
  String? _error;

  List<CtMissionModel> get missions => _missions;
  List<CtMissionModel> get pendingMissions =>
      _missions.where((m) => !m.isCompleted && !m.isCancelled).toList();
  List<CtMissionModel> get completedMissions =>
      _missions.where((m) => m.isCompleted || m.isCancelled).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadMissions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _missions = await CtMissionService.instance.getMissions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(String missionId, String status) async {
    try {
      await CtMissionService.instance.updateStatus(missionId, status);
      final idx = _missions.indexWhere((m) => m.id == missionId);
      if (idx != -1) {
        _missions[idx] = _missions[idx].copyWith(providerStatus: status);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitReport(
    String missionId,
    String result,
    String pvNumber,
    String observations,
    DateTime? nextVisitDate,
  ) async {
    try {
      final report = await CtMissionService.instance.submitReport(
        id: missionId,
        result: result,
        pvNumber: pvNumber,
        observations: observations.isNotEmpty ? observations : null,
        nextVisitDate: nextVisitDate != null
            ? '${nextVisitDate.year}-${nextVisitDate.month.toString().padLeft(2, '0')}-${nextVisitDate.day.toString().padLeft(2, '0')}'
            : null,
      );
      final idx = _missions.indexWhere((m) => m.id == missionId);
      if (idx != -1) {
        _missions[idx] = _missions[idx].copyWith(
          providerStatus: 'completed',
          report: report,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
