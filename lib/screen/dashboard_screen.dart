// Main Dashboard with Sensor Data and Motor Controls
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:imesh_ayya/screen/logging_screen.dart';
import 'package:imesh_ayya/main.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class PondDashboard extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> deviceData;

  const PondDashboard({
    Key? key,
    required this.deviceId,
    required this.deviceData,
  }) : super(key: key);

  @override
  _PondDashboardState createState() => _PondDashboardState();
}

class _PondDashboardState extends State<PondDashboard>
    with TickerProviderStateMixin {
  bool _isShuttingDown = false;

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isShuttingDown) return;
    setState(fn);
  }

  // MQTT Configuration
  final String mqttHost = "broker.emqx.io";
  final int mqttPort = 1883;
  late String mqttDataTopic;
  late String mqttCommandTopic;
  late String mqttStatusTopic;
  late String mqttConfigTopic;
  late String mqttDeviceConfigTopic; // NEW: Device config topic

  MqttServerClient? client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>?
  _mqttUpdatesSubscription;

  // Sensor Data (actual values from MQTT)
  String connectionStatus = "Connecting...";
  late String deviceId;
  double temperature = 25.0;
  double phLevel = 7.0;
  double dissolvedOxygen = 8.0;
  String lastUpdate = "Never";
  int messagesReceived = 0;

  // Displayed Values (what the UI shows during animations)
  double displayedTemperature = 25.0;
  double displayedPhLevel = 7.0;
  double displayedDissolvedOxygen = 8.0;

  // Motor Control States
  List<bool> motorStates = [false, false, false, false, false];
  List<String> motorNames = [
    'Water Pump',
    'Air Pump',
    'Heater',
    'UV Light',
    'Feeder',
  ];
  List<IconData> motorIcons = [
    Icons.water_drop,
    Icons.air,
    Icons.thermostat,
    Icons.light_mode,
    Icons.restaurant,
  ];

  // Motor Configurations
  List<MotorConfig> motorConfigs = [];

  // Batch Timer for Motor Commands
  Timer? _batchTimer;
  static const Duration _batchDelay = Duration(seconds: 3);

  // Carousel/PageView for Sensor Visualizations
  late PageController _sensorPageController;
  Timer? _autoScrollTimer;
  int _currentSensorPage = 0;
  static const Duration _autoScrollDelay = Duration(seconds: 5);

  // Animation controllers
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _temperatureController;
  late AnimationController _phController;
  late AnimationController _oxygenController;
  late AnimationController _bubbleController;
  late List<AnimationController> _motorControllers;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _temperatureAnimation;
  late Animation<double> _phAnimation;
  late Animation<double> _oxygenAnimation;
  late Animation<double> _bubbleAnimation;

  @override
  void initState() {
    super.initState();

    deviceId = widget.deviceId;
    mqttDataTopic = "idea8/${deviceId}/data";
    mqttCommandTopic = "idea8/${deviceId}/cmd";
    mqttStatusTopic = "idea8/${deviceId}/status";
    mqttConfigTopic = "idea8/${deviceId}/switch_config";
    mqttDeviceConfigTopic =
        "idea8/${deviceId}/device_config"; // NEW: Device config topic

    // Initialize motor configurations with defaults
    for (int i = 0; i < 5; i++) {
      motorConfigs.add(MotorConfig(name: motorNames[i]));
    }

    // Setup animations
    _waveController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _temperatureController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _phController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _oxygenController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _bubbleController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Motor switch animations
    _motorControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    // Initialize animations with current values
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);

    // Initialize sensor animations to start at current values
    _temperatureAnimation =
        Tween<double>(
          begin: displayedTemperature,
          end: displayedTemperature,
        ).animate(
          CurvedAnimation(
            parent: _temperatureController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _phAnimation = Tween<double>(begin: displayedPhLevel, end: displayedPhLevel)
        .animate(
          CurvedAnimation(parent: _phController, curve: Curves.easeInOutCubic),
        );
    _oxygenAnimation =
        Tween<double>(
          begin: displayedDissolvedOxygen,
          end: displayedDissolvedOxygen,
        ).animate(
          CurvedAnimation(
            parent: _oxygenController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _bubbleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_bubbleController);

    // Initialize PageController for sensor carousel
    _sensorPageController = PageController(viewportFraction: 0.95);

    // Start auto-scroll timer for sensor cards
    _startSensorAutoScroll();

    // Add animation listeners to update displayed values
    _temperatureController.addListener(() {
      _safeSetState(() {
        displayedTemperature = _temperatureAnimation.value;
      });
    });

    _phController.addListener(() {
      _safeSetState(() {
        displayedPhLevel = _phAnimation.value;
      });
    });

    _oxygenController.addListener(() {
      _safeSetState(() {
        displayedDissolvedOxygen = _oxygenAnimation.value;
      });
    });

    connectToMQTT();
  }

  Future<void> connectToMQTT() async {
    client = MqttServerClient(
      mqttHost,
      '${deviceId}_monitor_${DateTime.now().millisecondsSinceEpoch}',
    );
    client!.port = mqttPort;
    client!.keepAlivePeriod = 30;
    client!.autoReconnect = true;
    client!.resubscribeOnAutoReconnect = true;
    client!.onConnected = onConnected;
    client!.onDisconnected = onDisconnected;
    client!.onAutoReconnect = () {
      _safeSetState(() {
        connectionStatus = "Reconnecting...";
      });
      print('MQTT auto reconnecting...');
    };
    client!.onAutoReconnected = () {
      print('MQTT auto reconnected');
    };

    client!.connectionMessage = MqttConnectMessage()
        .withWillTopic('willtopic')
        .withWillMessage('${deviceId} monitor disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await client!.connect();
    } catch (e) {
      client?.disconnect();
      _safeSetState(() {
        connectionStatus = "Connection Failed";
      });
      print('MQTT connection error: $e');
    }
  }

  void onConnected() {
    _safeSetState(() {
      connectionStatus = "Connected";
    });

    print('Connected to MQTT broker: $mqttHost');
    print('Subscribed to topics:');
    print('  Device Config: $mqttDeviceConfigTopic');
    print('  Data: $mqttDataTopic');
    print('  Status: $mqttStatusTopic');

    // NEW: Subscribe to device config first to receive retained configuration
    client!.subscribe(mqttDeviceConfigTopic, MqttQos.atMostOnce);

    // Then subscribe to data and status topics
    client!.subscribe(mqttDataTopic, MqttQos.atMostOnce);
    client!.subscribe(mqttStatusTopic, MqttQos.atMostOnce);

    _mqttUpdatesSubscription?.cancel();
    _mqttUpdatesSubscription = client!.updates!.listen(
      (List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final message = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        final topic = c[0].topic;

        print('MQTT Message Received on $topic:');
        print(message);
        print('------------------------');

        try {
          final jsonData = jsonDecode(message) as Map<String, dynamic>;

          if (topic == mqttDeviceConfigTopic) {
            // NEW: Handle device configuration messages
            updateDeviceConfiguration(jsonData);
          } else if (topic == mqttDataTopic) {
            updateSensorData(jsonData);
          } else if (topic == mqttStatusTopic) {
            updateMotorStatus(jsonData);
          }
        } catch (e) {
          print('Error parsing JSON: $e');
        }
      },
      onError: (Object error) {
        print('MQTT updates stream error: $error');
      },
      cancelOnError: false,
    );
  }

  // NEW: Handle device configuration updates
  void updateDeviceConfiguration(Map<String, dynamic> jsonData) {
    if (!mounted || _isShuttingDown) return;
    try {
      print('Received device configuration: $jsonData');

      // Update motor configurations based on received data
      for (int i = 0; i < 5; i++) {
        String motorKey = 'motor${i + 1}';
        if (jsonData.containsKey(motorKey)) {
          Map<String, dynamic> motorData = jsonData[motorKey];

          // Create new motor config from received data
          motorConfigs[i] = MotorConfig.fromJson(motorData);

          // Update motor names
          if (motorConfigs[i].name.isNotEmpty) {
            motorNames[i] = motorConfigs[i].name;
          }
        }
      }

      _safeSetState(() {});

      print('Updated motor configurations from device');
    } catch (e) {
      print('Error updating device configuration: $e');
      // Keep existing defaults if parsing fails
    }
  }

  void updateSensorData(Map<String, dynamic> jsonData) {
    if (!mounted || _isShuttingDown) return;
    try {
      // Store what user currently sees (displayed values)
      double oldDisplayedTemp = displayedTemperature;
      double oldDisplayedPh = displayedPhLevel;
      double oldDisplayedOxygen = displayedDissolvedOxygen;

      // Update actual sensor values
      if (jsonData.containsKey('temperature')) {
        temperature = (jsonData['temperature'] as num).toDouble();
      }

      if (jsonData.containsKey('ph_value')) {
        phLevel = (jsonData['ph_value'] as num).toDouble();
      }

      if (jsonData.containsKey('do_level')) {
        dissolvedOxygen = (jsonData['do_level'] as num).toDouble();
      }

      if (jsonData.containsKey('timestamp')) {
        lastUpdate = jsonData['timestamp'].toString();
      } else {
        lastUpdate = DateTime.now().toString().substring(11, 19);
      }

      messagesReceived++;

      // Create smooth animations from current displayed values to new values
      if ((oldDisplayedTemp - temperature).abs() > 0.1) {
        // Only animate if change is significant
        _temperatureAnimation =
            Tween<double>(begin: oldDisplayedTemp, end: temperature).animate(
              CurvedAnimation(
                parent: _temperatureController,
                curve: Curves.easeInOutCubic,
              ),
            );
        _temperatureController.reset();
        _temperatureController.forward();
      }

      if ((oldDisplayedPh - phLevel).abs() > 0.05) {
        _phAnimation = Tween<double>(begin: oldDisplayedPh, end: phLevel)
            .animate(
              CurvedAnimation(
                parent: _phController,
                curve: Curves.easeInOutCubic,
              ),
            );
        _phController.reset();
        _phController.forward();
      }

      if ((oldDisplayedOxygen - dissolvedOxygen).abs() > 0.1) {
        _oxygenAnimation =
            Tween<double>(
              begin: oldDisplayedOxygen,
              end: dissolvedOxygen,
            ).animate(
              CurvedAnimation(
                parent: _oxygenController,
                curve: Curves.easeInOutCubic,
              ),
            );
        _oxygenController.reset();
        _oxygenController.forward();
      }

      _safeSetState(() {}); // Update UI for non-animated values

      print(
        'Updated sensor data for $deviceId - Temp: $temperature, pH: $phLevel, DO: $dissolvedOxygen',
      );
    } catch (e) {
      print('Error updating sensor data: $e');
    }
  }

  void updateMotorStatus(Map<String, dynamic> jsonData) {
    if (!mounted || _isShuttingDown) return;
    _safeSetState(() {
      try {
        for (int i = 0; i < 5; i++) {
          String motorKey = 'motor${i + 1}';
          if (jsonData.containsKey(motorKey)) {
            bool newState =
                jsonData[motorKey] == 'on' || jsonData[motorKey] == true;
            if (motorStates[i] != newState) {
              motorStates[i] = newState;
              if (newState) {
                _motorControllers[i].forward();
              } else {
                _motorControllers[i].reverse();
              }
            }
          }
        }

        print('Updated motor status: $motorStates');
      } catch (e) {
        print('Error updating motor status: $e');
      }
    });
  }

  // Batched Motor Command Method
  void sendBatchedMotorCommands() {
    if (client == null ||
        client!.connectionStatus!.state != MqttConnectionState.connected) {
      print('MQTT not connected, cannot send batched commands');
      return;
    }

    // Create command object with all 5 motor states
    Map<String, dynamic> batchCommand = {
      'motor1': motorStates[0] ? 'on' : 'off',
      'motor2': motorStates[1] ? 'on' : 'off',
      'motor3': motorStates[2] ? 'on' : 'off',
      'motor4': motorStates[3] ? 'on' : 'off',
      'motor5': motorStates[4] ? 'on' : 'off',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'batch': true, // Flag to indicate this is a batched command
    };

    String commandJson = jsonEncode(batchCommand);

    print('Sending batched motor commands to $mqttCommandTopic:');
    print(commandJson);

    final builder = MqttClientPayloadBuilder();
    builder.addString(commandJson);

    client!.publishMessage(
      mqttCommandTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  // Start/Reset Batch Timer
  void _startBatchTimer() {
    // Cancel any existing timer
    _batchTimer?.cancel();

    print('Starting batch timer for ${_batchDelay.inSeconds} seconds...');

    // Start new timer
    _batchTimer = Timer(_batchDelay, () {
      print('Batch timer expired - sending all motor states');
      sendBatchedMotorCommands();
    });
  }

  void sendMotorConfiguration() {
    if (client == null ||
        client!.connectionStatus!.state != MqttConnectionState.connected) {
      print('MQTT not connected, cannot send configuration');
      return;
    }

    Map<String, dynamic> configData = {};
    for (int i = 0; i < 5; i++) {
      configData['motor${i + 1}'] = motorConfigs[i].toJson();
    }

    String configJson = jsonEncode(configData);

    print('Sending motor configuration to $mqttConfigTopic:');
    print(configJson);

    final builder = MqttClientPayloadBuilder();
    builder.addString(configJson);

    client!.publishMessage(
      mqttConfigTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  // Handle Motor Toggle with Batch Timer
  Future<void> _handleMotorToggle(int motorIndex) async {
    if (motorConfigs[motorIndex].autoMode) {
      // Show confirmation dialog for auto-mode motors
      bool? shouldDisableAuto = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFF4A90E2),
            title: Text(
              'Disable Auto Mode?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'This motor is in auto mode. Do you want to disable auto mode and control it manually?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Disable Auto',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || _isShuttingDown) return;

      if (shouldDisableAuto == true) {
        _safeSetState(() {
          motorConfigs[motorIndex].autoMode = false;
        });
        sendMotorConfiguration();

        // Toggle motor state locally
        _safeSetState(() {
          motorStates[motorIndex] = !motorStates[motorIndex];
          if (motorStates[motorIndex]) {
            _motorControllers[motorIndex].forward();
          } else {
            _motorControllers[motorIndex].reverse();
          }
        });

        // Start/reset batch timer
        _startBatchTimer();
      }
    } else {
      // Normal manual toggle - update local state and start timer
      _safeSetState(() {
        motorStates[motorIndex] = !motorStates[motorIndex];
        if (motorStates[motorIndex]) {
          _motorControllers[motorIndex].forward();
        } else {
          _motorControllers[motorIndex].reverse();
        }
      });

      print(
        'Motor ${motorIndex + 1} toggled to: ${motorStates[motorIndex] ? "ON" : "OFF"}',
      );

      // Start/reset the batch timer
      _startBatchTimer();
    }
  }

  void _openMotorConfig() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MotorConfigScreen(
          motorConfigs: motorConfigs,
          onConfigSaved: (List<MotorConfig> updatedConfigs) {
            _safeSetState(() {
              motorConfigs = updatedConfigs;
              // Update motor names
              for (int i = 0; i < 5; i++) {
                motorNames[i] = motorConfigs[i].name;
              }
            });
            sendMotorConfiguration();
          },
        ),
      ),
    );
  }

  void onDisconnected() {
    _safeSetState(() {
      connectionStatus = "Disconnected";
    });
  }

  // Start auto-scroll timer for sensor carousel
  void _startSensorAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollDelay, (timer) {
      if (_sensorPageController.hasClients) {
        final nextPage = (_currentSensorPage + 1) % 3;
        _sensorPageController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Reset auto-scroll timer (called when user manually scrolls)
  void _resetSensorAutoScroll() {
    _startSensorAutoScroll();
  }

  void _logout() {
    _isShuttingDown = true;
    _batchTimer?.cancel();
    _autoScrollTimer?.cancel();
    _mqttUpdatesSubscription?.cancel();
    _mqttUpdatesSubscription = null;
    client?.autoReconnect = false;
    client?.disconnect();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  String getWaterQuality() {
    if (displayedTemperature >= 20 &&
        displayedTemperature <= 28 &&
        displayedPhLevel >= 6.5 &&
        displayedPhLevel <= 8.5 &&
        displayedDissolvedOxygen >= 5.0) {
      return "Excellent";
    } else if (displayedTemperature >= 15 &&
        displayedTemperature <= 32 &&
        displayedPhLevel >= 6.0 &&
        displayedPhLevel <= 9.0 &&
        displayedDissolvedOxygen >= 3.0) {
      return "Good";
    } else if (displayedDissolvedOxygen < 2.0 ||
        displayedPhLevel < 5.0 ||
        displayedPhLevel > 10.0) {
      return "Critical";
    } else {
      return "Fair";
    }
  }

  Color getWaterQualityColor() {
    switch (getWaterQuality()) {
      case "Excellent":
        return Colors.green;
      case "Good":
        return Colors.lightGreen;
      case "Fair":
        return Colors.orange;
      case "Critical":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color getTemperatureColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp <= 28) return Colors.green;
    if (temp <= 35) return Colors.orange;
    return Colors.red;
  }

  Color getPhColor(double ph) {
    if (ph < 6.0) return Colors.red;
    if (ph <= 6.5) return Colors.orange;
    if (ph <= 8.5) return Colors.green;
    if (ph <= 9.0) return Colors.orange;
    return Colors.red;
  }

  Color getOxygenColor(double oxygen) {
    if (oxygen < 2.0) return Colors.red;
    if (oxygen < 4.0) return Colors.orange;
    if (oxygen >= 5.0) return Colors.green;
    return Colors.lightGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                    AnimatedBuilder(
                      animation: _rotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * 0.5,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.cyan, Colors.blue],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.waves,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pond Monitoring System',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Device: $deviceId',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 10),
                    IconButton(
                      onPressed: _logout,
                      icon: Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: connectionStatus == "Connected"
                        ? _pulseAnimation.value
                        : 1.0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: connectionStatus == "Connected"
                              ? [Colors.green[400]!, Colors.green[600]!]
                              : [Colors.red[400]!, Colors.red[600]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (connectionStatus == "Connected"
                                        ? Colors.green
                                        : Colors.red)
                                    .withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            connectionStatus == "Connected"
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            connectionStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Water Quality Banner
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      getWaterQualityColor().withOpacity(0.8),
                      getWaterQualityColor(),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: getWaterQualityColor().withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.water_drop, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Water Quality: ${getWaterQuality()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Last: $lastUpdate',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Motor Control Panel
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: EdgeInsets.all(16),
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
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _openMotorConfig,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.cyan, Colors.blue],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Motor Controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        return Expanded(child: _buildMotorSwitch(index));
                      }),
                    ),
                  ],
                ),
              ),

              // Enhanced Sensor Visualizations - Carousel
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    children: [
                      // PageView for sensor cards
                      Expanded(
                        child: PageView(
                          controller: _sensorPageController,
                          onPageChanged: (index) {
                            _safeSetState(() {
                              _currentSensorPage = index;
                            });
                            // Reset auto-scroll timer when user manually scrolls
                            _resetSensorAutoScroll();
                          },
                          children: [
                            // Temperature Card
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: _buildThermometerWidget(),
                            ),
                            // pH Card
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: _buildPhScaleWidget(),
                            ),
                            // Oxygen Card
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: _buildOxygenGaugeWidget(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Page indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (index) => Container(
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            width: _currentSensorPage == index ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentSensorPage == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Info
              Container(
                padding: EdgeInsets.all(15),
                child: Text(
                  'Messages: $messagesReceived | ${motorStates.where((state) => state).length}/5 Motors Active',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced Thermometer Widget
  Widget _buildThermometerWidget() {
    return Container(
      padding: EdgeInsets.all(10),
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
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Temperature',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10),

          Expanded(
            child: CustomPaint(
              size: Size(60, double.infinity),
              painter: ThermometerPainter(
                temperature: displayedTemperature,
                animationValue: 1.0,
                color: getTemperatureColor(displayedTemperature),
              ),
            ),
          ),

          SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${displayedTemperature.toStringAsFixed(1)}°C',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Text(
            _getTemperatureStatus(displayedTemperature),
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Enhanced pH Scale Widget
  Widget _buildPhScaleWidget() {
    return Container(
      padding: EdgeInsets.all(10),
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
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'pH Level',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10),

          Expanded(
            child: CustomPaint(
              size: Size(double.infinity, 80),
              painter: PhScalePainter(
                phLevel: displayedPhLevel,
                animationValue: 1.0,
              ),
            ),
          ),

          SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayedPhLevel.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Text(
            _getPhStatus(displayedPhLevel),
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Enhanced Oxygen Gauge Widget
  Widget _buildOxygenGaugeWidget() {
    return Container(
      padding: EdgeInsets.all(10),
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
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Dissolved O₂',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10),

          Expanded(
            child: AnimatedBuilder(
              animation: _bubbleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(double.infinity, double.infinity),
                  painter: OxygenGaugePainter(
                    oxygenLevel: displayedDissolvedOxygen,
                    animationValue: 1.0,
                    bubbleAnimation: _bubbleAnimation.value,
                    color: getOxygenColor(displayedDissolvedOxygen),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${displayedDissolvedOxygen.toStringAsFixed(1)} mg/L',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Text(
            _getOxygenStatus(displayedDissolvedOxygen),
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Updated Motor switch widget with AUTO badge
  Widget _buildMotorSwitch(int index) {
    return GestureDetector(
      onTap: () => _handleMotorToggle(index),
      child: AnimatedBuilder(
        animation: _motorControllers[index],
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFB0BEC5),
                        Color(0xFF90A4AE),
                        Color(0xFF607D8B),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: Offset(1, 2),
                      ),
                      if (motorStates[index])
                        BoxShadow(
                          color: Colors.red.withOpacity(0.8),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: motorStates[index]
                                ? Colors.red.withOpacity(0.9)
                                : Colors.grey.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: motorStates[index]
                                  ? [
                                      Colors.red.withOpacity(0.8),
                                      Colors.red.withOpacity(0.4),
                                    ]
                                  : [
                                      Colors.grey.withOpacity(0.6),
                                      Colors.grey.withOpacity(0.2),
                                    ],
                            ),
                            boxShadow: [
                              if (motorStates[index])
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: Icon(
                            motorIcons[index],
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 5),

              Text(
                motorNames[index],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 3),

              // Status and AUTO badge
              Column(
                children: [
                  Text(
                    motorStates[index] ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: motorStates[index] ? Colors.red : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (motorConfigs[index].autoMode) ...[
                    SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AUTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper methods for status text
  String _getTemperatureStatus(double temp) {
    if (temp < 15) return 'Too Cold';
    if (temp <= 28) return 'Optimal';
    if (temp <= 35) return 'Warm';
    return 'Too Hot';
  }

  String _getPhStatus(double ph) {
    if (ph < 6.0) return 'Very Acidic';
    if (ph <= 6.5) return 'Acidic';
    if (ph <= 8.5) return 'Optimal';
    if (ph <= 9.0) return 'Basic';
    return 'Very Basic';
  }

  String _getOxygenStatus(double oxygen) {
    if (oxygen < 2.0) return 'Critical';
    if (oxygen < 4.0) return 'Low';
    if (oxygen >= 5.0) return 'Good';
    return 'Adequate';
  }

  @override
  void dispose() {
    _isShuttingDown = true;
    _mqttUpdatesSubscription?.cancel();
    _mqttUpdatesSubscription = null;

    _waveController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _temperatureController.dispose();
    _phController.dispose();
    _oxygenController.dispose();
    _bubbleController.dispose();
    for (var controller in _motorControllers) {
      controller.dispose();
    }

    // Cancel batch timer on dispose
    _batchTimer?.cancel();

    // Cancel auto-scroll timer and dispose PageController
    _autoScrollTimer?.cancel();
    _sensorPageController.dispose();

    client?.disconnect();
    super.dispose();
  }
}
