# Changelog

All notable changes to Kratom Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-04

### 🎉 Major Feature Update - Enhanced Analytics & Smart Notifications

This release represents a significant upgrade to Kratom Tracker, adding highly requested features while maintaining the privacy-first, offline-only approach.

### ✨ Added

#### Smart Notifications System
- **Full notification implementation** with `flutter_local_notifications`
- **Morning & evening reminders** with customizable times via time picker
- **Daily limit tracking** with automatic warnings:
  - Warning at 80% of daily limit
  - Alert when daily limit exceeded
- **Tolerance break reminders** with configurable intervals (7-30+ days recommended)
- **Duplicate dosage detection** with automatic alerts
- All notifications respect user privacy (local only, no external services)
- Fully configurable or can be completely disabled

#### Advanced Analytics Engine
- **Peak usage time analysis** with 7 time slots (Early Morning, Morning, Late Morning, Afternoon, Late Afternoon, Evening, Night)
- **Weekly summary dashboard** showing:
  - Total dosages
  - Total amount consumed
  - Days active out of 7
  - Daily average
- **Monthly summary dashboard** with:
  - Total dosages and amounts
  - Days active vs total days in month
  - Daily average for active days
- **Consecutive usage tracking** with visual indicators
- **Strain effectiveness trends** over customizable time periods (30/60/90 days)
- **Interactive bar charts** showing usage patterns by time of day
- **Tag analytics** to identify common usage contexts

#### Export & Reporting Suite
- **CSV Export** with 4 specialized formats:
  1. **Basic Dosage Log** - Date, time, strain, amount, notes
  2. **Detailed Report** - Includes mood, energy, pain relief ratings
  3. **Monthly Summary** - Aggregated data grouped by month
  4. **Strain Analytics** - Effectiveness metrics per strain
- **Professional PDF Reports** with:
  - Cover page with user name and date range
  - Summary statistics with key metrics
  - Strain breakdown and analytics
  - Time pattern analysis
  - Detailed dosage log table
  - Customizable date ranges (7/30/90 days or all time)
- All exports shareable via any installed app

#### Tags System
- **Quick tags** for dosages: "With Food", "Empty Stomach", "Morning", "Evening", "Work", "Relaxation", "Exercise", "Social", "Pain Management", "Focus"
- **Custom tags support** for personalized tracking
- **Tag filtering** in search/filter system
- **Tag analytics** showing frequency of each tag
- Tags persist in JSON backups and CSV/PDF exports

#### Enhanced Search & Filter
- **Multi-criteria search**:
  - Search by strain name
  - Search by notes content
  - Filter by specific strain
  - Filter by date range
  - Filter by tags (single or multiple)
- **Combined filtering** for precise queries
- Real-time search results

#### Strain Comparison
- **Side-by-side strain comparison** showing:
  - Total uses
  - Total and average amount
  - Average mood, energy, and pain relief ratings
  - Effectiveness scores
- Compare up to multiple strains simultaneously
- Helps identify most effective strains for specific needs

#### Data Validation & Safety
- **Duplicate detection** within 30-minute window (configurable)
- **Daily limit validation** with real-time checks
- **Consecutive usage monitoring** for tolerance awareness
- **Input validation** for amounts and timestamps
- **Backup validation** to ensure data integrity

### 🔧 Enhanced

#### Provider (KratomProvider)
- Added `isPotentialDuplicate()` method for duplicate detection
- Added `getDailyTotal()` for quick daily consumption lookup
- Added `getConsecutiveUsageDays()` for tolerance tracking
- Added `searchDosages()` with comprehensive filtering
- Added `getPeakUsageTimes()` for usage pattern analysis
- Added `getWeeklySummary()` and `getMonthlySummary()` methods
- Added `compareStrains()` for multi-strain analysis
- Added `getEffectivenessTrends()` for temporal analysis
- Added `getAllTags()` and `getTagUsageCount()` for tag analytics
- Enhanced `addDosage()` to support tags and trigger validation checks
- Enhanced `updateDosage()` to support tag updates
- Automatic notification triggers on daily limit warnings

