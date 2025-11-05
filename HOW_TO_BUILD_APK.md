# 🚀 How to Build & Test Your Beta APK

Your code is ready! The beta version will **install as a SEPARATE app** alongside your production version.

## 📱 What You'll Get

- **App Name on Phone**: "Herbal Tracker Beta"
- **Package ID**: `org.kratomtracker.app.beta` (different from production)
- **Version**: 1.1.0-beta
- **Result**: Both apps installed side-by-side for easy comparison!

---

## ⚡ FASTEST METHOD: GitHub Actions (Recommended)

GitHub will build the APK automatically in ~5 minutes.

### Step 1: Add the Workflow File (One-Time Setup)

Since I can't push workflow files directly, you need to add it manually:

1. **Go to your GitHub repo**: https://github.com/BareTread/KratomTracker

2. **Navigate to**: `.github/workflows/` folder
   - If the folder doesn't exist, create it

3. **Create new file**: Click "Add file" → "Create new file"

4. **Name it**: `build-apk.yml`

5. **Copy-paste the contents** from: `build-apk-workflow.yml` (in your repo root)

   Or copy this directly:
   ```yaml
   [See the file build-apk-workflow.yml in your repo]
   ```

6. **Commit directly to main branch**

### Step 2: Trigger the Build

**Option A - Automatically** (if you have a PR):
- The workflow will run automatically on your PR

**Option B - Manually**:
1. Go to: **Actions** tab on GitHub
2. Click: **"Build APK on PR"** workflow
3. Click: **"Run workflow"** button
4. Select branch: `claude/improve-app-features-011CUoibZq4DEDjVc3jjcQpD`
5. Click: **"Run workflow"**

### Step 3: Download Your APK

1. Wait ~5 minutes for the build to complete
2. Go to the **Actions** tab
3. Click on your workflow run
4. Scroll to bottom → **Artifacts** section
5. Download: `kratom-tracker-release-apk` (recommended)
   - Or `kratom-tracker-debug-apk` (faster to install, for quick testing)
   - Or `kratom-tracker-split-apks` (smaller files per architecture)

---

## 🔧 ALTERNATIVE: Local Build (Advanced)

If you have Flutter installed locally:

