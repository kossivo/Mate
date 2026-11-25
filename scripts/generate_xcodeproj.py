#!/usr/bin/env python3
import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

sources = [
    "Sources/MateApp/MateApp.swift",
    "Sources/MateCore/MateVersion.swift",
    "Sources/MateCore/Domain/Models.swift",
    "Sources/MateCore/Parser/DeterministicCaptureParser.swift",
    "Sources/MateCore/Scheduler/SmartSchedulingEngine.swift",
    "Sources/MateCore/StoreKit/StoreKitManager.swift",
    "Sources/MateCore/EventKit/EventKitManager.swift",
    "Sources/MateCore/Intents/MateIntents.swift",
    "Sources/MateCore/UI/Theme.swift",
    "Sources/MateCore/UI/TodayView.swift",
    "Sources/MateCore/UI/UniversalCaptureView.swift",
    "Sources/MateCore/UI/PlanView.swift",
    "Sources/MateCore/UI/SettingsView.swift",
    "Sources/MateCore/UI/PaywallView.swift",
    "Sources/MateCore/UI/MainTabView.swift",
    "Sources/MateCore/Widgets/MateWidgets.swift",
    "Sources/MateCore/Assistant/AvailabilityEngine.swift",
    "Sources/MateCore/Assistant/NotificationManager.swift",
    "Sources/MateCore/Assistant/DocumentScannerView.swift"
]

resources = [
    "Sources/MateApp/Assets.xcassets",
    "Sources/MateCore/Resources/PrivacyInfo.xcprivacy",
    "Sources/MateCore/Resources/en.lproj/Localizable.strings",
    "Sources/MateCore/Resources/vi.lproj/Localizable.strings",
    "Mate.storekit"
]

# Generate IDs
proj_id = "010000000000000000000001"
target_id = "020000000000000000000002"
sources_phase_id = "030000000000000000000003"
resources_phase_id = "040000000000000000000004"
frameworks_phase_id = "050000000000000000000005"
main_group_id = "060000000000000000000006"
products_group_id = "070000000000000000000007"
app_product_id = "080000000000000000000008"
proj_config_list_id = "090000000000000000000009"
target_config_list_id = "0A000000000000000000000A"
debug_proj_config_id = "0B000000000000000000000B"
release_proj_config_id = "0C000000000000000000000C"
debug_target_config_id = "0D000000000000000000000D"
release_target_config_id = "0E000000000000000000000E"

source_build_files = []
source_file_refs = []

for s in sources:
    fid = gen_id()
    bid = gen_id()
    name = os.path.basename(s)
    source_file_refs.append((fid, name, s))
    source_build_files.append((bid, fid, name))

resource_build_files = []
resource_file_refs = []

for r in resources:
    fid = gen_id()
    bid = gen_id()
    name = os.path.basename(r)
    resource_file_refs.append((fid, name, r))
    resource_build_files.append((bid, fid, name))

all_file_refs = source_file_refs + resource_file_refs
all_build_files = source_build_files + resource_build_files

pbx = []
pbx.append("// !$*UTF8*$!")
pbx.append("{")
pbx.append("\tarchiveVersion = 1;")
pbx.append("\tclasses = {")
pbx.append("\t};")
pbx.append("\tobjectVersion = 56;")
pbx.append("\tobjects = {")

# PBXBuildFile
pbx.append("/* Begin PBXBuildFile section */")
for bid, fid, name in source_build_files:
    pbx.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
for bid, fid, name in resource_build_files:
    pbx.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
pbx.append("/* End PBXBuildFile section */")

# PBXFileReference
pbx.append("/* Begin PBXFileReference section */")
pbx.append(f"\t\t{app_product_id} /* Mate.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Mate.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for fid, name, path in all_file_refs:
    ftype = "sourcecode.swift"
    if name.endswith(".xcassets"):
        ftype = "folder.assetcatalog"
    elif name.endswith(".xcprivacy"):
        ftype = "text.xml"
    elif name.endswith(".strings"):
        ftype = "text.plist.strings"
    elif name.endswith(".storekit"):
        ftype = "text.json"
    pbx.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{path}\"; sourceTree = \"<group>\"; }};")
