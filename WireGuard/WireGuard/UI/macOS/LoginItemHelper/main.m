// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 WireGuard LLC. All Rights Reserved.

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    NSURL *bundleURL = [NSBundle.mainBundle bundleURL];

    // From <path>/WireGuard.app/Contents/Library/LoginItems/WireGuardLoginItemHelper.app, derive <path>/WireGuard.app
    for (int i = 0; i < 4; ++i)
        bundleURL = [bundleURL URLByDeletingLastPathComponent];

    [NSWorkspace.sharedWorkspace launchApplication:[bundleURL path]];
    return 0;
}