```bash
# Clone your PR branch
git clone https://github.com/BareTread/KratomTracker.git
cd KratomTracker
git checkout claude/improve-app-features-011CUoibZq4DEDjVc3jjcQpD

# Get dependencies
flutter pub get

# Build release APK (recommended for testing)
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 📲 Installing on Your Phone

### Enable Unknown Sources
1. Open **Settings** on Android
2. Go to **Security** or **Privacy**
3. Enable **"Install from unknown sources"** or **"Install unknown apps"**
4. Allow installation from your browser/file manager

### Install the APK
1. Transfer the APK to your phone (USB, email, cloud, etc.)
2. Tap the APK file
3. Tap **"Install"**
4. ✅ Done! Look for "Herbal Tracker Beta" in your app drawer

### Both Apps Side-by-Side
You'll now have:
- **Original app**: "Herbal Tracker" (org.kratomtracker.app)
- **Beta app**: "Herbal Tracker Beta" (org.kratomtracker.app.beta)

They have **separate data** - no conflicts!

---

## 🧪 Testing Checklist

Once installed, test these new features:

### 1. ✅ Smart Notifications
- Go to **Manage** tab
- Enable **Notifications**
- Set **Morning Reminder** (e.g., 8:00 AM)
- Set **Evening Reminder** (e.g., 8:00 PM)
- Set **Daily Limit** (try 5g for testing)
- Enable **Tolerance Tracking**
- Wait for scheduled time or add a dosage to test limit warnings

### 2. ✅ CSV Export
- Go to **Manage** tab
- Tap **"Export to CSV"**
- Try all 4 formats:
  - Basic Dosage Log
  - Detailed with Effects
  - Monthly Summary
  - Strain Analytics
- Share and open in Google Sheets/Excel

### 3. ✅ PDF Report
- Go to **Manage** tab
- Tap **"Generate PDF Report"**
- Select date range:
  - Last 7 Days
  - Last 30 Days
  - Last 90 Days
  - All Time
- View the professional PDF

### 4. ✅ Advanced Analytics
- Go to **Stats** tab
- Scroll to **"Advanced Analytics"** section
- Check:
  - Weekly Summary
  - Monthly Summary
  - Consecutive Usage Tracker (should show warning if ≥7 days)
  - Peak Usage Times Bar Chart

### 5. ✅ Tags System
- Add a new dosage
- Select tags: "With Food", "Morning", etc.
- Verify tags appear in dosage list

### 6. ✅ Duplicate Detection
- Add a dosage (e.g., "Green Strain" at 3g)
- Immediately try adding the SAME strain within 30 minutes
- Should see a notification/warning

### 7. ✅ Daily Limit Warnings
- Set daily limit to 5g (in Manage)
- Add dosages totaling 4g (80% of limit)
- Should see warning notification
- Add another 1.5g
- Should see limit exceeded alert

### 8. ✅ Strain Comparison
- (Advanced feature via provider methods)
- Multiple strains with different effects
- Check analytics to compare effectiveness

---

## 🐛 Troubleshooting

### Build Failed in GitHub Actions
- Check the error logs in the Actions tab
- Common issues:
  - Gradle sync errors (usually auto-resolves)
  - Dependency conflicts (update Flutter version in workflow)

### APK Won't Install
- Make sure "Unknown sources" is enabled
- Try uninstalling the beta version first
- Check Android version (requires Android 5.0+)

### Notifications Don't Work
- Android 13+ requires explicit permission
- Go to Android Settings → Apps → Herbal Tracker Beta → Notifications
- Enable all notification permissions

### Both Apps Share Data
- They shouldn't! They have different package IDs
- If they do, something went wrong with the build
- Uninstall beta and rebuild

---

## 📊 What Changed in This Version

### New Features (15 major additions):
1. **Smart Notifications** - Morning/evening reminders, daily limits, tolerance breaks
2. **CSV Export** - 4 specialized formats for data analysis
3. **PDF Reports** - Professional reports with customizable date ranges
4. **Advanced Analytics** - Weekly/monthly summaries, peak times, consecutive usage tracking
5. **Tags System** - Quick tags like "With Food", "Empty Stomach", custom tags
6. **Search & Filter** - Multi-criteria search by strain, date, tags
7. **Strain Comparison** - Side-by-side effectiveness analysis
8. **Duplicate Detection** - Prevents accidental double-logging
9. **Daily Limit Tracking** - Automatic warnings and alerts
10. **Tolerance Tracking** - Visual indicators and break reminders
11. **Peak Usage Analysis** - Interactive bar charts
12. **Consecutive Days Tracker** - Know your usage streak
13. **Tag Analytics** - Understand context patterns
14. **Data Validation** - Smart input checks
15. **Enhanced Manage Screen** - Complete redesign with all new features

### Technical Improvements:
- 5 new packages added (notifications, CSV, PDF, timezone)
- 12+ new analytics methods in provider
- 3 new service classes
- Enhanced UI/UX throughout
- Backward compatible - existing data works seamlessly

---

## 🎯 After Testing

Once you're satisfied with testing:

1. **Merge the PR** on GitHub
2. **Update the production app**:
   - Change `applicationId` back to `org.kratomtracker.app`
   - Change app name back to "Herbal Tracker"
   - Update version to `1.1.0` (remove -beta suffix)
3. **Build production APK**
4. **Distribute to users**

---

## 💡 Tips

- **Keep both apps** during testing to compare features
- **Test notifications** by setting reminders for a few minutes from now
- **Try the CSV export** to see your data in a spreadsheet
- **Generate a PDF report** to share with doctors or for records
- **Set a low daily limit** (like 3g) to test the warning system quickly
- **Use tags** to understand patterns (e.g., "With Food" vs "Empty Stomach")

---

## 🚀 Quick Start Commands

```bash
# For GitHub UI users (recommended):
1. Add workflow file via GitHub web interface
2. Go to Actions → Run workflow
3. Wait 5 minutes
4. Download APK from Artifacts

# For CLI users:
gh workflow run "Build APK on PR" --ref claude/improve-app-features-011CUoibZq4DEDjVc3jjcQpD

# For local builders:
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

**Questions?** Check the commit history or open an issue!

**Happy Testing!** 🎉
