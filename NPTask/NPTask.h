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

@interface NSTask (NPTask)

@property NSString *icon;   /* authentication icon */

- (void)launchAuthenticated;    /* our-addon */

@end
