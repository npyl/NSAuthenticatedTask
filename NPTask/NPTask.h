//
//  NPTask.h
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for NPTask.
FOUNDATION_EXPORT double NPTaskVersionNumber;

//! Project version string for NPTask.
FOUNDATION_EXPORT const unsigned char NPTaskVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <NPTask/PublicHeader.h>

@interface NPTask : NSObject

- (void)launch;
- (void)launchAuthenticated;

@end