#### Models
- **Dosage model** updated to include `tags` field
- Added `Dosage.commonTags` constant for quick access
- Backward compatible JSON serialization (tags optional)

#### Screens
- **Manage Screen** completely redesigned with:
  - Expandable notification settings panel
  - Time pickers for morning/evening reminders
  - Daily limit input dialog
  - Tolerance break interval configuration
  - CSV export options menu
  - PDF report generation with date range selection
  - Improved visual hierarchy and organization
- **Stats Screen** enhanced with:
  - Advanced Analytics Card integration
  - Weekly/monthly summaries
  - Consecutive usage tracker with visual warnings
  - Interactive peak usage time charts
  - Better card organization

#### Services
- Created `NotificationService` with singleton pattern
- Created `CsvExportService` with multiple export formats
- Created `PdfExportService` with professional report generation
- All services maintain privacy-first approach (local only)

### 🎨 UI/UX Improvements
- **Advanced Analytics Card** widget with beautiful visualizations
- **Stat columns** with color-coded icons for quick comprehension
- **Warning indicators** for consecutive usage (changes color after 7 days)
- **Interactive time pickers** for notification scheduling
- **Better visual hierarchy** in settings with expandable sections
- **Improved card designs** throughout the app
- **Loading states** for async operations
- **Success/error dialogs** for all export operations

### 📚 Documentation
- Updated README with comprehensive feature list
- Added detailed feature descriptions with bold highlights
- Documented all new analytics capabilities
- Added notification system documentation
- Updated technology stack listing
- This CHANGELOG documenting all improvements

### 🔐 Security & Privacy
- All new features maintain offline-only operation
- No external API calls or data transmission
- Notifications processed locally
- CSV/PDF generation done on-device
- Tags and analytics computed locally

### 🛠️ Technical Improvements
- Added `intl` package import to provider for date formatting
- Proper error handling in all new services
- Async/await patterns for better performance
- Memory-efficient analytics calculations
- LRU cache optimization maintained
- Backward compatible data models

### 📦 Dependencies Added
- `flutter_local_notifications: ^18.0.1` - Local notification system
- `timezone: ^0.9.2` - Timezone support for scheduled notifications
- `csv: ^6.0.0` - CSV file generation
- `pdf: ^3.11.1` - PDF document creation
- `printing: ^5.13.3` - PDF sharing and printing

### 🐛 Bug Fixes
- Fixed potential null reference in strain analytics
- Improved error handling in backup/restore operations
- Better handling of empty states in analytics
- Fixed date comparison edge cases in filtering

### ♻️ Code Quality
- Separated concerns with dedicated service classes
- Consistent error handling patterns
- Improved code documentation
- Better widget composition
- Type-safe analytics calculations

### 🔄 Breaking Changes
None! All changes are backward compatible. Existing data will work seamlessly with the new features.

### 📈 Performance
- Optimized analytics calculations for large datasets
- Efficient duplicate detection algorithm
- Minimal memory overhead for new features
- Lazy loading of analytics data

---

## [1.0.0] - 2024-XX-XX

### Initial Release
- Basic dosage tracking
- Strain management
- Simple analytics
- Dark mode
- Local data storage
- JSON backup/restore

---

## Future Roadmap

### Planned Features (Community Requested)
- [ ] Custom effect tracking beyond mood/energy/pain
- [ ] Medication interaction warnings
- [ ] Photo attachments for strains
- [ ] Widget support for quick logging
- [ ] Batch import from CSV
- [ ] Multi-language support
- [ ] Cloud sync (optional, opt-in)
- [ ] Apple Health / Google Fit integration

### Under Consideration
- Effect correlation analysis (e.g., "With Food" increases effectiveness)
- Predictive analytics (suggest optimal dosage times)
- Customizable dashboard widgets
- Voice notes support
- Encrypted backups with password protection

---

**Note**: This project maintains a strict privacy-first philosophy. All features are designed to work offline without any external data transmission. Cloud features, if ever implemented, will always be optional and opt-in only.
