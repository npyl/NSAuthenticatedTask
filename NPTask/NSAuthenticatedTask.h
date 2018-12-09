//
//  NPTask.h
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#ifndef NSAUTHENTICATEDTASK_H
#define NSAUTHENTICATEDTASK_H

#import <xpc/xpc.h>
#import <Foundation/Foundation.h>

//! Project version number for NSAuthenticatedTask.
FOUNDATION_EXPORT double NSAuthenticatedTaskVersionNumber;

//! Project version string for NSAuthenticatedTask.
FOUNDATION_EXPORT const unsigned char NSAuthenticatedTaskVersionString[];

@interface NSAuthenticatedTask : NSObject
{
    BOOL _usesPipes;
    xpc_connection_t connection_handle;
}

@property (nullable) NSString *text;   /* authentication text */
@property (nullable) NSString *icon;   /* authentication icon */

// these methods can only be set before a launch
@property (nullable, copy) NSString *launchPath;
@property (nullable, copy) NSURL *executableURL;
@property (nullable, copy) NSArray<NSString *> *arguments;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *environment; // if not set, use current
@property (nullable, copy) NSURL *currentDirectoryURL;
@property (copy) NSString * _Nonnull currentDirectoryPath; // if not set, use current

// status
@property (readonly) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly) int terminationStatus;
@property (readonly) NSTaskTerminationReason terminationReason;

@property (nullable, copy) void (^terminationHandler)(NSTask *_Nonnull);
@property NSQualityOfService qualityOfService;

// standard I/O channels; could be either an NSFileHandle or an NSPipe
@property (nullable, retain) id standardInput;
@property (nullable, retain) id standardOutput;
@property (nullable, retain) id standardError;

- (void)interrupt; // Not always possible. Sends SIGINT.
- (void)terminate; // Not always possible. Sends SIGTERM.

- (BOOL)suspend;
- (BOOL)resume;

- (void)launchAuthenticated;

- (void)waitUntilExit;

@end

//+ (nullable NSTask *)launchedTaskWithExecutableURL:(NSURL *)url arguments:(NSArray<NSString *> *)arguments error:(out NSError ** _Nullable)error terminationHandler:(void (^_Nullable)(NSTask *))terminationHandler;

// actions
// (npyl): I don't like this...
//- (BOOL)launchAndReturnError:(out NSError **_Nullable)error;

#endif
