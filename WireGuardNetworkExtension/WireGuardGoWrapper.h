//
//  WireGuardGoWrapper.h
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 21-06-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

@interface WireGuardGoWrapper : NSObject

@property (nonatomic, weak) NEPacketTunnelFlow *packetFlow;
@property (nonatomic, assign) BOOL configured;

- (BOOL) turnOnWithInterfaceName: (NSString *)interfaceName settingsString: (NSString *)settingsString;
- (void) turnOff;

+ (NSString *)versionWireGuardGo;

@end
