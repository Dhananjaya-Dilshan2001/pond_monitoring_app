import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pond_monitoring_app/core/api_service.dart';
import 'package:pond_monitoring_app/core/app_sizes.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

// Conditional import for web
import 'package:universal_html/html.dart' as html show Blob, Url, AnchorElement;

class GraphScreen extends StatefulWidget {
  final String deviceId;

  const GraphScreen({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  String selectedFilter = 'all';
  List<Map<String, dynamic>> temperatureData = [];
  List<Map<String, dynamic>> dissolvedOxygenData = [];
  bool isLoading = true;
  Timer? _refreshTimer;

  final List<String> filterOptions = [
    'all',
    '1hour',
    '24hours',
    'week',
    'month',
  ];

  final List<String> filterDisplayNames = [
    'All',
    'Last hour',
    'Last 24 hours',
    'Last week',
    'Last month',
  ];

  String? selectedSaveLocation;
  final Map<String, String> saveLocations = {
    'Downloads': '/storage/emulated/0/Download',
    'Documents': '/storage/emulated/0/Documents',
    'DCIM': '/storage/emulated/0/DCIM',
    'App Private': '', // Will be set dynamically
  };

  @override
  void initState() {
    super.initState();
    fetchData();
    // Auto refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        fetchData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final tempData = await ApiService.fetchReadings(
        type: 'temperature',
        filter: selectedFilter,
        deviceId: widget.deviceId,
      );

      final doData = await ApiService.fetchReadings(
        type: 'do',
        filter: selectedFilter,
        deviceId: widget.deviceId,
      );

      if (mounted) {
        setState(() {
          temperatureData = tempData;
          dissolvedOxygenData = doData;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching graph data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != selectedFilter) {
      setState(() {
        selectedFilter = newFilter;
      });
      fetchData();
    }
  }

  Future<void> _showSaveLocationDialog() async {
    // Set the app private location dynamically
    if (Platform.isAndroid) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        saveLocations['App Private'] = appDir.path;
      } catch (e) {
        saveLocations['App Private'] = 'Not available';
      }
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF4A90E2),
          title: Text(
            'Choose Save Location',
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: saveLocations.entries.map((entry) {
              return ListTile(
                title: Text(
                  entry.key,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                ),
                subtitle: Text(
                  entry.value.isEmpty ? 'App private storage' : entry.value,
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
                onTap: () {
                  setState(() {
                    selectedSaveLocation =
                        entry.value.isEmpty ? null : entry.value;
                  });
                  Navigator.of(context).pop();
                  _downloadCSV();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadCSV() async {
    if (temperatureData.isEmpty && dissolvedOxygenData.isEmpty) {
      _showDialog('No Data', 'No data available to download.');
      return;
    }

    // Show progress dialog
    _showProgressDialog();

    try {
      // Step 1: Prepare data (20%)
      _updateProgress(0.2, 'Preparing data...');
      print('CSV Download: Preparing data...');

      // Generate CSV content
      final csvData = _generateCSV();
      print('CSV Download: Generated ${csvData.length} characters of CSV data');

      // Step 2: Create filename (40%)
      _updateProgress(0.4, 'Creating filename...');
      print('CSV Download: Creating filename...');

      final readableFilter = _getReadableFilterName(selectedFilter);
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = 'sensor_data_${readableFilter}_$timestamp.csv';
      print('CSV Download: Filename created: $filename');

      // Step 3: Processing file (60%)
      _updateProgress(0.6, 'Processing file...');
      print('CSV Download: Processing file...');

      // Step 4: Saving file (80%)
      _updateProgress(0.8, 'Saving file...');
      print('CSV Download: Saving file...');

      // Download the file (platform-specific implementation)
      await _downloadFile(csvData, filename);

      // Step 5: Complete (100%)
      _updateProgress(1.0, 'Complete! Tap OK to close.');
      print('CSV Download: Complete!');

      // For web, show success message here. For mobile, it's shown in _downloadFile
      if (kIsWeb) {
        _showDialog('Success',
            'CSV file downloaded successfully!\n\nFilename: $filename');
      }
    } catch (e) {
      // Close progress dialog and show error
      Navigator.of(context).pop(); // Close progress dialog
      print('CSV Download Error: ${e.toString()}');
      _showDialog('Error', 'Failed to process CSV: ${e.toString()}');
    }
  }

  String _getReadableFilterName(String filter) {
    switch (filter) {
      case 'all':
        return 'all';
      case '1hour':
        return 'last_hour';
      case '24hours':
        return 'last_24_hours';
      case 'week':
        return 'last_week';
      case 'month':
        return 'last_month';
      default:
        return filter;
    }
  }

  String _generateCSV() {
    final List<List<String>> csvRows = [];

    // Add header
    csvRows.add(['Timestamp', 'Device ID', 'Sensor Type', 'Value', 'Unit']);

    // Add temperature data
    for (final reading in temperatureData) {
      final parsed = DateTime.parse(reading['created_at']).toLocal();
      final timestamp = '${parsed.year.toString().padLeft(4, '0')}.'
          '${parsed.month.toString().padLeft(2, '0')}.'
          '${parsed.day.toString().padLeft(2, '0')} - '
          '${parsed.hour.toString().padLeft(2, '0')}.'
          '${parsed.minute.toString().padLeft(2, '0')}';
      final deviceId = reading['device_id'] ?? widget.deviceId;
      final value = (reading['value'] as num).toDouble().toStringAsFixed(2);
      csvRows.add([timestamp, deviceId, 'Temperature', value, '°C']);
    }

    // Add dissolved oxygen data
    for (final reading in dissolvedOxygenData) {
      final parsed = DateTime.parse(reading['created_at']).toLocal();
      final timestamp = '${parsed.year.toString().padLeft(4, '0')}.'
          '${parsed.month.toString().padLeft(2, '0')}.'
          '${parsed.day.toString().padLeft(2, '0')} - '
          '${parsed.hour.toString().padLeft(2, '0')}.'
          '${parsed.minute.toString().padLeft(2, '0')}';
      final deviceId = reading['device_id'] ?? widget.deviceId;
      final value = (reading['value'] as num).toDouble().toStringAsFixed(2);
      csvRows.add([timestamp, deviceId, 'Dissolved Oxygen', value, 'mg/L']);
    }

    // Sort by timestamp
    csvRows.sublist(1).sort((a, b) => a[0].compareTo(b[0]));

    // Convert to CSV string
    return const ListToCsvConverter().convert(csvRows);
  }

  Future<void> _downloadFile(String data, String filename) async {
    if (kIsWeb) {
      // Web implementation using universal_html
      try {
        final blob = html.Blob([data]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        throw Exception('Web download failed: ${e.toString()}');
      }
    } else {
      // Mobile implementation - save directly to storage
      try {
        print('Mobile Download: Starting file save process...');

        // Try different directory approaches for Android
        Directory? targetDir;

        if (Platform.isAndroid) {
          print('Mobile Download: Android platform detected');

          // Use user-selected location if available
          if (selectedSaveLocation != null &&
              selectedSaveLocation!.isNotEmpty) {
            targetDir = Directory(selectedSaveLocation!);
            print(
                'Mobile Download: Using user-selected location: ${targetDir.path}');
          } else {
            // Try public Downloads directory first (Android 10+ compatible)
            try {
              targetDir = Directory('/storage/emulated/0/Download');
              if (await targetDir.exists()) {
                print(
                    'Mobile Download: Public Downloads directory available: ${targetDir.path}');
              } else {
                print(
                    'Mobile Download: Public Downloads directory does not exist, will create it');
              }
            } catch (e) {
              print(
                  'Mobile Download: Cannot access public Downloads directory: $e');
              targetDir = null;
            }

            // Fallback: Try Downloads directory from path_provider
            if (targetDir == null) {
              try {
                targetDir = await getDownloadsDirectory();
                print(
                    'Mobile Download: Path provider Downloads directory: ${targetDir?.path}');
              } catch (e) {
                print('Mobile Download: Failed to get downloads directory: $e');
              }
            }

            // Fallback: Try external storage directory
            if (targetDir == null) {
              try {
                targetDir = await getExternalStorageDirectory();
                print('Mobile Download: External storage: ${targetDir?.path}');
              } catch (e) {
                print('Mobile Download: Failed to get external storage: $e');
              }
            }

            // Last fallback: Application documents directory
            if (targetDir == null) {
              try {
                targetDir = await getApplicationDocumentsDirectory();
                print('Mobile Download: App documents: ${targetDir?.path}');
              } catch (e) {
                print(
                    'Mobile Download: Failed to get app documents directory: $e');
              }
            }

            // Create a Downloads subdirectory if not already in Downloads
            if (targetDir != null && !targetDir.path.contains('Download')) {
              targetDir = Directory('${targetDir.path}/Download');
              print(
                  'Mobile Download: Using Download subdirectory: ${targetDir.path}');
            }
          }
        } else if (Platform.isIOS) {
          print('Mobile Download: iOS platform detected');
          targetDir = await getApplicationDocumentsDirectory();
          print('Mobile Download: App documents: ${targetDir?.path}');
        } else {
          // Fallback for other platforms
          print('Mobile Download: Other platform detected');
          targetDir = await getApplicationDocumentsDirectory();
          print('Mobile Download: App documents: ${targetDir?.path}');
        }

        if (targetDir == null) {
          print('Mobile Download: No target directory found');
          throw Exception('Could not access storage directory');
        }

        final file = File('${targetDir.path}/$filename');
        print('Mobile Download: File path: ${file.path}');

        // Ensure the directory exists
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
          print('Mobile Download: Created target directory');
        }

        // Write CSV data to file
        await file.writeAsString(data);
        print('Mobile Download: File written successfully');

        // Verify file was created
        if (await file.exists()) {
          final fileSize = await file.length();
          print('Mobile Download: File verified, size: $fileSize bytes');

          // Show success message with file path
          _showDialog('File Saved',
              'CSV file saved successfully!\n\nLocation: ${file.path}\n\nFilename: $filename');
        } else {
          print('Mobile Download: File verification failed');
          throw Exception('File was not created successfully');
        }
      } catch (e) {
        print('Mobile Download Error: ${e.toString()}');
        throw Exception('Failed to save file: ${e.toString()}');
      }
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF4A90E2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16.h),
              Text(
                'Generating CSV...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProgressDialog() {
    _progressValue = 0.0;
    _progressText = 'Starting...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Store the setState function for progress updates
            _progressSetState = setState;
            return AlertDialog(
              backgroundColor: Color(0xFF4A90E2),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 200.w,
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '${(_progressValue * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _progressText,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _progressValue >= 1.0
                      ? () {
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: _progressValue >= 1.0
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _progressValue = 0.0;
  String _progressText = 'Starting...';
  StateSetter? _progressSetState;

  void _updateProgress(double value, String text) {
    _progressValue = value;
    _progressText = text;
    // Update the progress dialog if it's showing
    _progressSetState?.call(() {});
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF4A90E2),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<FlSpot> _prepareChartData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];

    // Sort data by timestamp
    data.sort((a, b) {
      final aTime = DateTime.parse(a['created_at']).millisecondsSinceEpoch;
      final bTime = DateTime.parse(b['created_at']).millisecondsSinceEpoch;
      return aTime.compareTo(bTime);
    });

    final spots = <FlSpot>[];
    final startTime = DateTime.parse(data.first['created_at'])
        .millisecondsSinceEpoch
        .toDouble();

    for (final reading in data) {
      final timestamp = DateTime.parse(reading['created_at'])
          .millisecondsSinceEpoch
          .toDouble();
      final value = (reading['value'] as num).toDouble();
      final x = (timestamp - startTime) /
          (1000 * 60); // Convert to minutes from start
      spots.add(FlSpot(x, value));
    }

    return spots;
  }

  double _calculateXAxisInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;

    final spanMinutes = (spots.last.x - spots.first.x).abs();
    if (spanMinutes <= 0) return 1;

    // First, middle, last -> three x-axis labels.
    return spanMinutes / 2;
  }

  List<double> _getKeyXAxisValues(List<FlSpot> spots) {
    if (spots.isEmpty) return [];
    if (spots.length == 1) return [spots.first.x];
    if (spots.length == 2) return [spots.first.x, spots.last.x];

    final first = spots.first.x;
    final last = spots.last.x;
    final middle = spots[spots.length ~/ 2].x;

    return [first, middle, last];
  }

  String _formatXAxisLabel(
    double value,
    List<Map<String, dynamic>> rawData,
    String filter,
  ) {
    if (rawData.isEmpty) return '';

    final sorted = [...rawData]..sort((a, b) {
        final aTime = DateTime.parse(a['created_at']).millisecondsSinceEpoch;
        final bTime = DateTime.parse(b['created_at']).millisecondsSinceEpoch;
        return aTime.compareTo(bTime);
      });

    final startTime = DateTime.parse(sorted.first['created_at']).toLocal();
    final endTime = DateTime.parse(sorted.last['created_at']).toLocal();
    final spanMinutes = endTime.difference(startTime).inMinutes.abs();

    final pointTime = startTime.add(Duration(minutes: value.round()));
    final hh = pointTime.hour.toString().padLeft(2, '0');
    final mm = pointTime.minute.toString().padLeft(2, '0');
    final dd = pointTime.day.toString().padLeft(2, '0');
    final mon = pointTime.month.toString().padLeft(2, '0');

    switch (filter) {
      case '1hour':
      case '24hours':
        return '$hh:$mm';
      case 'week':
      case 'month':
        return '$dd/$mon';
      default:
        if (spanMinutes <= 1440) {
          return '$hh:$mm';
        }
        return '$dd/$mon';
    }
  }

  Map<String, dynamic> _getAxisLabels(String filter) {
    switch (filter) {
      case '1hour':
        return {
          'unit': 'HH:mm',
          'interval': 10.0, // Show every 10 minutes
        };
      case '24hours':
        return {
          'unit': 'HH:mm',
          'interval': 120.0, // Show every 2 hours
        };
      case 'week':
        return {
          'unit': 'dd/MM',
          'interval': 1440.0, // Show every day
        };
      case 'month':
        return {
          'unit': 'dd/MM',
          'interval': 4320.0, // Show every 3 days
        };
      default: // 'all'
        return {
          'unit': 'auto (HH:mm / dd/MM)',
          'interval': 240.0, // Show every 4 hours
        };
    }
  }

  Widget _buildChart({
    required String title,
    required List<Map<String, dynamic>> data,
    required Color color,
    required String unit,
  }) {
    final spots = _prepareChartData(data);
    final axisLabels = _getAxisLabels(selectedFilter);
    final xAxisInterval = _calculateXAxisInterval(spots);
    final keyXAxisValues = _getKeyXAxisValues(spots);

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 200.h,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 1,
                        verticalInterval:
                            spots.length > 10 ? spots.length / 10 : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.white.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.white.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: xAxisInterval,
                            getTitlesWidget: (value, meta) {
                              if (keyXAxisValues.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              final threshold = xAxisInterval / 3;
                              final nearestKey = keyXAxisValues.reduce(
                                (a, b) => (a - value).abs() <= (b - value).abs()
                                    ? a
                                    : b,
                              );

                              final shouldShow =
                                  (nearestKey - value).abs() <= threshold;

                              if (!shouldShow) {
                                return const SizedBox.shrink();
                              }

                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                fitInside:
                                    SideTitleFitInsideData.fromTitleMeta(meta),
                                child: Text(
                                  _formatXAxisLabel(
                                    nearestKey,
                                    data,
                                    selectedFilter,
                                  ),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      minX: spots.isNotEmpty ? spots.first.x : 0,
                      maxX: spots.isNotEmpty ? spots.last.x : 1,
                      minY: spots.isNotEmpty
                          ? spots
                                  .map((s) => s.y)
                                  .reduce((a, b) => a < b ? a : b) -
                              1
                          : 0,
                      maxY: spots.isNotEmpty
                          ? spots
                                  .map((s) => s.y)
                                  .reduce((a, b) => a > b ? a : b) +
                              1
                          : 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Time: ${axisLabels['unit']} | Value: $unit',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
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
                padding: EdgeInsets.all(20.w),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      'Sensor Graphs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    if (isLoading)
                      SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: _showSaveLocationDialog,
                        icon: Icon(Icons.download, color: Colors.white),
                        tooltip: 'Download CSV',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: EdgeInsets.all(12.w),
                        ),
                      ),
                  ],
                ),
              ),

              // Filter Dropdown
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: DropdownButton<String>(
                  value: selectedFilter,
                  onChanged: _onFilterChanged,
                  items: List.generate(filterOptions.length, (index) {
                    return DropdownMenuItem<String>(
                      value: filterOptions[index],
                      child: Text(
                        filterDisplayNames[index],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                    );
                  }),
                  dropdownColor: Color(0xFF4A90E2),
                  underline: SizedBox(),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                  isExpanded: true,
                ),
              ),

              // Charts
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildChart(
                        title: 'Temperature vs Time',
                        data: temperatureData,
                        color: Colors.orange,
                        unit: '°C',
                      ),
                      _buildChart(
                        title: 'Dissolved Oxygen vs Time',
                        data: dissolvedOxygenData,
                        color: Colors.blue,
                        unit: 'mg/L',
                      ),
                    ],
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
