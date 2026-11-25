# Privacy & Security Assessment

## 1. Core Privacy Tenets

Mate is engineered from the ground up under the principle of **Zero Knowledge, Zero Telemetry, and Maximum User Sovereignty**.

1. **No External Servers**: Mate operates entirely on the user's device. No data is ever sent to third-party AI APIs (OpenAI, Anthropic, Google Cloud) or analytics vendors.
2. **Private iCloud Storage Only**: If the user enables multi-device synchronization, data flows exclusively through Apple's end-to-end encrypted private CloudKit container (`CKContainer.default().privateCloudDatabase`). The app developer cannot view, inspect, or query user data.
3. **No Account Registration**: No email signups, no passwords, no OAuth third-party trackers.
4. **Transparent Calendar Ownership**: Mate reads calendar events strictly in-memory to detect scheduling gaps. Calendar event titles, attendees, and notes are never stored outside the system EventKit database.

---

## 2. Apple Privacy Manifest (`PrivacyInfo.xcprivacy`)

To comply with App Store Review Guideline 5.1.1 and Apple's mandatory Privacy Manifest requirement, Mate declares:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Explanations:
- `NSPrivacyTracking`: Set to `false`. Mate contains zero tracking code.
- `NSPrivacyCollectedDataTypes`: Empty. Mate collects zero user data.
- `NSPrivacyAccessedAPICategoryUserDefaults`: Used exclusively to persist local app preferences (`CA92.1`: Access to user defaults to read and write information that is only used by the app itself).

---

## 3. Permission & Entitlement Security Audit

| Permission / Entitlement | Purpose | Justification String | Risk Level |
|---|---|---|---|
| `NSCalendarsFullAccessUsageDescription` | Inspect busy slots and insert approved time blocks. | "Mate reads your calendar to find available focus time and adds your approved scheduled tasks." | Medium (Mitigated by zero cloud transmission & user confirmation on write) |
| `NSRemindersFullAccessUsageDescription` | Import and mark reminders complete. | "Mate accesses your reminders to organize and schedule your to-do items." | Medium |
| `iCloud (CloudKit)` | Sync user tasks and preferences across iPhone, iPad, and Mac. | Private iCloud database only. | Low |
| `App Groups` | Share schedule snapshots with Widgets and App Intents. | `group.com.mate.app` strictly on-device sandbox. | Low |
