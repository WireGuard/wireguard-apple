#!/bin/bash

sed=$(sh /etc/profile; which sed)
wireguard_go_version=$("$sed" -n 's/.*WireGuardGoVersion = "\(.*\)\".*/\1/p' wireguard-go/version.go)

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"

for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    echo $wireguard_go_version
    /usr/libexec/PlistBuddy -c "Set :WireGuardGoVersion $wireguard_go_version" "$plist"
  fi
done

settings_root_plist="$TARGET_BUILD_DIR/WireGuard.app/Settings.bundle/Root.plist"

if [ -f "$settings_root_plist" ]; then
  /usr/libexec/PlistBuddy -c "Set :PreferenceSpecifiers:2:DefaultValue $wireguard_go_version" "$settings_root_plist"
else
  echo "Could not find: $settings_root_plist"
  exit 1
fi
