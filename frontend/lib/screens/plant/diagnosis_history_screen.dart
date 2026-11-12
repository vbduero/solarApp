// ============================================================
// Solar-Grow - Historial de diagnósticos IA de una planta
// ============================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/diagnosis_model.dart';
import '../../providers/diagnosis_provider.dart';

class DiagnosisHistoryScreen extends StatefulWidget {
  final int plantId;
  final String plantName;

  const DiagnosisHistoryScreen({
    super.key,
    required this.plantId,
    required this.plantName,
  });

  @override
  State<DiagnosisHistoryScreen> createState() => _DiagnosisHistoryScreenState();
}

class _DiagnosisHistoryScreenState extends State<DiagnosisHistoryScreen> {
  /// Evita mostrar el estado vacío antes de que arranque la primera carga
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _started = true;
      context.read<DiagnosisProvider>().loadDiagnoses(widget.plantId);
    });
  }

  Color _statusColor(DiagnosisModel d) {
    switch (d.healthLabel) {
      case 'Excelente':
      case 'Buena':
        return SolarColors.success;
      case 'Regular':
        return SolarColors.warning;
      case 'Mala':
      case 'Crítica':
        return SolarColors.error;
      default:
        return SolarColors.textSecondary;
    }
  }

  String _formatDate(DiagnosisModel d) =>
      DateFormat('dd/MM/yyyy HH:mm').format(d.createdAt.toLocal());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiagnosisProvider>();

    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(title: const Text('Diagnósticos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.plantName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SolarColors.primaryDark,
                ),
              ),
            ),
          ),
          Expanded(child: _buildContent(provider)),
        ],
      ),
    );
  }

  Widget _buildContent(DiagnosisProvider provider) {
    if (provider.isLoading || !_started) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SolarColors.error, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => provider.loadDiagnoses(widget.plantId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.diagnoses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Esta planta aún no tiene diagnósticos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SolarColors.textLight, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: provider.diagnoses.length,
      itemBuilder: (context, index) =>
          _buildCard(provider, provider.diagnoses[index]),
    );
  }

  Widget _noPhoto(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SolarColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Sin foto',
        textAlign: TextAlign.center,
        style: TextStyle(color: SolarColors.textLight, fontSize: 12),
      ),
    );
  }

  Widget _buildPhoto(String? url, {required double size}) {
    if (url == null) return _noPhoto(size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _noPhoto(size),
      ),
    );
  }

  Widget _buildCard(DiagnosisProvider provider, DiagnosisModel d) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(provider, d),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildPhoto(provider.imageUrlFor(d), size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(d),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: SolarColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.healthLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _statusColor(d),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SolarColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(DiagnosisProvider provider, DiagnosisModel d) {
    final text = (d.diagnosis == null || d.diagnosis!.isEmpty)
        ? 'Sin descripción'
        : d.diagnosis!;
    final url = provider.imageUrlFor(d);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDate(d),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: SolarColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                d.healthLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _statusColor(d),
                ),
              ),
              const SizedBox(height: 14),
              Center(child: _buildLargePhoto(url)),
              const SizedBox(height: 14),
              SelectableText(text, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargePhoto(String? url) {
    if (url == null) return _noPhoto(160);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _noPhoto(160),
      ),
    );
  }
}
