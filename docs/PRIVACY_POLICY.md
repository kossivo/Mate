# Privacy Policy for Mate

**Effective Date:** November 25, 2026  
**Last Updated:** November 25, 2026  

At **Mate** ("we", "our", or "us"), your privacy is our foundational product principle. Mate is designed to be a **privacy-first personal productivity assistant**. We believe your thoughts, tasks, schedules, and calendar commitments belong exclusively to you.

---

## 1. Zero Knowledge & Local-First Processing
- **100% On-Device Processing**: All natural language processing, entity extraction, task parsing, and schedule calculations are performed entirely on your Apple device using native on-device intelligence and deterministic algorithms.
- **No External Servers**: Mate does not own, rent, or operate external servers, databases, or analytics infrastructure. Your data is never transmitted to us or any third-party AI provider (such as OpenAI, Google, or Anthropic).
- **No Account Required**: You do not need to register with an email, create a password, or sign in through third-party social accounts to use Mate.

---

## 2. Information We Access & How It Is Used
Mate requests access to native Apple device capabilities solely to provide core productivity functionality:

1. **Apple Calendar (`EventKit`)**:
   - *Purpose*: To inspect your calendar commitments in real-time, detect scheduling conflicts, and identify open focus slots.
   - *Storage*: Calendar titles, attendees, and meeting details are processed strictly in-memory on your device. Mate never stores external calendar events outside your device's native Calendar database.
   - *Approval*: Mate will never create, modify, or delete calendar events without your explicit review and confirmation.
2. **Apple Reminders (`EventKit`)**:
   - *Purpose*: To import or sync your tasks and mark them complete upon your instruction.
3. **Speech & Dictation**:
   - *Purpose*: For hands-free voice capture. Audio dictation is processed locally on-device by Apple's speech recognition engine.
4. **Siri & App Shortcuts (`AppIntents`)**:
   - *Purpose*: To allow you to capture thoughts, view your next commitment, and trigger daily planning using voice commands.

---

## 3. Data Synchronization & iCloud
If you choose to enable multi-device synchronization (across iPhone, iPad, and Mac), Mate utilizes **Apple's Private CloudKit Database** (`CKContainer.default().privateCloudDatabase`):
- Your data is stored within your personal, private iCloud container.
- All synchronization is end-to-end encrypted by Apple.
- We, the developers of Mate, have zero access to your iCloud container and cannot view, search, decrypt, or share your data.

---

## 4. In-App Purchases & Subscriptions
Mate uses Apple's official **StoreKit 2** framework for subscription handling:
- All transactions, renewals, and billing are processed directly by Apple through your Apple ID.
- We do not collect or store your payment details, credit card numbers, or billing addresses.
- Purchase entitlements are cryptographically verified on-device using Apple's signed JWS transaction receipts.

---

## 5. Third-Party Analytics & Tracking
- **Zero Third-Party SDKs**: Mate contains no third-party tracking libraries, advertising SDKs (e.g., Google AdMob, Meta Audience Network), or external telemetry tools (e.g., Firebase, Mixpanel).
- **No Tracking**: We do not track your activity across other companies' apps or websites.

---

## 6. Your Rights: Export & Deletion
You maintain complete control over your data:
- **Export**: You can export all your tasks, routines, and preferences in JSON format at any time directly in Mate's Settings.
- **Deletion**: You can reset your preferences or delete tasks directly within the app. Deleting the app removes all local data from your device.

---

## 7. Contact Us
If you have any questions or feedback regarding this Privacy Policy, you may contact us at:
- **Email**: privacy@mateapp.local (or your developer support email)
- **Website**: https://mateapp.local
