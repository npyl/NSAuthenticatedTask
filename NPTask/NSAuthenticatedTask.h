//
//  NPTask.h
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#ifndef NPTASK_H
#define NPTASK_H

#import <Foundation/Foundation.h>

//! Project version number for NSAuthenticatedTask.
FOUNDATION_EXPORT double NSAuthenticatedTaskVersionNumber;

//! Project version string for NSAuthenticatedTask.
FOUNDATION_EXPORT const unsigned char NSAuthenticatedTaskVersionString[];

@interface NSAuthenticatedTask : NSObject

@property NSString *text;   /* authentication text */
@property NSString *icon;   /* authentication icon */

// these methods can only be set before a launch
@property (nullable, copy) NSURL *executableURL;
@property (nullable, copy) NSArray<NSString *> *arguments;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *environment; // if not set, use current
@property (nullable, copy) NSURL *currentDirectoryURL;

// standard I/O channels; could be either an NSFileHandle or an NSPipe
@property (nullable, retain) id standardInput;
@property (nullable, retain) id standardOutput;
@property (nullable, retain) id standardError;

// actions
- (BOOL)launchAndReturnError:(out NSError **_Nullable)error;

- (void)interrupt; // Not always possible. Sends SIGINT.
- (void)terminate; // Not always possible. Sends SIGTERM.

- (BOOL)suspend;
- (BOOL)resume;

// status
@property (readonly) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly) int terminationStatus;
@property (readonly) NSTaskTerminationReason terminationReason;

@property (nullable, copy) void (^terminationHandler)(NSTask *);
@property NSQualityOfService qualityOfService;

@end

@interface NSTask (NSTaskConveniences)

+ (nullable NSTask *)launchedTaskWithExecutableURL:(NSURL *)url arguments:(NSArray<NSString *> *)arguments error:(out NSError ** _Nullable)error terminationHandler:(void (^_Nullable)(NSTask *))terminationHandler API_AVAILABLE(macos(10.13)) API_UNAVAILABLE(ios, watchos, tvos);

- (void)waitUntilExit;
// poll the runLoop in defaultMode until task completes

@property (nullable, copy) NSString *launchPath;
@property (copy) NSString *currentDirectoryPath; // if not set, use current

- (void)launch;

- (void)launchAuthenticated;    /* our-addon */

@end

#endif
