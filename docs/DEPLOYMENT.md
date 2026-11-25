# Mate — Terminal Deployment Guide

This guide provides the exact terminal commands and scripts to build, test, install, and run **Mate** directly from your macOS terminal on either a **Physical iPhone** or an **iOS Simulator**.

---

## ⚡️ Quick Start: Automated Deployment Script

We have provided a turnkey deployment script located at `scripts/deploy.sh`.

```bash
# Make sure the script is executable (already set in repository)
chmod +x scripts/deploy.sh
```

### 1. Deploy to iOS Simulator
```bash
./scripts/deploy.sh
```
*(Auto-detects the booted simulator, compiles Mate, installs `com.mate-hi.app`, and brings it to the foreground).*

### 2. Deploy to Physical iPhone (USB or Wi-Fi)
```bash
./scripts/deploy.sh --device
```
*(Auto-detects your connected iPhone via `xcrun devicectl`, builds with your Apple Developer Team ID, installs, and launches).*

### 3. Run Automated Tests Before Deploying
```bash
./scripts/deploy.sh --test --sim
```

### 4. Clean Build & Deploy
```bash
./scripts/deploy.sh --clean --sim
```

### 5. Stream Live Device / Simulator Logs
```bash
./scripts/deploy.sh --sim --logs
```

---

## 🛠 Manual Terminal Commands (Step-by-Step)

If you prefer executing the underlying Apple command-line tools (`xcodebuild`, `xcrun simctl`, `xcrun devicectl`) directly:

### Option A: Physical iPhone (iOS 17 / iOS 18+)

#### Step 1: Find your connected iPhone's UUID
```bash
xcrun devicectl list devices
```
*Look for your iPhone in the output table (e.g., `1522EA9E-0EA4-50A5-9AF8-2F68966A7127` or `available`).*

#### Step 2: Build for the physical device
```bash
xcodebuild -project Mate.xcodeproj \
           -scheme Mate \
           -destination "generic/platform=iOS" \
           -derivedDataPath DerivedData \
           build
```
*(Or specify the device ID: `-destination "id=<YOUR_DEVICE_UUID>"`).*

#### Step 3: Install onto the iPhone
```bash
xcrun devicectl device install app \
  --device <YOUR_DEVICE_UUID> \
  DerivedData/Build/Products/Debug-iphoneos/Mate.app
```

#### Step 4: Launch the app
```bash
xcrun devicectl device process launch \
  --device <YOUR_DEVICE_UUID> \
  com.mate-hi.app
```

---

### Option B: iOS Simulator

#### Step 1: List or Boot Simulator
```bash
# Check booted simulator
xcrun simctl list devices booted

# Or boot iPhone 17 Pro
xcrun simctl boot "iPhone 17 Pro" || true
open -a Simulator
```

#### Step 2: Build for Simulator
```bash
xcodebuild -project Mate.xcodeproj \
           -scheme Mate \
           -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
           -derivedDataPath DerivedData \
           build
```

#### Step 3: Install and Launch
```bash
# Install app bundle
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/Mate.app

# Terminate existing instance (if any) and launch
xcrun simctl terminate booted com.mate-hi.app || true
xcrun simctl launch booted com.mate-hi.app
```

---

## 🧪 Testing & Verification from Terminal

Run the full automated test suite (20 tests covering Availability, Priority Scheduling, NLP Capture, StoreKit Entitlements, EventKit):

```bash
swift test
```

Inspect code signing identity and entitlements:
```bash
codesign -d --entitlements - DerivedData/Build/Products/Debug-iphonesimulator/Mate.app
```

Capture an immediate screenshot from the booted simulator:
```bash
xcrun simctl io booted screenshot docs/screenshots/latest_screen.png
```
