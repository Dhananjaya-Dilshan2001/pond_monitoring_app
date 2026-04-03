# Pond Monitoring System

A comprehensive Flutter application for real-time monitoring and control of aquaculture pond systems. This cross-platform solution provides sensor data visualization, automated motor controls, data logging, and historical analytics.

## 📱 Features

### Core Functionality
- **Real-Time Dashboard**: Live sensor data monitoring including water quality parameters
- **Motor Control**: Remote management of pond equipment and devices
- **Data Visualization**: Interactive graphs and charts for historical data analysis
- **Sensor Logging**: Comprehensive logging of all sensor readings and system events
- **Multi-Platform Support**: Runs on iOS, Android, Windows, macOS, Linux, and Web

### Technical Capabilities
- **MQTT Communication**: Real-time device communication via MQTT broker (EMQX)
- **Cloud Integration**: Firebase authentication and Firestore data storage
- **Secure Storage**: Local encrypted credential storage using Flutter Secure Storage
- **Responsive Design**: Adaptive UI using Flutter ScreenUtil for all screen sizes
- **Data Export**: CSV export functionality for data analysis and reporting
- **Device Preview**: Built-in device preview for testing across different screen sizes

## 🛠️ Technology Stack

### Framework & UI
- **Flutter**: Cross-platform mobile framework
- **Material Design**: UI components and design system
- **Flutter ScreenUtil**: Responsive design scaling
- **fl_chart**: Advanced charting and graphing library

### Backend & Data
- **Firebase**: Authentication and real-time database (Firestore)
- **MQTT**: Lightweight messaging for IoT device communication
- **HTTP**: RESTful API communication
- **Local Storage**: Flutter Secure Storage for credential management

### Development
- **Dart**: Primary programming language
- **DevicePreview**: Device preview for testing
- **CSV**: Data export capabilities
- **path_provider**: Cross-platform file access

## 📋 Prerequisites

