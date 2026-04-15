// ============================================================
// Solar-Grow - Pantalla para Agregar Planta
// ============================================================
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/plant_provider.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();

  // Imagen seleccionada
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final ImagePicker _picker = ImagePicker();

  // Dropdown states
  String _selectedType = 'Suculento';
  String _selectedLocation = 'Jardin';

  final List<String> _plantTypes = [
    'Suculento',
    'Floral',
    'Acuática',
    'Vegetal',
    'Árbol',
    'Hortaliza',
    'Otro',
  ];
  final List<String> _locations = [
    'Balcon',
    'Dormitorio',
    'Sala',
    'Cocina',
    'Jardin',
    'Terraza',
    'Otro',
  ];

  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<PlantProvider>();
    String? finalImageUrl;

    // Subir imagen si hay alguna seleccionada
    if (_selectedImageBytes != null && _selectedImageName != null) {
      finalImageUrl = await provider.uploadImage(
        _selectedImageBytes!,
        _selectedImageName!,
      );
    }

    final plantData = {
      'common_name': _nameController.text.trim(),
      'plant_type': _selectedType,
      'location': _selectedLocation,
      if (finalImageUrl != null) 'image_url': finalImageUrl,
    };

    final success = await provider.createPlant(plantData);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planta agregada exitosamente 🌱')),
      );
      Navigator.pop(context); // Volver a Home
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Ocurrió un error'),
          backgroundColor: SolarColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(
        title: const Text(
          'Registrar Planta',
          style: TextStyle(color: SolarColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SolarColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos de tu nueva planta',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: SolarColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre Común
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre común / Apodo *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 16),

              // Selección de Imagen
              InkWell(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: SolarColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedImageName ?? 'Seleccionar imagen (Opcional)',
                          style: TextStyle(
                            color: _selectedImageName != null
                                ? SolarColors.textPrimary
                                : SolarColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedImageBytes != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tipo de Planta
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Tipo de planta',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _plantTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),

              // Ubicación
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Ubicación',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _locations
                    .map(
                      (loc) => DropdownMenuItem(value: loc, child: Text(loc)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedLocation = val!),
              ),

              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SolarColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Registrar Planta',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
