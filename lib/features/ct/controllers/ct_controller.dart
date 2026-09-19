import 'package:flutter/material.dart';
import '../../../core/models/ct_mission_model.dart';
import '../../../core/services/ct_mission_service.dart';

class CtController extends ChangeNotifier {
  List<CtMissionModel> _missions = [];
  CtMissionModel? _activeMission;
  bool _isLoading = false;
  String? _error;

  List<CtMissionModel> get missions => _missions;
  CtMissionModel? get activeMission => _activeMission;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<CtMissionModel> get pendingMissions =>
      _missions.where((m) => m.isPending || m.isEnRoute || m.isArrived).toList();
  List<CtMissionModel> get completedMissions =>
      _missions.where((m) => m.isCompleted || m.isCancelled).toList();

  Future<void> loadMissions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _missions = await CtMissionService.instance.getMissions();
      _activeMission = _missions.firstWhere(
        (m) => m.isEnRoute || m.isArrived,
        orElse: () => _missions.firstWhere((m) => m.isPending,
            orElse: () => _missions.isEmpty ? throw Exception('') : _missions.first),
      );
    } catch (e) {
      _activeMission = null;
      if (_missions.isEmpty) _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    try {
      final updated = await CtMissionService.instance.updateStatus(id, status);
      final idx = _missions.indexWhere((m) => m.id == id);
      if (idx != -1) {
        _missions[idx] = updated;
        if (_activeMission?.id == id) _activeMission = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitReport(String id, Map<String, dynamic> reportData) async {
    try {
      await CtMissionService.instance.submitReport(id, reportData);
      await updateStatus(id, 'completed');
      return true;
    } catch (e) {
      return false;
    }
  }
}
