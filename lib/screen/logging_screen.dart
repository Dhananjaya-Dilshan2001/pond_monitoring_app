// Login Screen for Device Authentication
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pond_monitoring_app/core/app_sizes.dart';
import 'package:pond_monitoring_app/screen/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _deviceIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _validateDevice() async {
    if (_deviceIdController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both Device ID and Password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DocumentSnapshot deviceDoc = await FirebaseFirestore.instance
          .collection('Devices')
          .doc(_deviceIdController.text.trim())
          .get();

      log("Device Document: ${deviceDoc.data()}");

      if (!deviceDoc.exists) {
        setState(() {
          _errorMessage = 'Device ID not found';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> deviceData =
          deviceDoc.data() as Map<String, dynamic>;
      String storedPassword = deviceData['password'] ?? '';

      if (storedPassword != _passwordController.text.trim()) {
        setState(() {
          _errorMessage = 'Incorrect password';
          _isLoading = false;
        });
        return;
      }

      bool soldStatus = deviceData['sold_status'] ?? false;
      if (!soldStatus) {
        setState(() {
          _errorMessage = 'Device is not activated';
          _isLoading = false;
        });
        return;
      }
      FocusScope.of(context).unfocus();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PondDashboard(
            deviceId: _deviceIdController.text.trim(),
            deviceData: deviceData,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
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
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan, Colors.blue],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(Icons.waves, color: Colors.white, size: 48),
                  ),
                  SizedBox(height: 40),
                  Text(
                    'Pond Monitoring System',
                    style: context.textStyles.h1.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Connect to Your Device',
                    style: context.textStyles.title.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 40),
                  Container(
                    padding: EdgeInsets.all(32),
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
                        TextField(
                          controller: _deviceIdController,
                          style: context.textStyles.input.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Device ID',
                            labelStyle: context.textStyles.inputLabel,
                            hintText: 'Enter your device ID (e.g., DEVICE_001)',
                            hintStyle: context.textStyles.inputHint,
                            prefixIcon: Icon(
                              Icons.devices,
                              color: Colors.white70,
                            ),
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
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: context.textStyles.input.copyWith(
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: context.textStyles.inputLabel,
                            hintText: 'Enter device password',
                            hintStyle: context.textStyles.inputHint,
                            prefixIcon: Icon(Icons.lock, color: Colors.white70),
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
                        ),
                        SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _validateDevice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Connect to Device',
                                    style: context.textStyles.button.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        if (_errorMessage.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: context.textStyles.body.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
