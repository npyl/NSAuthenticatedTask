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

// these methods can only be set before a launch
@property (nullable, copy) NSString *launchPath;
@property (copy) NSString *currentDirectoryPath; // if not set, use current
@property (nullable, copy) NSURL *executableURL;
@property (nullable, copy) NSArray<NSString *> *arguments;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *environment; // if not set, use current
@property (nullable, copy) NSURL *currentDirectoryURL;

// standard I/O channels; could be either an NSFileHandle or an NSPipe
@property (nullable, retain) id standardInput;
@property (nullable, retain) id standardOutput;
@property (nullable, retain) id standardError;

- (void)interrupt; // Not always possible. Sends SIGINT.
- (void)terminate; // Not always possible. Sends SIGTERM.

- (BOOL)suspend;
- (BOOL)resume;

- (void)waitUntilExit;  // poll the runLoop in defaultMode until task completes

// status
@property (readonly) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly) int terminationStatus;
@property (readonly) NSTaskTerminationReason terminationReason;

@property (nullable, copy) void (^terminationHandler)(NSTask *);

- (void)launch;
- (void)launchAuthenticated;    /* our-addon */

@end
