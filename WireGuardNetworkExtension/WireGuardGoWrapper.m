//
//  WireGuardGoWrapper.m
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 21-06-18.
//  Copyright © 2018 Wireguard. All rights reserved.
//

#import "WireGuardGoWrapper.h"

#include "wireguard.h"

/// Trampoline function
static ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len);
/// Trampoline function
static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len);

@interface WireGuardGoWrapper ()

@property (nonatomic, assign) int handle;
@property (nonatomic, assign) BOOL isClosed;

@end

@implementation WireGuardGoWrapper

- (void) turnOnWithInterfaceName: (NSString *)interfaceName settingsString: (NSString *)settingsString
{
    const char * ifName = [interfaceName UTF8String];
    const char * settings = [settingsString UTF8String];

    self.handle = wgTurnOn((gostring_t){ .p = ifName, .n = interfaceName.length }, (gostring_t){ .p = settings, .n = settingsString.length }, do_read, do_write, (__bridge void *)(self));
}

- (void) turnOff
{
    self.isClosed = YES;
    wgTurnOff(self.handle);
}

@end

static ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len)
{
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    printf("Reading from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
    sleep(1);
    return wrapper.isClosed ? -1 : 0;
}

static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len)
{
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    printf("Writing from instance with ctx %p into buffer %p of length %zu\n", ctx, buf, len);
    return len;
}
