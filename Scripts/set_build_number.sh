#!/bin/bash

git=$(sh /etc/profile; which git)
date=$(sh /etc/profile; which date)

number_of_commits=$("$git" rev-list HEAD --count)
date_timestamp=$("$date" +%Y%m%d)

target_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
echo $target_plist
dsym_plist="$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME/Contents/Info.plist"
echo $dsym_plist

for plist in "$target_plist" "$dsym_plist"; do
  if [ -f "$plist" ]; then
    echo $date_timestamp
    echo $plist
    echo $number_of_commits
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number_of_commits" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.0.$date_timestamp" "$plist"

  fi
done

settings_root_plist="$TARGET_BUILD_DIR/WireGuard.app/Settings.bundle/Root.plist"

if [ -f "$settings_root_plist" ]; then
  settingsVersion="`agvtool what-marketing-version -terse1`(${number_of_commits})"
  /usr/libexec/PlistBuddy -c "Set :PreferenceSpecifiers:1:DefaultValue $settingsVersion" "$settings_root_plist"
  /usr/libexec/PlistBuddy -c "Set :PreferenceSpecifiers:1:DefaultValue 0.0.$date_timestamp" "$settings_root_plist"
else
  echo "Could not find: $settings_root_plist"
  exit 1
fi

