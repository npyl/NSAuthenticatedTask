//
//  NPTask.h
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#ifndef NSAUTHENTICATEDTASK_H
#define NSAUTHENTICATEDTASK_H

#import <Cocoa/Cocoa.h>

//! Project version number for NSAuthenticatedTask.
FOUNDATION_EXPORT double NSAuthenticatedTaskVersionNumber;

//! Project version string for NSAuthenticatedTask.
FOUNDATION_EXPORT const unsigned char NSAuthenticatedTaskVersionString[];

/*
 * SESSION ID
 * 1:       no-session (create one)
 * -1:      failure
 * else:    SESSION ID
 */
typedef NSUInteger NSASession;

enum : NSASession {
    NSA_SESSION_FAIL = -1,  /* Indicate SESSION failure */
    NSA_SESSION_NEW = 1,    /* Create new SESSION */
};

@interface NSAuthenticatedTask : NSObject
{
    NSASession sessionID;
    BOOL _usesPipes;
    xpc_connection_t connection_handle;
    
    NSTask *tsk;    /* incase we are working in normal (NSTask) mode */
    BOOL usingNSTask;   /* set this to yes/no depending on whether ^^^^ happens */
}

@property (nullable) NSString *text;   /* authentication text */
@property (nullable) NSImage *icon;   /* authentication icon */
@property BOOL stayAuthorized;   /* ability to authorize only ONCE, but keep admin privileges for longer... */

// these methods can only be set before a launch
@property (nullable, copy, nonatomic, setter=setLaunchPath:) NSString *launchPath;
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

- (void)launch;
- (NSASession)launchAuthorized;
- (NSASession)launchAuthorizedWithSession:(NSASession)sessionID;

- (void)waitUntilExit;

/**
 * You should be able end a SESSION (aka. to quit the Helper) in order to save resources and ensure security.
 */
- (void)endSession:(NSASession)sessionID;
/**
 * End session with id, the session ID, this NSAuthenticatedTask is holding.
 */
- (void)endSession;

@end

#endif
