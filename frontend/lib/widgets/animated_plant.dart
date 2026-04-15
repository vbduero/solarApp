// ============================================================
// Solar-Grow - Widget de Planta Animada Interactiva
// ============================================================
// Este widget muestra una planta animada con expresiones faciales
// que cambian según el estado de salud de la planta.
// - Feliz: La planta está sana y bien cuidada
// - Triste: Necesita agua, sol o abono
// ============================================================
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Widget que representa la planta con animaciones y expresiones
class AnimatedPlantWidget extends StatefulWidget {
  /// Nombre de la planta que se muestra en la maceta
  final String plantName;

  /// Puntaje de salud de 0-100 (determina la expresión)
  final double healthScore;

  /// Estado de salud: healthy, needs_water, needs_light, critical
  final String healthStatus;

  /// Si se está regando activamente
  final bool isWatering;

  /// Tamaño del widget
  final double size;

  const AnimatedPlantWidget({
    super.key,
    required this.plantName,
    this.healthScore = 100.0,
    this.healthStatus = 'healthy',
    this.isWatering = false,
    this.size = 280,
  });

  @override
  State<AnimatedPlantWidget> createState() => _AnimatedPlantWidgetState();
}

class _AnimatedPlantWidgetState extends State<AnimatedPlantWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _breathController;
  late AnimationController _blinkController;
  late AnimationController _waterDropController;

  late Animation<double> _bounceAnimation;
  late Animation<double> _breathAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _waterDropAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de rebote suave (toda la planta)
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Animación de respiración (escala)
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Animación de parpadeo
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _startBlinking();

    // Animación de gotas de agua
    _waterDropController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _waterDropAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waterDropController, curve: Curves.easeIn),
    );

    if (widget.isWatering) {
      _waterDropController.repeat();
    }
  }

  void _startBlinking() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2500 + Random().nextInt(3000)),
      );
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void didUpdateWidget(AnimatedPlantWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWatering && !oldWidget.isWatering) {
      _waterDropController.repeat();
    } else if (!widget.isWatering && oldWidget.isWatering) {
      _waterDropController.stop();
      _waterDropController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _breathController.dispose();
    _blinkController.dispose();
    _waterDropController.dispose();
    super.dispose();
  }

  bool get _isHealthy => widget.healthScore >= 60;
  bool get _isCritical => widget.healthScore < 30;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bounceAnimation,
        _breathAnimation,
        _blinkAnimation,
        _waterDropAnimation,
      ]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size + 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gotas de agua (si se está regando)
              if (widget.isWatering) ..._buildWaterDrops(),

              // Planta completa con animación
              Transform.translate(
                offset: Offset(0, -_bounceAnimation.value),
                child: Transform.scale(
                  scale: _breathAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hojas de la planta
                      _buildLeaves(),
                      // Tallo
                      _buildStem(),
                      // Maceta con cara
                      _buildPot(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construye las hojas de la planta
  Widget _buildLeaves() {
    final leafColor = _isHealthy
        ? SolarColors.primaryLight
        : _isCritical
        ? const Color(0xFFCD853F) // Marrón dorado (marchitas)
        : const Color(0xFFDAA520); // Amarillento (estresada)

    final droopAngle = _isHealthy ? 0.0 : (_isCritical ? 0.3 : 0.15);

    return SizedBox(
      width: widget.size * 0.65,
      height: widget.size * 0.42,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Hoja central
          Positioned(
            bottom: 0,
            child: Transform.rotate(
              angle: 0,
              child: _buildLeaf(
                width: widget.size * 0.15,
                height: widget.size * 0.35,
                color: leafColor,
                droopAngle: 0,
              ),
            ),
          ),
          // Hojas izquierdas
          Positioned(
            bottom: 5,
            left: widget.size * 0.08,
            child: Transform.rotate(
              angle: -0.5 - droopAngle,
              child: _buildLeaf(
                width: widget.size * 0.18,
                height: widget.size * 0.30,
                color: leafColor.withValues(alpha: 0.9),
                droopAngle: droopAngle,
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            left: -widget.size * 0.02,
            child: Transform.rotate(
              angle: -1.0 - droopAngle * 1.5,
              child: _buildLeaf(
                width: widget.size * 0.15,
                height: widget.size * 0.25,
                color: leafColor.withValues(alpha: 0.8),
                droopAngle: droopAngle * 1.5,
              ),
            ),
          ),
          // Hojas derechas
          Positioned(
            bottom: 5,
            right: widget.size * 0.08,
            child: Transform.rotate(
              angle: 0.5 + droopAngle,
              child: _buildLeaf(
                width: widget.size * 0.18,
                height: widget.size * 0.30,
                color: leafColor.withValues(alpha: 0.9),
                droopAngle: droopAngle,
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            right: -widget.size * 0.02,
            child: Transform.rotate(
              angle: 1.0 + droopAngle * 1.5,
              child: _buildLeaf(
                width: widget.size * 0.15,
                height: widget.size * 0.25,
                color: leafColor.withValues(alpha: 0.8),
                droopAngle: droopAngle * 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una hoja individual
  Widget _buildLeaf({
    required double width,
    required double height,
    required Color color,
    double droopAngle = 0,
  }) {
    return CustomPaint(
      size: Size(width, height),
      painter: _LeafPainter(color: color),
    );
  }

  /// Construye el tallo
  Widget _buildStem() {
    return Container(
      width: 8,
      height: widget.size * 0.08,
      decoration: BoxDecoration(
        color: _isHealthy ? SolarColors.primary : const Color(0xFF8B7355),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  /// Construye la maceta con expresión facial
  Widget _buildPot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Maceta estilo terracota (más ancha y curva estilo bowl)
        CustomPaint(
          size: Size(widget.size * 0.6, widget.size * 0.35),
          painter: _PotPainter(),
        ),
        // Nombre de la planta en el borde de arriba
        Positioned(
          top: widget.size * 0.01,
          child: Text(
            widget.plantName,
            style: TextStyle(
              color: const Color(0xFF3B2A1A).withValues(alpha: 0.85),
              fontSize: widget.size * 0.055,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        // Cara de la maceta centrada en la "panza" inferior
        Positioned(top: widget.size * 0.15, child: _buildFace()),
      ],
    );
  }

  /// Construye la cara expresiva de la maceta
  Widget _buildFace() {
    final eyeSize = widget.size * 0.04;
    final mouthSize = widget.size * 0.06;

    return SizedBox(
      width: widget.size * 0.25,
      height: widget.size * 0.12,
      child: Stack(
        children: [
          // Ojo izquierdo
          Positioned(
            left: widget.size * 0.04,
            top: 0,
            child: _buildEye(eyeSize),
          ),
          // Ojo derecho
          Positioned(
            right: widget.size * 0.04,
            top: 0,
            child: _buildEye(eyeSize),
          ),
          // Boca
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(child: _buildMouth(mouthSize)),
          ),
        ],
      ),
    );
  }

  /// Ojo con animación de parpadeo
  Widget _buildEye(double size) {
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        return Container(
          width: size * 1.8,
          height: size * 1.8 * _blinkAnimation.value,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: const Color(0xFF4A3728), width: 2),
          ),
          child: _blinkAnimation.value > 0.5
              ? Center(
                  child: Container(
                    width: size * 0.8,
                    height: size * 0.8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C1810),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.3,
                        height: size * 0.3,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Boca feliz o triste según el estado
  Widget _buildMouth(double size) {
    if (_isHealthy) {
      // Boca feliz - sonrisa amplia con lengua
      return SizedBox(
        width: size * 2.5,
        height: size * 1.5,
        child: CustomPaint(painter: _SmilePainter(showTongue: true)),
      );
    } else {
      // Boca triste
      return SizedBox(
        width: size * 2,
        height: size * 1.2,
        child: CustomPaint(painter: _SadMouthPainter(isCritical: _isCritical)),
      );
    }
  }

  /// Gotas de agua durante el riego
  List<Widget> _buildWaterDrops() {
    return List.generate(5, (index) {
      final xOffset = (index - 2) * 20.0;
      final delay = index * 0.2;
      final progress = (_waterDropAnimation.value + delay) % 1.0;

      return Positioned(
        top: widget.size * 0.1 + progress * widget.size * 0.5,
        left: widget.size / 2 + xOffset,
        child: Opacity(
          opacity: (1.0 - progress).clamp(0.0, 1.0),
          child: Icon(
            Icons.water_drop,
            color: SolarColors.skyBlue.withValues(alpha: 0.7),
            size: 16,
          ),
        ),
      );
    });
  }
}

// ============================================================
// Custom Painters
// ============================================================

/// Pintor de hojas con forma orgánica
class _LeafPainter extends CustomPainter {
  final Color color;

  _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height);
    path.cubicTo(
      -size.width * 0.3,
      size.height * 0.5,
      -size.width * 0.1,
      size.height * 0.1,
      size.width / 2,
      0,
    );
    path.cubicTo(
      size.width * 1.1,
      size.height * 0.1,
      size.width * 1.3,
      size.height * 0.5,
      size.width / 2,
      size.height,
    );
    path.close();
    canvas.drawPath(path, paint);

    // Nervadura central
    final veinPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final veinPath = Path();
    veinPath.moveTo(size.width / 2, size.height);
    veinPath.lineTo(size.width / 2, size.height * 0.1);
    canvas.drawPath(veinPath, veinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor de maceta estilo terracota
class _PotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Borde superior de la maceta
    final rimPaint = Paint()
      ..color = const Color(0xFFB8734A)
      ..style = PaintingStyle.fill;

    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -size.width * 0.05,
        0,
        size.width * 1.1,
        size.height * 0.15,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(rimRect, rimPaint);

    // Cuerpo de la maceta (estilo bowl curvo)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFCD7F4B), const Color(0xFFB56A3A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final bodyPath = Path();
    bodyPath.moveTo(size.width * 0.05, size.height * 0.15);
    // Curva izquierda hacia la base
    bodyPath.quadraticBezierTo(
      size.width * 0.08,
      size.height * 0.85,
      size.width * 0.3,
      size.height * 0.95,
    );
    // Base ligeramente recta
    bodyPath.lineTo(size.width * 0.7, size.height * 0.95);
    // Curva derecha hacia arriba
    bodyPath.quadraticBezierTo(
      size.width * 0.92,
      size.height * 0.85,
      size.width * 0.95,
      size.height * 0.15,
    );
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor de sonrisa feliz
class _SmilePainter extends CustomPainter {
  final bool showTongue;

  _SmilePainter({this.showTongue = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Boca sonriente
    final mouthPaint = Paint()
      ..color = const Color(0xFF4A3728)
      ..style = PaintingStyle.fill;

    final mouthPath = Path();
    mouthPath.moveTo(0, size.height * 0.1);
    mouthPath.quadraticBezierTo(
      size.width / 2,
      size.height * 1.2,
      size.width,
      size.height * 0.1,
    );
    mouthPath.close();
    canvas.drawPath(mouthPath, mouthPaint);

    // Lengua
    if (showTongue) {
      final tonguePaint = Paint()
        ..color = const Color(0xFFE75480)
        ..style = PaintingStyle.fill;

      final tonguePath = Path();
      tonguePath.moveTo(size.width * 0.35, size.height * 0.5);
      tonguePath.quadraticBezierTo(
        size.width / 2,
        size.height * 1.1,
        size.width * 0.65,
        size.height * 0.5,
      );
      canvas.drawPath(tonguePath, tonguePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor de boca triste
class _SadMouthPainter extends CustomPainter {
  final bool isCritical;

  _SadMouthPainter({this.isCritical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final mouthPaint = Paint()
      ..color = const Color(0xFF4A3728)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.7);
    path.quadraticBezierTo(
      size.width / 2,
      isCritical ? -size.height * 0.3 : size.height * 0.1,
      size.width * 0.85,
      size.height * 0.7,
    );
    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