pbx.append("/* End PBXFileReference section */")

# PBXFrameworksBuildPhase
pbx.append("/* Begin PBXFrameworksBuildPhase section */")
pbx.append(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
pbx.append("\t\t\tisa = PBXFrameworksBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXFrameworksBuildPhase section */")

# PBXGroup
pbx.append("/* Begin PBXGroup section */")
pbx.append(f"\t\t{main_group_id} = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
for fid, name, _ in all_file_refs:
    pbx.append(f"\t\t\t\t{fid} /* {name} */,")
pbx.append(f"\t\t\t\t{products_group_id} /* Products */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")

pbx.append(f"\t\t{products_group_id} /* Products */ = {{")
pbx.append("\t\t\tisa = PBXGroup;")
pbx.append("\t\t\tchildren = (")
pbx.append(f"\t\t\t\t{app_product_id} /* Mate.app */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = Products;")
pbx.append("\t\t\tsourceTree = \"<group>\";")
pbx.append("\t\t};")
pbx.append("/* End PBXGroup section */")

# PBXNativeTarget
pbx.append("/* Begin PBXNativeTarget section */")
pbx.append(f"\t\t{target_id} /* Mate */ = {{")
pbx.append("\t\t\tisa = PBXNativeTarget;")
pbx.append(f"\t\t\tbuildConfigurationList = {target_config_list_id} /* Build configuration list for PBXNativeTarget \"Mate\" */;")
pbx.append("\t\t\tbuildPhases = (")
pbx.append(f"\t\t\t\t{sources_phase_id} /* Sources */,")
pbx.append(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
pbx.append(f"\t\t\t\t{resources_phase_id} /* Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tbuildRules = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdependencies = (")
pbx.append("\t\t\t);")
pbx.append("\t\t\tname = Mate;")
pbx.append("\t\t\tproductName = Mate;")
pbx.append(f"\t\t\tproductReference = {app_product_id} /* Mate.app */;")
pbx.append("\t\t\tproductType = \"com.apple.product-type.application\";")
pbx.append("\t\t};")
pbx.append("/* End PBXNativeTarget section */")

# PBXProject
pbx.append("/* Begin PBXProject section */")
pbx.append(f"\t\t{proj_id} /* Project object */ = {{")
pbx.append("\t\t\tisa = PBXProject;")
pbx.append("\t\t\tattributes = {")
pbx.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
pbx.append("\t\t\t\tLastUpgradeCheck = 1600;")
pbx.append("\t\t\t\tTargetAttributes = {")
pbx.append(f"\t\t\t\t\t{target_id} = {{")
pbx.append("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
pbx.append("\t\t\t\t\t};")
pbx.append("\t\t\t\t};")
pbx.append("\t\t\t};")
pbx.append(f"\t\t\tbuildConfigurationList = {proj_config_list_id} /* Build configuration list for PBXProject \"Mate\" */;")
pbx.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
pbx.append("\t\t\tdevelopmentRegion = en;")
pbx.append("\t\t\thasScannedForEncodings = 0;")
pbx.append("\t\t\tknownRegions = (")
pbx.append("\t\t\t\ten,")
pbx.append("\t\t\t\tvi,")
pbx.append("\t\t\t\tBase,")
pbx.append("\t\t\t);")
pbx.append(f"\t\t\tmainGroup = {main_group_id};")
pbx.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
pbx.append("\t\t\tprojectDirPath = \"\";")
pbx.append("\t\t\tprojectRoot = \"\";")
pbx.append("\t\t\ttargets = (")
pbx.append(f"\t\t\t\t{target_id} /* Mate */,")
pbx.append("\t\t\t);")
pbx.append("\t\t};")
pbx.append("/* End PBXProject section */")

# PBXResourcesBuildPhase
pbx.append("/* Begin PBXResourcesBuildPhase section */")
pbx.append(f"\t\t{resources_phase_id} /* Resources */ = {{")
pbx.append("\t\t\tisa = PBXResourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for bid, _, name in resource_build_files:
    pbx.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXResourcesBuildPhase section */")

# PBXSourcesBuildPhase
pbx.append("/* Begin PBXSourcesBuildPhase section */")
pbx.append(f"\t\t{sources_phase_id} /* Sources */ = {{")
pbx.append("\t\t\tisa = PBXSourcesBuildPhase;")
pbx.append("\t\t\tbuildActionMask = 2147483647;")
pbx.append("\t\t\tfiles = (")
for bid, _, name in source_build_files:
    pbx.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
pbx.append("\t\t};")
pbx.append("/* End PBXSourcesBuildPhase section */")

# XCBuildConfiguration
pbx.append("/* Begin XCBuildConfiguration section */")
pbx.append(f"\t\t{debug_proj_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
pbx.append("\t\t\t\tENABLE_TESTABILITY = YES;")
pbx.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
pbx.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
pbx.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
pbx.append("\t\t\t\tSDKROOT = iphoneos;")
pbx.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";")
pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
pbx.append("\t\t\t};")
pbx.append("\t\t\tname = Debug;")
pbx.append("\t\t};")

pbx.append(f"\t\t{release_proj_config_id} /* Release */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {")
pbx.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
pbx.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
pbx.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
pbx.append("\t\t\t\tENABLE_NS_ASSERTIONS = NO;")
pbx.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;")
pbx.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
pbx.append("\t\t\t\tSDKROOT = iphoneos;")
pbx.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
pbx.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
pbx.append("\t\t\t};")
pbx.append("\t\t\tname = Release;")
pbx.append("\t\t};")

# Target build settings (where bundleID, Info.plist, and permissions live!)
common_target_settings = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Mate;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "Mate reads your calendar to find available focus time and adds your approved scheduled tasks.";
				INFOPLIST_KEY_NSRemindersFullAccessUsageDescription = "Mate accesses your reminders to organize and schedule your to-do items.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.mate.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

pbx.append(f"\t\t{debug_target_config_id} /* Debug */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {" + common_target_settings)
pbx.append("\t\t\t};")
pbx.append("\t\t\tname = Debug;")
pbx.append("\t\t};")

pbx.append(f"\t\t{release_target_config_id} /* Release */ = {{")
pbx.append("\t\t\tisa = XCBuildConfiguration;")
pbx.append("\t\t\tbuildSettings = {" + common_target_settings)
pbx.append("\t\t\t};")
pbx.append("\t\t\tname = Release;")
pbx.append("\t\t};")
pbx.append("/* End XCBuildConfiguration section */")

# XCConfigurationList
pbx.append("/* Begin XCConfigurationList section */")
pbx.append(f"\t\t{proj_config_list_id} /* Build configuration list for PBXProject \"Mate\" */ = {{")
pbx.append("\t\t\tisa = XCConfigurationList;")
pbx.append("\t\t\tbuildConfigurations = (")
pbx.append(f"\t\t\t\t{debug_proj_config_id} /* Debug */,")
pbx.append(f"\t\t\t\t{release_proj_config_id} /* Release */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
pbx.append("\t\t\tdefaultConfigurationName = Release;")
pbx.append("\t\t};")

pbx.append(f"\t\t{target_config_list_id} /* Build configuration list for PBXNativeTarget \"Mate\" */ = {{")
pbx.append("\t\t\tisa = XCConfigurationList;")
pbx.append("\t\t\tbuildConfigurations = (")
pbx.append(f"\t\t\t\t{debug_target_config_id} /* Debug */,")
pbx.append(f"\t\t\t\t{release_target_config_id} /* Release */,")
pbx.append("\t\t\t);")
pbx.append("\t\t\tdefaultConfigurationIsVisible = 0;")
pbx.append("\t\t\tdefaultConfigurationName = Release;")
pbx.append("\t\t};")
pbx.append("/* End XCConfigurationList section */")

pbx.append("\t};")
pbx.append(f"\trootObject = {proj_id} /* Project object */;")
pbx.append("}")

os.makedirs("Mate.xcodeproj", exist_ok=True)
with open("Mate.xcodeproj/project.pbxproj", "w") as f:
    f.write("\n".join(pbx))

print("Mate.xcodeproj generated successfully!")
