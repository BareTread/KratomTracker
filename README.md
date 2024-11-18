# Kratom Tracker

A comprehensive mobile application for tracking and analyzing your kratom usage, built with Flutter.

![Flutter Version](https://img.shields.io/badge/flutter-^3.5.4-blue.svg)
![Dart Version](https://img.shields.io/badge/dart-^3.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- 📊 Track daily kratom usage with detailed dosage logging
- 🌿 Manage multiple strains with custom colors and codes
- 📈 View usage statistics and trends
- 🔄 Smart strain recommendations based on effects
- 📱 Modern Material Design 3 UI
- 🌙 Dark mode support
- 💾 Backup and restore functionality
- 📅 Calendar view for historical data
- 📝 Note-taking for each dose
- ⏰ Optional dosage reminders

## Screenshots

[Consider adding screenshots of key screens here]

## Installation

1. **Prerequisites**
   - Flutter SDK (^3.5.4)
   - Dart SDK (^3.0.0)
   - Android Studio / Xcode

2. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/kratom_tracker.git
   cd kratom_tracker
   ```

3. **Install Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

## Dependencies

- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.2` - Local data storage
- `uuid: ^4.2.1` - Unique ID generation
- `intl: ^0.19.0` - Internationalization and formatting
- `table_calendar: ^3.0.9` - Calendar widget
- `share_plus: ^7.2.1` - Share functionality
- `file_picker: ^6.1.1` - File operations
- `fl_chart: ^0.66.2` - Statistical charts
- `lottie: ^2.7.0` - Animated assets

## Architecture

The app follows a clean architecture pattern with Provider for state management:
