//
//  WireGuardGoWrapper.m
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 21-06-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

#include <os/log.h>

#include "wireguard.h"
#import "WireGuardGoWrapper.h"

/// Trampoline function
static ssize_t do_read(const void *ctx, const unsigned char *buf, size_t len);
/// Trampoline function
static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len);
/// Trampoline function
static void do_log(int level, const char *tag, const char *msg);



@interface WireGuardGoWrapper ()

@property (nonatomic, assign) int handle;
@property (nonatomic, assign) BOOL isClosed;
@property (nonatomic, strong) NSMutableArray<NSData *> *packets;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *protocols;

@property (nonatomic, strong) NSCondition *condition;

@end

@implementation WireGuardGoWrapper

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.handle = -1;
        self.configured = false;
        self.condition = [NSCondition new];
    }
    return self;
}

- (BOOL) turnOnWithInterfaceName: (NSString *)interfaceName settingsString: (NSString *)settingsString
{
    os_log([WireGuardGoWrapper log], "WireGuard Go Version %{public}s", wgVersion());

    wgSetLogger(do_log);

    const char * ifName = [interfaceName UTF8String];
    const char * settings = [settingsString UTF8String];

    self.handle = wgTurnOn((gostring_t){ .p = ifName, .n = interfaceName.length }, (gostring_t){ .p = settings, .n = settingsString.length }, do_read, do_write, (__bridge void *)(self));

    return self.handle >= 0;
}

- (void) turnOff
{
    self.isClosed = YES;
    self.configured = NO;
    wgTurnOff(self.handle);
    self.handle = -1;
}

+ (NSString *)versionWireGuardGo {
    return [NSString stringWithUTF8String:wgVersion()];
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
    if (wrapper.isClosed) return -1;

    if (wrapper.handle < 0 || !wrapper.configured ) {
//        os_log_debug([WireGuardGoWrapper log], "do_read - early - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);

        return 0;
    }

    if (wrapper.packets.count == 0) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [wrapper.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
                [wrapper.packets addObjectsFromArray:packets];
                [wrapper.protocols addObjectsFromArray:protocols];
                [wrapper.condition signal];
            }];
        });
        [wrapper.condition wait];
    }

    NSData *packet = [wrapper.packets objectAtIndex:0];
//    NSNumber *protocol = [wrapper.protocols objectAtIndex:0];
    [wrapper.packets removeObjectAtIndex:0];
    [wrapper.protocols removeObjectAtIndex:0];

    NSUInteger packetLength = [packet length];
    if (packetLength > len) {
        // The packet will be dropped when we end up here.
        return 0;
    }
    memcpy(buf, [packet bytes], packetLength);

    return packetLength;
}

static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len)
{
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    //TODO: determine IPv4 or IPv6 status.
    NSData *packet = [[NSData alloc] initWithBytes:buf length:len];
    [wrapper.packetFlow writePackets:@[packet] withProtocols:@[@AF_INET]];
    return len;
}

static void do_log(int level, const char *tag, const char *msg)
{
    // TODO Get some details on the log level and distribute to matching log levels.
    os_log([WireGuardGoWrapper log], "Log level %d for %{public}s: %{public}s", level, tag, msg);
}
