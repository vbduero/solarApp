// ============================================================
// Solar-Grow - Provider del historial de diagnósticos IA
// ============================================================
import 'package:flutter/foundation.dart';
import '../config/api_constants.dart';
import '../models/diagnosis_model.dart';
import '../services/api_service.dart';

class DiagnosisProvider extends ChangeNotifier {
  List<DiagnosisModel> _diagnoses = [];
  bool _isLoading = false;
  String? _error;

  /// Identifica la última petición; las respuestas anteriores se descartan.
  int _requestCounter = 0;

  List<DiagnosisModel> get diagnoses => _diagnoses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Carga los diagnósticos de una planta, del más reciente al más antiguo.
  Future<bool> loadDiagnoses(int plantId) async {
    final requestId = ++_requestCounter;
    _diagnoses = [];
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.get('${ApiConstants.aiDiagnosis}/$plantId');
      if (requestId != _requestCounter) return false;
      final list =
          (data as List)
              .map((e) => DiagnosisModel.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) {
              final byDate = b.createdAt.compareTo(a.createdAt);
              return byDate != 0 ? byDate : b.id.compareTo(a.id);
            });
      _diagnoses = list;
      return true;
    } catch (e) {
      debugPrint('Error al cargar diagnósticos: $e');
      if (requestId != _requestCounter) return false;
      _diagnoses = [];
      _error = 'No se pudieron cargar los diagnósticos.';
      return false;
    } finally {
      if (requestId == _requestCounter) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// URL absoluta de la foto del diagnóstico, o null si no tiene.
  String? imageUrlFor(DiagnosisModel d) {
    final path = d.imageUrl;
    if (path == null || path.isEmpty) return null;
    return '${ApiService.baseUrl}$path';
  }
}
