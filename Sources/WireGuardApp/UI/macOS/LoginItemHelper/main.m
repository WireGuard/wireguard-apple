// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    NSString *appIdInfoDictionaryKey = @"com.wireguard.macos.app_id";
    NSString *appId = [NSBundle.mainBundle objectForInfoDictionaryKey:appIdInfoDictionaryKey];

    NSString *launchCode = @"LaunchedByWireGuardLoginItemHelper";
    NSAppleEventDescriptor *paramDescriptor = [NSAppleEventDescriptor descriptorWithString:launchCode];

    [NSWorkspace.sharedWorkspace launchAppWithBundleIdentifier:appId options:NSWorkspaceLaunchWithoutActivation
                                additionalEventParamDescriptor:paramDescriptor launchIdentifier:NULL];
    return 0;
}
