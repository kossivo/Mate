#!/bin/bash
set -e

# ==============================================================================
# Mate — Terminal Deployment CLI Tool
# Automates building, code signing, installing, and launching Mate on iOS
# ==============================================================================

PROJECT_NAME="Mate.xcodeproj"
SCHEME_NAME="Mate"
BUNDLE_ID="com.mate-hi.app"
DERIVED_DATA_PATH="DerivedData"

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}${BOLD}====================================================${NC}"
    echo -e "${CYAN}${BOLD}       🚀 MATE — TERMINAL DEPLOYMENT TOOL           ${NC}"
    echo -e "${BLUE}${BOLD}====================================================${NC}"
}

usage() {
    echo -e "${BOLD}Usage:${NC} ./scripts/deploy.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${GREEN}--sim${NC}                 Deploy to booted iOS Simulator (default)"
    echo -e "  ${GREEN}--device${NC}              Deploy to physical iPhone via USB/WiFi (xcrun devicectl)"
    echo -e "  ${GREEN}--device-id <UUID>${NC}    Deploy to specific physical device UUID"
    echo -e "  ${GREEN}--test${NC}                Run full automated test suite before deploying"
    echo -e "  ${GREEN}--clean${NC}               Clean build artifacts and DerivedData first"
    echo -e "  ${GREEN}--logs${NC}                Stream device/simulator logs after launch"
    echo -e "  ${GREEN}--help${NC}                Show this help guide"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ./scripts/deploy.sh                   # Fast deploy to iOS simulator"
    echo -e "  ./scripts/deploy.sh --device          # Deploy to plugged-in physical iPhone"
    echo -e "  ./scripts/deploy.sh --test --sim      # Run tests then deploy to simulator"
    echo ""
}

TARGET_MODE="sim"
RUN_TESTS=false
CLEAN_BUILD=false
STREAM_LOGS=false
SPECIFIC_DEVICE_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --sim)
            TARGET_MODE="sim"
            shift
            ;;
        --device)
            TARGET_MODE="device"
            shift
            ;;
        --device-id)
            TARGET_MODE="device"
            SPECIFIC_DEVICE_ID="$2"
            shift 2
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --logs)
            STREAM_LOGS=true
            shift
            ;;
        --help|-h)
            print_header
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

print_header

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"
    rm -rf "$DERIVED_DATA_PATH"
    swift package clean
    echo -e "${GREEN}✓ Clean completed.${NC}"
fi

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    echo -e "${YELLOW}🧪 Running full automated test suite (swift test)...${NC}"
    swift test
    echo -e "${GREEN}✓ All test suites passed!${NC}"
fi

# ------------------------------------------------------------------------------
# 1. DEPLOY TO SIMULATOR
# ------------------------------------------------------------------------------
if [ "$TARGET_MODE" = "sim" ]; then
    echo -e "${CYAN}📱 Finding booted iOS Simulator...${NC}"
    SIMULATOR_ID=$(xcrun simctl list devices booted -j | grep '"udid"' | head -n 1 | awk -F'"' '{print $4}')

    if [ -z "$SIMULATOR_ID" ]; then
        echo -e "${YELLOW}No booted simulator found. Booting default iPhone 17 Pro...${NC}"
        SIMULATOR_ID=$(xcrun simctl list devices available -j | grep -B 2 -A 5 '"name" : "iPhone 17 Pro"' | grep '"udid"' | head -n 1 | awk -F'"' '{print $4}')
        if [ -z "$SIMULATOR_ID" ]; then
            SIMULATOR_ID=$(xcrun simctl list devices available -j | grep '"udid"' | head -n 1 | awk -F'"' '{print $4}')
        fi
        xcrun simctl boot "$SIMULATOR_ID" || true
        open -a Simulator
    fi

    echo -e "${GREEN}Target Simulator ID:${NC} $SIMULATOR_ID"

    echo -e "${YELLOW}🔨 Building Mate for iOS Simulator...${NC}"
    xcodebuild -project "$PROJECT_NAME" \
               -scheme "$SCHEME_NAME" \
               -destination "id=$SIMULATOR_ID" \
               -derivedDataPath "$DERIVED_DATA_PATH" \
               build -quiet

    APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Mate.app"

    if [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}❌ Build failed: $APP_PATH not found!${NC}"
        exit 1
    fi

    echo -e "${YELLOW}📦 Installing $BUNDLE_ID onto Simulator...${NC}"
    xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

    echo -e "${YELLOW}🚀 Launching $BUNDLE_ID...${NC}"
    xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

    echo -e "${GREEN}${BOLD}🎉 SUCCESS: Mate is now running on the iOS Simulator!${NC}"

    if [ "$STREAM_LOGS" = true ]; then
        echo -e "${CYAN}📋 Streaming application logs (Ctrl+C to stop)...${NC}"
        xcrun simctl spawn "$SIMULATOR_ID" log stream --predicate "subsystem CONTAINS 'com.mate-hi.app' OR process == 'Mate'" --level debug
    fi

