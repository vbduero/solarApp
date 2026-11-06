// ============================================================
// Solar-Grow - Formulario para programar una tarea
// ============================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// Abre el formulario para programar una tarea de la planta indicada.
///
/// Devuelve el tipo de la tarea creada, o `null` si no se creó ninguna.
Future<String?> showCreateTaskSheet(
  BuildContext context, {
  required int plantId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SolarColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CreateTaskSheet(plantId: plantId),
  );
}

/// Bottom sheet con el tipo, la fecha y la descripción de la tarea
class CreateTaskSheet extends StatefulWidget {
  final int plantId;

  const CreateTaskSheet({super.key, required this.plantId});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _taskType;
  DateTime? _dueDate;
  bool _saveFailed = false;

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldLabelText: 'Fecha',
      errorFormatText: 'Formato de fecha inválido',
      errorInvalidText: 'Fecha fuera de rango',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _dueDate = picked;
      _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  Future<void> _submit() async {
    setState(() => _saveFailed = false);
    if (!_formKey.currentState!.validate()) return;

    final taskType = _taskType!;
    final description = _descriptionController.text.trim();
    final created = await context.read<TaskProvider>().createTask(
      plantId: widget.plantId,
      taskType: taskType,
      dueDate: _dueDate!,
      description: description.isEmpty ? null : description,
    );
    if (!mounted) return;

    if (created) {
      Navigator.of(context).pop(taskType);
    } else {
      setState(() => _saveFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<TaskProvider>().isLoading;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Programar tarea',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: SolarColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _taskType,
              decoration: const InputDecoration(labelText: 'Tipo de tarea'),
              items: TaskModel.taskTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _taskType = value),
              validator: (value) =>
                  value == null ? 'Selecciona un tipo de tarea' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: SolarColors.primary,
                ),
              ),
              onTap: _pickDate,
              validator: (_) =>
                  _dueDate == null ? 'Selecciona una fecha' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            if (_saveFailed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'No se pudo programar la tarea. Intenta de nuevo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SolarColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
