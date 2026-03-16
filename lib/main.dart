import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pond_monitoring_app/core/app_sizes.dart';
import 'package:pond_monitoring_app/screen/logging_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:math' as math;

import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize window manager only for desktop platforms (not web)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(1500, 800),
      center: true,
      minimumSize: Size(1500, 800),
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(DevicePreview(enabled: false, builder: (context) => const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Pond Monitoring System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'PlusJakartaSans',
        ),
        home: LoginScreen(),
        useInheritedMediaQuery: true,
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
      ),
    );
  }
}

// Motor Configuration Model
class MotorConfig {
  String name;
  bool autoMode;
  String parameter; // 'temperature', 'ph_level', 'dissolved_oxygen'
  double minValue;
  double maxValue;
  String turnOnWhen; // 'below_min', 'above_max'

  MotorConfig({
    required this.name,
    this.autoMode = false,
    this.parameter = 'temperature',
    this.minValue = 0.0,
    this.maxValue = 50.0,
    this.turnOnWhen = 'below_min',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'auto_mode': autoMode,
      'parameter': parameter,
      'min_value': minValue,
      'max_value': maxValue,
      'turn_on_when': turnOnWhen,
    };
  }

  factory MotorConfig.fromJson(Map<String, dynamic> json) {
    return MotorConfig(
      name: json['name'] ?? '',
      autoMode: json['auto_mode'] ?? false,
      parameter: json['parameter'] ?? 'temperature',
      minValue: (json['min_value'] ?? 0.0).toDouble(),
      maxValue: (json['max_value'] ?? 50.0).toDouble(),
      turnOnWhen: json['turn_on_when'] ?? 'below_min',
    );
  }
}

// Motor Configuration Screen
class MotorConfigScreen extends StatefulWidget {
  final List<MotorConfig> motorConfigs;
  final Function(List<MotorConfig>) onConfigSaved;

  const MotorConfigScreen({
    Key? key,
    required this.motorConfigs,
    required this.onConfigSaved,
  }) : super(key: key);

  @override
  _MotorConfigScreenState createState() => _MotorConfigScreenState();
}

class _MotorConfigScreenState extends State<MotorConfigScreen> {
  late List<MotorConfig> configs;
  late PageController _pageController;
  int currentMotor = 0;

