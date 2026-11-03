#!/bin/zsh
set -eu
cd "$(dirname "$0")"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
release_metadata="$(python3 -c 'import re;from pathlib import Path;v=Path("VERSION").read_text().strip();assert re.fullmatch(r"0\.\d+",v),"Invalid VERSION";print(v,v.split(".")[1])')"
read -r release_version release_number <<< "$release_metadata"
platform="${1:-mac}"
build_root="${DEADOPS_BUILD_ROOT:-Build}"
case "$platform" in
 mac) sdk=macosx; target=arm64-apple-macosx14.0; app="$build_root/Mac/DeadOpsReconstruction.app"; executable="$app/Contents/MacOS/DeadOpsReconstruction"; plist="$app/Contents/Info.plist"; family=1; min_key=LSMinimumSystemVersion; min_value=14.0 ;;
 tv-simulator) sdk=appletvsimulator; target=arm64-apple-tvos18.0-simulator; app="$build_root/AppleTV-Simulator/DeadOpsReconstruction.app"; executable="$app/DeadOpsReconstruction"; plist="$app/Info.plist"; family=3; min_key=MinimumOSVersion; min_value=18.0 ;;
 tv-device) sdk=appletvos; target=arm64-apple-tvos18.0; app="$build_root/AppleTV-Device/DeadOpsReconstruction.app"; executable="$app/DeadOpsReconstruction"; plist="$app/Info.plist"; family=3; min_key=MinimumOSVersion; min_value=18.0 ;;
 *) print "Nutzung: ./build.sh mac | tv-simulator | tv-device";exit 1 ;;
esac
module_cache="${TMPDIR:-/tmp}/DeadOpsReconstruction-module-cache"
icon_entry=""
if [[ "$platform" == mac ]]; then
 icon_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' Config/Info-mac.plist)
 icon_entry="<key>CFBundleIconFile</key><string>$icon_name</string>"
fi
mkdir -p "$(dirname "$executable")" "$module_cache"
xcrun --sdk "$sdk" swiftc -O -swift-version 5 -module-cache-path "$module_cache" -sdk "$(xcrun --sdk "$sdk" --show-sdk-path)" -target "$target" Sources/*.swift -o "$executable"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>de</string>
<key>CFBundleExecutable</key><string>DeadOpsReconstruction</string>
<key>CFBundleIdentifier</key><string>local.nick.arcade.deadopsreconstruction</string>
<key>CFBundleName</key><string>DeadOpsReconstruction</string>
<key>CFBundleDisplayName</key><string>Dead Ops Rekonstruktion</string>
<key>CFBundlePackageType</key><string>APPL</string>
$icon_entry
<key>LSApplicationCategoryType</key><string>public.app-category.action-games</string>
<key>CFBundleShortVersionString</key><string>$release_version</string>
<key>CFBundleVersion</key><string>$release_number</string>
<key>$min_key</key><string>$min_value</string>
<key>NSHighResolutionCapable</key><true/>
<key>UIDeviceFamily</key><array><integer>$family</integer></array>
<key>GCSupportedGameControllers</key><array><dict><key>ProfileName</key><string>ExtendedGamepad</string></dict></array>
<key>GCSupportsControllerUserInteraction</key><true/>
</dict></plist>
PLIST
if [[ "$platform" == mac ]]; then resource_dir="$app/Contents/Resources"; else resource_dir="$app"; fi
mkdir -p "$resource_dir/Assets"
cp Assets/*.png "$resource_dir/Assets/"
if [[ "$platform" == mac ]]; then cp "Assets/$icon_name.icns" "$resource_dir/"; fi
if [[ -d "$resource_dir/Music" ]]; then rm -rf "$resource_dir/Music"; fi
# Optional user-supplied music for native/tvOS builds; no files are downloaded.
if [[ -d Assets/Music ]]; then
 mkdir -p "$resource_dir/Music"
 for music_file in Assets/Music/*(N.); do
  case "${music_file:e:l}" in wav|mp3|m4a|aif|aiff|caf) cp "$music_file" "$resource_dir/Music/" ;; esac
 done
fi
if [[ "$platform" == mac ]]; then codesign --force --sign - "$app"; fi
print "Erstellt: $app"