# ------------------------------------------------------------------------------
# 2. DEPLOY TO PHYSICAL DEVICE
# ------------------------------------------------------------------------------
elif [ "$TARGET_MODE" = "device" ]; then
    echo -e "${CYAN}🔌 Scanning for connected physical Apple devices...${NC}"

    if [ -z "$SPECIFIC_DEVICE_ID" ]; then
        # Query devicectl for available device
        DEVICE_UUID=$(xcrun devicectl list devices 2>&1 | grep "available" | head -n 1 | awk '{print $3}')
        if [ -z "$DEVICE_UUID" ]; then
            DEVICE_UUID=$(xcrun devicectl list devices 2>&1 | grep -E "iPhone|iPad" | head -n 1 | awk '{print $3}')
        fi
    else
        DEVICE_UUID="$SPECIFIC_DEVICE_ID"
    fi

    if [ -z "$DEVICE_UUID" ]; then
        echo -e "${RED}❌ No physical iPhone/iPad detected!${NC}"
        echo -e "Make sure your iPhone is connected via USB or Wi-Fi, unlocked, and 'Trust this computer' is approved."
        echo -e "Run ${BOLD}xcrun devicectl list devices${NC} to check device connection status."
        exit 1
    fi

    echo -e "${GREEN}Target Physical Device:${NC} $DEVICE_UUID"

    XCODE_DEST="$DEVICE_UUID"
    if [[ "$DEVICE_UUID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
        # When given a CoreDevice UUID (for devicectl), use generic/platform=iOS or physical UDID for xcodebuild
        XCODE_DEST="generic/platform=iOS"
    fi

    echo -e "${YELLOW}🔨 Building Mate for physical iOS Device (Debug)...${NC}"
    xcodebuild -project "$PROJECT_NAME" \
               -scheme "$SCHEME_NAME" \
               -destination "$XCODE_DEST" \
               -derivedDataPath "$DERIVED_DATA_PATH" \
               build -quiet

    APP_PATH=$(find "$DERIVED_DATA_PATH/Build/Products" -name "Mate.app" -type d | grep -v "simulator" | head -n 1)

    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}❌ Build output not found in $DERIVED_DATA_PATH!${NC}"
        exit 1
    fi

    echo -e "${YELLOW}📦 Installing onto physical device via xcrun devicectl...${NC}"
    xcrun devicectl device install app --device "$DEVICE_UUID" "$APP_PATH"

    echo -e "${YELLOW}🚀 Launching $BUNDLE_ID on device...${NC}"
    xcrun devicectl device process launch --device "$DEVICE_UUID" "$BUNDLE_ID" || true

    echo -e "${GREEN}${BOLD}🎉 SUCCESS: Mate is installed and running on your iPhone!${NC}"
fi