  @override
  void initState() {
    super.initState();
    configs = widget.motorConfigs
        .map(
          (config) => MotorConfig(
            name: config.name,
            autoMode: config.autoMode,
            parameter: config.parameter,
            minValue: config.minValue,
            maxValue: config.maxValue,
            turnOnWhen: config.turnOnWhen,
          ),
        )
        .toList();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90E2), Color(0xFF7B68EE), Color(0xFF2E8B57)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'Motor Configuration',
                        style: context.textStyles.h2.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        widget.onConfigSaved(configs);
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.check, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Motor tabs
              Container(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          currentMotor = index;
                        });
                        _pageController.animateToPage(
                          index,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: currentMotor == index
                                ? [
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.2),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: currentMotor == index
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'Motor ${index + 1}',
                          style: context.textStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: currentMotor == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Configuration content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentMotor = index;
                    });
                  },
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return _buildMotorConfig(index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMotorConfig(int motorIndex) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.2),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Motor Name
            Text(
              'Motor Name',
              style: context.textStyles.subtitle.copyWith(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              style: context.textStyles.input.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter motor name',
                hintStyle: context.textStyles.inputHint,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              controller: TextEditingController(text: configs[motorIndex].name),
              onChanged: (value) {
                configs[motorIndex].name = value;
              },
            ),

            SizedBox(height: 30),

            // Auto Mode Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auto Mode',
                  style: context.textStyles.subtitle.copyWith(
                    color: Colors.white,
                  ),
                ),
                Switch(
                  value: configs[motorIndex].autoMode,
                  onChanged: (value) {
                    setState(() {
                      configs[motorIndex].autoMode = value;
                    });
                  },
                  activeColor: Colors.cyan,
                ),
              ],
            ),

            if (configs[motorIndex].autoMode) ...[
              SizedBox(height: 30),

              // Parameter Selection
              Text(
                'Control Parameter',
                style: context.textStyles.subtitle.copyWith(
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: DropdownButtonFormField<String>(
                  value: configs[motorIndex].parameter,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  dropdownColor: Color(0xFF4A90E2),
                  style: context.textStyles.body.copyWith(color: Colors.white),
                  items: [
                    DropdownMenuItem(
                      value: 'temperature',
                      child: Text(
                        'Temperature (°C)',
                        style: context.textStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ph_level',
                      child: Text(
                        'pH Level',
                        style: context.textStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'dissolved_oxygen',
                      child: Text(
                        'Dissolved Oxygen (mg/L)',
                        style: context.textStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      configs[motorIndex].parameter = value!;
                    });
                  },
                ),
              ),

              SizedBox(height: 30),

              // Turn On When
              Text(
                'Turn ON When',
                style: context.textStyles.subtitle.copyWith(
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: DropdownButtonFormField<String>(
                  value: configs[motorIndex].turnOnWhen,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  dropdownColor: Color(0xFF4A90E2),
                  style: context.textStyles.body.copyWith(color: Colors.white),
                  items: [
                    DropdownMenuItem(
                      value: 'below_min',
                      child: Text(
                        'Below Minimum',
                        style: context.textStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'above_max',
                      child: Text(
                        'Above Maximum',
                        style: context.textStyles.body.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      configs[motorIndex].turnOnWhen = value!;
                    });
                  },
                ),
              ),

              SizedBox(height: 30),

              // Min/Max Values
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minimum Value',
                          style: context.textStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          style: context.textStyles.input.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.0',
                            hintStyle: context.textStyles.inputHint,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          controller: TextEditingController(
                            text: configs[motorIndex].minValue.toString(),
                          ),
                          onChanged: (value) {
                            configs[motorIndex].minValue =
                                double.tryParse(value) ?? 0.0;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maximum Value',
                          style: context.textStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          style: context.textStyles.input.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: '50.0',
                            hintStyle: context.textStyles.inputHint,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          controller: TextEditingController(
                            text: configs[motorIndex].maxValue.toString(),
                          ),
                          onChanged: (value) {
                            configs[motorIndex].maxValue =
                                double.tryParse(value) ?? 50.0;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Logic Explanation
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Control Logic:',
                      style: context.textStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      configs[motorIndex].turnOnWhen == 'below_min'
                          ? '• Turn ON when ${_getParameterName(configs[motorIndex].parameter)} < ${configs[motorIndex].minValue}\n• Turn OFF when ${_getParameterName(configs[motorIndex].parameter)} > ${configs[motorIndex].maxValue}'
                          : '• Turn ON when ${_getParameterName(configs[motorIndex].parameter)} > ${configs[motorIndex].maxValue}\n• Turn OFF when ${_getParameterName(configs[motorIndex].parameter)} < ${configs[motorIndex].minValue}',
                      style: context.textStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getParameterName(String parameter) {
    switch (parameter) {
      case 'temperature':
        return 'Temperature';
      case 'ph_level':
        return 'pH';
      case 'dissolved_oxygen':
        return 'DO';
      default:
        return parameter;
    }
  }
}

// Custom Painter for Thermometer
class ThermometerPainter extends CustomPainter {
  final double temperature;
  final double animationValue;
  final Color color;

  ThermometerPainter({
    required this.temperature,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.4,
        size.height * 0.7,
      ),
      Radius.circular(size.width * 0.2),
    );
    canvas.drawRRect(bodyRect, outlinePaint);

    final bulbCenter = Offset(size.width * 0.5, size.height * 0.85);
    canvas.drawCircle(bulbCenter, size.width * 0.25, outlinePaint);

    double tempPercent = ((temperature - 0) / 50).clamp(0.0, 1.0);
    double animatedPercent = tempPercent * animationValue;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.8), color],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawCircle(bulbCenter, size.width * 0.22, fillPaint);

    final fillHeight = (size.height * 0.7) * animatedPercent;
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.32,
        size.height * 0.8 - fillHeight,
        size.width * 0.36,
        fillHeight + size.height * 0.05,
      ),
      Radius.circular(size.width * 0.18),
    );
    canvas.drawRRect(fillRect, fillPaint);

    final scalePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      double y = size.height * 0.15 + (size.height * 0.6) * (i / 5);
      canvas.drawLine(
        Offset(size.width * 0.75, y),
        Offset(size.width * 0.85, y),
        scalePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter for pH Scale
class PhScalePainter extends CustomPainter {
  final double phLevel;
  final double animationValue;

  PhScalePainter({required this.phLevel, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.lightBlue,
      Colors.blue,
      Colors.purple,
    ];

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        stops: [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.3));

    final scaleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2),
      Radius.circular(size.height * 0.1),
    );
    canvas.drawRRect(scaleRect, gradientPaint);

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(scaleRect, outlinePaint);

    double phPosition = (phLevel / 14).clamp(0.0, 1.0);
    double animatedPosition = phPosition * animationValue;

    final indicatorX = size.width * animatedPosition;
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final indicatorPath = Path();
    indicatorPath.moveTo(indicatorX, size.height * 0.35);
    indicatorPath.lineTo(indicatorX - 8, size.height * 0.25);
    indicatorPath.lineTo(indicatorX + 8, size.height * 0.25);
    indicatorPath.close();

    canvas.drawPath(indicatorPath, indicatorPaint);
    canvas.drawPath(
      indicatorPath,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    final textPaint = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 14; i += 2) {
      textPaint.text = TextSpan(
        text: '$i',
        style: AppTextStyles.micro.copyWith(
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.bold,
        ),
      );
      textPaint.layout();

      final x = size.width * (i / 14) - textPaint.width / 2;
      textPaint.paint(canvas, Offset(x, size.height * 0.65));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter for Oxygen Gauge
class OxygenGaugePainter extends CustomPainter {
  final double oxygenLevel;
  final double animationValue;
  final double bubbleAnimation;
  final Color color;

  OxygenGaugePainter({
    required this.oxygenLevel,
    required this.animationValue,
    required this.bubbleAnimation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius + 2, shadowPaint);

    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    final innerBackgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, innerBackgroundPaint);

    final oxygenPercent = (oxygenLevel / 20).clamp(0.0, 1.0);
    final animatedPercent = oxygenPercent * animationValue;

    final gaugePaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.7), color, color.withOpacity(0.9)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      (3 * math.pi / 2) * animatedPercent,
      false,
      gaugePaint,
    );

    if (animatedPercent > 0) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.3),
            color.withOpacity(0.1),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        (3 * math.pi / 2) * animatedPercent,
        false,
        glowPaint,
      );
    }

    final bubblePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 20));

    final random = math.Random(42);
    for (int i = 0; i < 12; i++) {
      final angle = (2 * math.pi * i / 12) + (bubbleAnimation * math.pi / 3);
      final bubbleRadius =
          radius * (0.4 + 0.3 * math.sin(bubbleAnimation * math.pi + i));
      final bubbleSize = (4 + random.nextDouble() * 6) *
          (0.6 + 0.4 * math.sin(bubbleAnimation * 2 * math.pi + i));

      final bubbleX = center.dx + bubbleRadius * math.cos(angle);
      final bubbleY = center.dy + bubbleRadius * math.sin(angle);

      canvas.drawCircle(
        Offset(bubbleX, bubbleY),
        bubbleSize * animationValue,
        bubblePaint,
      );

      final highlightPaint = Paint()..color = Colors.white.withOpacity(0.8);
      canvas.drawCircle(
        Offset(bubbleX - bubbleSize * 0.3, bubbleY - bubbleSize * 0.3),
        bubbleSize * 0.3 * animationValue,
        highlightPaint,
      );
    }

    final markerPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 8; i++) {
      final angle = -math.pi / 2 + ((3 * math.pi / 2) * i / 8);
      final innerRadius = radius - 25;
      final outerRadius = radius - 10;

      final startX = center.dx + innerRadius * math.cos(angle);
      final startY = center.dy + innerRadius * math.sin(angle);
      final endX = center.dx + outerRadius * math.cos(angle);
      final endY = center.dy + outerRadius * math.sin(angle);

      if (i % 2 == 0) {
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          markerPaint,
        );

        if (i <= 6) {
          int oxygenValue = (i * 2.5).round();
          if (oxygenValue % 5 == 0) {
            textPainter.text = TextSpan(
              text: '$oxygenValue',
              style: AppTextStyles.micro.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            );
            textPainter.layout();

            final textRadius = radius - 35;
            final textX = center.dx +
                textRadius * math.cos(angle) -
                textPainter.width / 2;
            final textY = center.dy +
                textRadius * math.sin(angle) -
                textPainter.height / 2;

            textPainter.paint(canvas, Offset(textX, textY));
          }
        }
      } else {
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX - 5, endY - 5),
          Paint()
            ..color = Colors.white.withOpacity(0.5)
            ..strokeWidth = 2,
        );
      }
    }

    final centerDotPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.4)],
      ).createShader(Rect.fromCircle(center: center, radius: 8));
    canvas.drawCircle(center, 6, centerDotPaint);

    final ringHighlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius + 12, ringHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
