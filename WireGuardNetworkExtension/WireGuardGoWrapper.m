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
@property (nonatomic, strong) dispatch_queue_t dispatchQueue;

@property (nonatomic, strong) NSCondition *condition;

@end

@implementation WireGuardGoWrapper

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.packets = [[NSMutableArray alloc]initWithCapacity:100];
        self.handle = -1;
        self.configured = false;
        self.condition = [NSCondition new];
        self.dispatchQueue = dispatch_queue_create("manager", NULL);
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

- (void) startReadingPackets {
    [self readPackets];
}

- (void) readPackets {
    dispatch_async(self.dispatchQueue, ^{
        if (self.isClosed || self.handle < 0 || !self.configured ) {
            [self readPackets];
            return;
        }

        os_log_debug([WireGuardGoWrapper log], "readPackets - read call - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);

        [self.packetFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
            @synchronized(self.packets) {
                [self.packets addObjectsFromArray:packets];
                [self.protocols addObjectsFromArray:protocols];
            }
            os_log_debug([WireGuardGoWrapper log], "readPackets - signal - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);
            [self.condition signal];
            [self readPackets];
        }];
    });
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
//    os_log_debug([WireGuardGoWrapper log], "do_read - start - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);
    WireGuardGoWrapper *wrapper = (__bridge WireGuardGoWrapper *)ctx;
    if (wrapper.isClosed) return -1;

    if (wrapper.handle < 0 || !wrapper.configured ) {
//        os_log_debug([WireGuardGoWrapper log], "do_read - early - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);

        return 0;
    }


    NSData * __block packet = nil;
//    NSNumber *protocol = nil;
    dispatch_sync(wrapper.dispatchQueue, ^{
        @synchronized(wrapper.packets) {
            if (wrapper.packets.count == 0) {
                os_log_debug([WireGuardGoWrapper log], "do_read - no packet - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);

                return;
            }

            packet = [wrapper.packets objectAtIndex:0];
            //    protocol = [wrapper.protocols objectAtIndex:0];
            [wrapper.packets removeObjectAtIndex:0];
            [wrapper.protocols removeObjectAtIndex:0];
        }
    });

    if (packet == nil) {
        os_log_debug([WireGuardGoWrapper log], "do_read - wait - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);
        [wrapper.condition wait];
        return 0;
    }

    NSUInteger packetLength = [packet length];
    if (packetLength > len) {
        // The packet will be dropped when we end up here.
        os_log_debug([WireGuardGoWrapper log], "do_read - drop  - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);
        return 0;
    }
    memcpy(buf, [packet bytes], packetLength);
    os_log_debug([WireGuardGoWrapper log], "do_read - packet  - on thread \"%{public}@\" - %d", NSThread.currentThread.name, (int)NSThread.currentThread);
    return packetLength;
}

static ssize_t do_write(const void *ctx, const unsigned char *buf, size_t len)
{
    os_log_debug([WireGuardGoWrapper log], "do_write - start");

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
