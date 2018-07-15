//
//  WireGuardGoWrapper.h
//  WireGuardNetworkExtension
//
//  Created by Jeroen Leenarts on 21-06-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WireGuardGoWrapper : NSObject

- (void) turnOnWithInterfaceName: (NSString *)interfaceName settingsString: (NSString *)settingsString;
- (void) turnOff;

@end
