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
    int mode;   /* our operation modes: a) Authenticated Task b) NSTask emulation */
    
    int _processIdentifier; // NSTask mode
    int _terminationStatus;  //  NSTask mode
    NSTaskTerminationReason _terminationReason; // NSTask mode
}

@property (nullable) NSString *text;   /* authentication text */
@property (nullable) NSImage *icon;   /* authentication icon */
@property BOOL stayAuthorized;   /* ability to authorize only ONCE, but keep admin privileges for longer... */

// these methods can only be set before a launch
@property (nullable, copy, nonatomic, getter=launchPath, setter=setLaunchPath:) NSString *launchPath;
@property (nullable, copy, getter=executableURL, setter=setExecutableURL:) NSURL *executableURL;
@property (nullable, copy, getter=arguments, setter=setArguments:) NSArray<NSString *> *arguments;
@property (nullable, copy, getter=environment, setter=setEnvironment:) NSDictionary<NSString *, NSString *> *environment; // if not set, use current
@property (nullable, copy, getter=currentDirectoryURL, setter=setCurrentDirectoryURL:) NSURL *currentDirectoryURL;
@property (copy, getter=currentDirectoryPath, setter=setCurrentDirectoryPath:) NSString * _Nonnull currentDirectoryPath; // if not set, use current

// status
@property (readonly, getter=processIdentifier) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly, getter=terminationStatus) int terminationStatus;
@property (readonly, getter=terminationReason) NSTaskTerminationReason terminationReason;

@property (nullable, copy, getter=terminationHandler, setter=setTerminationHandler:) void (^terminationHandler)(NSTask *_Nonnull);
@property NSQualityOfService qualityOfService;

// standard I/O channels; could be either an NSFileHandle or an NSPipe
@property (nullable, retain, getter=standardInput, setter=setStandardInput:) id standardInput;
@property (nullable, retain, getter=standardOutput, setter=setStandardOutput:) id standardOutput;
@property (nullable, retain, getter=standardError, setter=setStandardError:) id standardError;

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

/**
 * Returns the task we bridge to
 */
- (NSTask *)task;

@end

#endif
