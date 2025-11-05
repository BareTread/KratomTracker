# Kratom Tracker

<div align="center">

![App Icon](assets/icon/app_icon.png)

A comprehensive mobile application for tracking and analyzing kratom usage, built with Flutter. Features detailed analytics, strain management, and a privacy-focused design.

[![Flutter Version](https://img.shields.io/badge/flutter-^3.5.4-blue.svg)](https://flutter.dev)
[![Dart Version](https://img.shields.io/badge/dart-^3.0.0-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/release/username/KratomTracker.svg)](https://github.com/BareTread/KratomTracker/releases)

[Features](#features) • [Screenshots](#screenshots) • [Installation](#installation) • [Privacy](#privacy) • [Contributing](#contributing)
</div>

## 📱 Screenshots
[Add 4-5 screenshots showing main features like timeline, strain management, analytics, etc.]

## 🌟 Features

### 📊 Dosage Tracking
- **Visual timeline** with precise timestamp recording
- **Custom notes and tags** for context ("With Food", "Empty Stomach", etc.)
- **Duplicate detection** to prevent accidental double-logging
- Multiple measurement units support
- Daily, weekly, and monthly consumption tracking
- Interactive timeline visualization with time-of-day periods
- **Daily limit tracking** with automatic warnings at 80% and alerts when exceeded

### 🌿 Strain Management
- Create and manage multiple strains
- Customizable strain colors (12 color variants) and icons (6 icon choices)
- **Strain effectiveness tracking** with detailed analytics
- **Strain comparison** - Compare effectiveness side-by-side
- **Optimal dosage recommendations** based on historical data
- Batch tracking support

### 📈 Analytics & Insights
- **Advanced usage pattern analysis** - Peak times, usage trends
- **Weekly/Monthly summaries** with comprehensive statistics
- **Consecutive usage tracking** with tolerance break recommendations
- **Strain effectiveness trends** over time
- **Interactive charts and graphs** (bar charts, usage patterns)
- Pattern recognition and insights
- **Tag analytics** to understand context patterns

### 🔔 Smart Notifications & Reminders
- **Customizable morning/evening reminders** for dosage logging
- **Daily limit warnings** (at 80% and when exceeded)
- **Tolerance break reminders** with configurable intervals
- **Duplicate dosage alerts** to prevent errors
- All notifications fully customizable or can be disabled

### 📤 Export & Reporting
- **CSV Export** with 4 formats:
  - Basic dosage log
  - Detailed with effects
  - Monthly summary
  - Strain analytics
- **Professional PDF Reports** with customizable date ranges
- **JSON Backup/Restore** for data portability
- Share exports via any app

### 🔒 Privacy-Focused
- **100% offline** - All data stored locally on device
- No cloud storage or external servers
- No tracking, analytics, or telemetry
- No account or sign-up required
- Easy data export for full data ownership

### 🎨 User Interface
- Material Design 3 with modern aesthetics
- **Full dark mode support** with optimized color schemes
- Custom color themes per strain
- Intuitive navigation with bottom nav bar
- Smooth animations and transitions
- Accessibility features

### 🔍 Search & Filter
- **Search dosages** by strain name, notes, or date
- **Filter by strain** to see usage patterns
- **Filter by date range** for specific periods
- **Filter by tags** to analyze context
- Combined filtering for precise queries

## 🛠️ Installation

### Download
- [Download APK](https://github.com/BareTread/KratomTracker/releases/download/1.0.0/app-release.apk)
- Play Store: Coming Soon!

### Build from Source
```bash
# Clone the repository
git clone https://github.com/username/KratomTracker.git

# Navigate to the project
cd KratomTracker

# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release
```

## 📱 Requirements
- Android 5.0 (API level 21) or higher
- 50MB of free storage
- No special permissions required

## 🏗️ Technical Details

### Architecture
```
lib/
├── models/         # Data models
├── providers/      # State management
├── screens/        # UI screens
├── widgets/        # Reusable components
├── constants/      # App constants
└── main.dart       # Entry point
```

### Technologies Used
- **Framework**: Flutter 3.5.4+
- **State Management**: Provider pattern
- **Local Storage**: SharedPreferences
- **Notifications**: flutter_local_notifications with timezone support
- **Charts**: fl_chart for interactive visualizations
- **Export**: CSV generation & PDF printing
- **UI**: Material Design 3
- **Animations**: Lottie
- **Calendar**: table_calendar
- **File Handling**: share_plus, file_picker, path_provider

## 🤝 Contributing

Contributions are welcome! Check out our [Contributing Guidelines](CONTRIBUTING.md) for details on how to:
- Report bugs
- Suggest features
- Submit pull requests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💙 Acknowledgments
- [provider](https://pub.dev/packages/provider) for state management
- [shared_preferences](https://pub.dev/packages/shared_preferences) for local storage
- [lottie](https://pub.dev/packages/lottie) for animations
- [table_calendar](https://pub.dev/packages/table_calendar) for calendar widget
- Full list in [pubspec.yaml](pubspec.yaml)

## 📞 Support

- Report issues on [GitHub Issues](https://github.com/BareTread/KratomTracker/issues)
- For support, reach out through [GitHub Discussions](link-to-discussions)

---

<div align="center">
Made with ❤️ by [Your Name]
</div>
