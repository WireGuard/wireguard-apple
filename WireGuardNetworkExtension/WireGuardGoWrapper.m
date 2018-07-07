//
//  WireGuardGoWrapper.m
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 21-06-18.
//  Copyright © 2018 WireGuard. All rights reserved.
//

#import "WireGuardGoWrapper.h"

#include <os/log.h>
#include "wireguard.h"

/// Trampoline function
static ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len);
/// Trampoline function
static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len);
/// Trampoline function
static void do_log(int level, const char *tag, const char *msg);



@interface WireGuardGoWrapper ()

@property (nonatomic, assign) int handle;
@property (nonatomic, assign) BOOL isClosed;

@end

@implementation WireGuardGoWrapper

- (void) turnOnWithInterfaceName: (NSString *)interfaceName settingsString: (NSString *)settingsString
{

    wgSetLogger(do_log);

    const char * ifName = [interfaceName UTF8String];
    const char * settings = [settingsString UTF8String];

    self.handle = wgTurnOn((gostring_t){ .p = ifName, .n = interfaceName.length }, (gostring_t){ .p = settings, .n = settingsString.length }, do_read, do_write, (__bridge void *)(self));
}

- (void) turnOff
{
    self.isClosed = YES;
    wgTurnOff(self.handle);
}

+ (os_log_t)log {
    static os_log_t subLog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        subLog = os_log_create("com.wireguard.ios.WireGuard.WireGuardNetworkExtension", "WireGuard-Go");
    });

    return subLog;
}

@end

static ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len)
{
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    printf("Reading from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
    sleep(1);
    // TODO received data from tunnel, write to Packetflow
    return wrapper.isClosed ? -1 : 0;
}

static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len)
{
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    printf("Writing from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
    return len;
}

static void do_log(int level, const char *tag, const char *msg)
{
    // TODO Get some details on the log level and distribute to matching log levels.
    os_log([WireGuardGoWrapper log], "Log level %d for %s: %s", level, tag, msg);
}