- Flutter SDK: >= 3.4.0 < 4.0.0
- Dart SDK: Included with Flutter
- Android SDK (for Android builds)
- Xcode (for iOS/macOS builds)
- Firebase account for backend services
- MQTT broker access (default: broker.emqx.io)

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd pond_monitoring_system
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Set up Firebase project in [Firebase Console](https://console.firebase.google.com)
   - Download google-services.json (Android) and GoogleService-Info.plist (iOS)
   - Place files in their respective platform directories
   - Update `lib/firebase_options.dart` with your Firebase configuration

4. **Run the application**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: Android 5.0 (API 21)
- Uses gradle build system
- Requires proper signing configuration for production builds

#### iOS
- Minimum deployment target: iOS 11.0
- Requires CocoaPods for dependency management
- Configure provisioning profiles in Xcode

#### Desktop (Windows/macOS/Linux)
- Windows: Requires Windows 10 or later
- macOS: Requires macOS 10.11 or later
- Linux: Install required development libraries

## 📁 Project Structure

```
lib/
├── main.dart                 # Application entry point
├── firebase_options.dart     # Firebase configuration
├── core/
│   ├── api_service.dart      # API communication service
│   ├── app_sizes.dart        # Responsive size utilities
│   └── local_storage_service.dart  # Secure local storage
├── screen/
│   ├── dashboard_screen.dart # Main sensor dashboard
│   ├── graph_screen.dart     # Data visualization
│   └── logging_screen.dart   # System event logging
├── assets/
│   └── Images/               # App images and icons
```

## 🔧 Configuration

### MQTT Settings
- **Broker Host**: `broker.emqx.io`
- **Port**: `1883`
- **Topics**:
  - Data: `{deviceId}/data`
  - Commands: `{deviceId}/command`
  - Status: `{deviceId}/status`
  - Config: `{deviceId}/config`

### App Configuration
- **Design Size**: 375x812 (iPhone SE reference)
- **Orientation**: Portrait mode only
- **Theme**: Material Design Blue primary color
- **Font**: Plus Jakarta Sans

## 📊 Dashboard Features

### Sensor Monitoring
- Real-time sensor data display
- Water quality parameters
- Equipment status indicators
- Alert notifications

### Motor Controls
- Remote motor activation/deactivation
- Speed control
- Schedule management
- Emergency stop functionality

### Data Analytics
- Historical data visualization
- Trend analysis charts
- Peak/minimum value tracking
- Time-range filtering

## 📝 Logging System

- Complete event logging
- Sensor data recording
- Motor operation history
- Timestamp tracking
- Data export to CSV format

## 🔐 Security

- Firebase authentication for user verification
- Flutter Secure Storage for credentials
- Encrypted local data storage
- MQTT secure connections
- Device-specific access control

## 📲 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | API 21+ |
| iOS | ✅ Supported | iOS 11.0+ |
| Windows | ✅ Supported | Windows 10+ |
| macOS | ✅ Supported | macOS 10.11+ |
| Linux | ✅ Supported | Required libraries |
| Web | ✅ Supported | Desktop browser |

## 📦 Dependencies

### Production Dependencies
- `firebase_core: ^4.5.0` - Firebase initialization
- `cloud_firestore: ^6.1.3` - Cloud database
- `mqtt_client: ^10.11.9` - MQTT protocol
- `fl_chart: ^0.68.0` - Chart visualization
- `flutter_secure_storage: ^10.0.0` - Secure storage
- `http: ^1.2.1` - HTTP requests
- `flutter_screenutil: ^5.9.3` - Responsive UI
- `csv: ^6.0.0` - CSV export
- `path_provider: ^2.1.3` - File access
- `window_manager: ^0.5.1` - Desktop window management
- `device_preview: ^1.3.1` - Device preview

### Development Dependencies
- `flutter_test` - Testing framework
- `flutter_lints` - Linting rules
- `flutter_launcher_icons: ^0.14.4` - Icon generation

## 🔄 MQTT Communication

The app uses MQTT for real-time device communication:

```dart
// Connection settings
final String mqttHost = "broker.emqx.io";
final int mqttPort = 1883;

// Topic structure
mqttDataTopic = "$deviceId/data"
mqttCommandTopic = "$deviceId/command"
mqttStatusTopic = "$deviceId/status"
mqttConfigTopic = "$deviceId/config"
```

## 🎨 UI/UX Features

- **Responsive Design**: Adapts to all screen sizes
- **Device Preview**: Test across multiple devices
- **Material Design**: Consistent UI components
- **Landscape Support**: Windows and web platforms
- **Portrait Locked**: Mobile platforms (configurable)

## 🐛 Debugging

Enable DevicePreview for testing:
```dart
DevicePreview(
  enabled: true,  // Set to false in production
  builder: (context) => const MyApp()
)
```

## 📝 Build Instructions

### Debug Build
```bash
flutter run
```

### Release Build
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:
1. Create a feature branch (`git checkout -b feature/AmazingFeature`)
2. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
3. Push to the branch (`git push origin feature/AmazingFeature`)
4. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

## 🆘 Support & Troubleshooting

### Common Issues

**MQTT Connection Failed**
- Verify broker connectivity: `broker.emqx.io:1883`
- Check device ID format
- Ensure network connectivity

**Firebase Authentication Error**
- Verify Firebase configuration files
- Check internet connection
- Ensure device has system time synchronized

**UI Responsiveness Issues**
- Use ScreenUtil for responsive sizing
- Test on multiple device sizes using DevicePreview

## 📞 Contact & Support

For issues, feature requests, or support, please contact the development team.

## 🎯 Future Enhancements

- [ ] Offline mode with data sync
- [ ] Advanced analytics dashboard
- [ ] Mobile app notifications
- [ ] Predictive maintenance alerts
- [ ] Multi-pond management
- [ ] Custom alert configurations
- [ ] User roles and permissions
- [ ] Dark mode theme

---

**Version**: 1.0.0  
**Last Updated**: 2026  
**Status**: Active Development
