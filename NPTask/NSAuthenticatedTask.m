//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NSAuthenticatedTask.h"

#import <syslog.h>
#import "../Shared.h"
#import <Cocoa/Cocoa.h>

@implementation NSAuthenticatedTask

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        /*
         * Get current working directory (PWD)
         */
        char cwd[PATH_MAX];
        if (getcwd(cwd, sizeof(cwd)) == NULL)
            return nil;
        
        _stayAuthorized = NO;
        _usesPipes = NO;
        _icon = nil;
        _currentDirectoryPath = [NSString stringWithUTF8String:cwd];
        _environment = [[NSProcessInfo processInfo] environment];
        _terminationHandler = ^(NSTask *tsk) {};
        _terminationStatus = 1; // !0 = error
    }
    return self;
}

- (void)setLaunchPath:(NSString *)launchPath
{
    _launchPath = launchPath;
    
    /* Get Icon for File */
    _icon = [self GetImageForFile:_launchPath];
}

/**
 * GetImageForFile
 *
 * Automatically find
 */
- (NSImage *)GetImageForFile:(NSString *)file
{
    NSImage *image = nil;
    
    NSString *bundlePath = [[[file stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
  
    CFStringRef fileExtension = (__bridge CFStringRef) [file pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, fileExtension, NULL);
    
    if (UTTypeConformsTo(fileUTI, kUTTypeBundle))
    {
        image = [[NSWorkspace sharedWorkspace] iconForFile:bundlePath];
    }
    else
    {
        image = [[NSWorkspace sharedWorkspace] iconForFile:file];
    }
    
    CFRelease(fileUTI);

    return image;
}

/**
 * GetIconLocation
 *
 * Convert an NSImage to PNG and save it;
 * Return the path to the icon.
 */
- (NSString *)GetIconLocation:(NSImage *)image
{
    /* Generate a random path in /tmp/NPTask/icons */
    int r = arc4random_uniform(10000000);
    NSString *tmpdir = @"/tmp/NPTask/icons";
    NSString *format = @"%@/%llu.png";
    NSString *path = [NSString stringWithFormat:format, tmpdir, r];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpdir withIntermediateDirectories:YES attributes:nil error:&error];
    
    CGImageRef cgRef = [image CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    /* I want the same resolution */
    [newRep setSize:[image size]];
    NSData *pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [pngData writeToFile:path atomically:YES];
    
    return path;
}

/**
 * connection_for_session
 *
 * Return a proper connection handle;
 * Existing for an already-created valid SESSION OR
 * new if passed `sessionID' is `NSA_NEW_SESSION'.
 */
- (xpc_connection_t)connection_for_session:(NSASession)sessionID
{
    NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)sessionID];
    
    switch (sessionID)
    {
//        /* sessionID has become/is invalid */
//        case (-1):
//            return nil;
        /* connection handle for new SESSION */
        case NSA_NEW_SESSION:
            return xpc_connection_create_mach_service(HELPER_IDENTIFIER, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        /* connection handle for valid existing SESSION */
        default:
            return (xpc_connection_t)[[NSUserDefaults standardUserDefaults] objectForKey:key];
    }
}

- (void)launch
{
    usingNSTask = YES;
    
    /*
     * Bridge everything we got to NSTask! :)
     */
    
    tsk = [[NSTask alloc] init];
    tsk.launchPath = _launchPath;
    tsk.currentDirectoryPath = _currentDirectoryPath;
    tsk.environment = _environment;
    tsk.arguments = _arguments;
    
    if (_usesPipes)
    {
        tsk.standardInput = _standardInput;
        tsk.standardOutput = _standardOutput;
        tsk.standardError = _standardError;
    }

    // XXX probably have to make NSAuthTask's standardXXX return tsk's standardXXX instead if usingNSTask is true...
    // XXX a story for next time...
    
    [tsk setTerminationHandler:^(NSTask * _Nonnull _tsk) {
        self->_terminationHandler(_tsk);

        self->_running = NO;
        self->usingNSTask = NO;
    }];
    
    [tsk launch];
    _running = YES;
}

- (NSASession)launchAuthorized
{
    return [self launchAuthorizedWithSession:NSA_NEW_SESSION];
}

- (NSASession)launchAuthorizedWithSession:(NSASession)passedSessionID
{
    sessionID = -1; /* clear & re-initialise sessionID */
    static BOOL calledFirstTime = YES;
    BOOL isSessionNew = (passedSessionID == NSA_NEW_SESSION);

    /*
     * Generate a SESSION ID
     */
    if (isSessionNew)
    {
        sessionID = arc4random_uniform(10000000);
    }
    
    if (!_launchPath)
    {
        [NSException raise:@"launchPath cannot be nil" format:@""];
        return (-1);
    }
    
    if (_standardInput || _standardOutput || _standardError)
        _usesPipes = YES;
    
    /*
     * Call NPAuthenticator to authenticate ONLY ONCE
     * if `_stayAuthorized' is set by user or if new SESSION.
     */
    if ((_stayAuthorized && calledFirstTime) || isSessionNew)
    {
        NSString *_executableName = [_launchPath lastPathComponent];
        
        /*
         * Call the NPAuthenticator
         */
        NSBundle *thisFramework = [NSBundle bundleWithIdentifier:@"npyl.NPTask"];
        NSBundle *NPAuthBundle = [NSBundle bundleWithPath:[thisFramework pathForResource:@"NPAuthenticator" ofType:@"app"]];
        NSString *NPAuthenticatorPath = [NPAuthBundle executablePath];
        NSMutableArray *args = [NSMutableArray arrayWithObject:_executableName];
        
        if (_icon)
        {
            NSString *_iconLocation = [self GetIconLocation:_icon];
            [args addObject:_iconLocation];
        }
        
        /*
         * Call NPAuthenticator using the following format for the
         * authentication box to have a custom icon and text...
         *              EXECUTABLE          ARG0                    ARG1
         * .../.../.../NPAuthenticator      $EXECUTABLE_NAME        $ICON
         */
        NSTask *NPAuthenticator = [[NSTask alloc] init];
        NPAuthenticator.launchPath = NPAuthenticatorPath;
        NPAuthenticator.arguments = args;
        [NPAuthenticator launch];
        [NPAuthenticator waitUntilExit];
        
        if ([NPAuthenticator terminationStatus] != 0)
        {
            syslog(LOG_NOTICE, "Authentication failed!");
            return (-1);
        }
    }
    
    calledFirstTime = NO;
    
    /* Set Running to Yes */
    _running = YES;
    
    /* Lets start communications */
    xpc_connection_t connection = [self connection_for_session:passedSessionID];
    NSLog(@"(%p)!", connection);
    connection_handle = connection;
    if (!connection)
    {
        syslog(LOG_NOTICE, "Failed to create XPC connection.");
        return (-1);
    }
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event)
                                     {
                                         xpc_type_t type = xpc_get_type(event);
                                         
                                         if (type == XPC_TYPE_ERROR)
                                         {
                                             if (event == XPC_ERROR_CONNECTION_INTERRUPTED)  { syslog(LOG_NOTICE, "XPC connection interupted."); }
                                             else if (event == XPC_ERROR_CONNECTION_INVALID) { syslog(LOG_NOTICE, "XPC connection invalid, releasing."); }
                                             else                                            { syslog(LOG_NOTICE, "Unexpected XPC connection error."); }
                                         }
                                         else if (self->_usesPipes)
                                         {
                                             /*
                                              * Ok, we are probably starting to get pipe data...
                                              */
                                             const char *standardOutput = xpc_dictionary_get_string(event, "standardOutput");
                                             const char *standardError = xpc_dictionary_get_string(event, "standardError");
                                             
                                             NSFileHandle *writeHandle;
                                             
                                             if (standardOutput)
                                             {
                                                 syslog(LOG_NOTICE, "out: %s", standardOutput);
                                                 
                                                 writeHandle = [self->_standardOutput fileHandleForWriting];
                                                 [writeHandle writeData:[[NSString stringWithUTF8String:standardOutput] dataUsingEncoding:NSUTF8StringEncoding]];
                                             }
                                             if (standardError)
                                             {
                                                 syslog(LOG_NOTICE, "err: %s", standardError);
                                                 
                                                 writeHandle = [self->_standardError fileHandleForWriting];
                                                 [writeHandle writeData:[[NSString stringWithUTF8String:standardError] dataUsingEncoding:NSUTF8StringEncoding]];
                                             }
                                         }
                                         else // misc-events
                                         {
                                             const char *exit_event = xpc_dictionary_get_string(event, "exit_message");
                                             
                                             if (exit_event)
                                             {
                                                 /* termination status */
                                                 sscanf(exit_event, "%i", &self->_terminationStatus);
                                                 /* running? */
                                                 self->_running = NO;
                                                 
                                                 syslog(LOG_NOTICE, "Task finished with status: %i", self->_terminationStatus);
                                             }
                                         }
                                     });
    
    xpc_connection_resume(connection);
    
    /*
     * Create the arguments array
     */
    xpc_object_t arguments = xpc_array_create(NULL, 0);
    for (NSString *arg in self.arguments)
    {
        xpc_array_append_value(arguments, xpc_string_create(arg.UTF8String));
    }
    
    /*
     * Create the environment keys array
     */
    xpc_object_t environment_variables = xpc_array_create(NULL, 0);
    
    /*
     * Create the environment dictionary
     */
    NSDictionary *environmentDictionary = [NSProcessInfo processInfo].environment;
    xpc_object_t environment = xpc_dictionary_create(NULL, NULL, 0);
    
    for (NSString *key in environmentDictionary.allKeys)
    {
        xpc_object_t value = xpc_string_create([[environmentDictionary objectForKey:key] UTF8String]);
        xpc_object_t key_o = xpc_string_create(key.UTF8String);
        
        /* fill-in */
        xpc_array_append_value(environment_variables, key_o);
        xpc_dictionary_set_value(environment, key.UTF8String, value);
    }
    
    /*
     * Send data!
     */
    xpc_object_t dictionary = xpc_dictionary_create(NULL, NULL, 0);
    
    /* Tell Helper we are requesting a new-session event type */
    xpc_dictionary_set_string(dictionary,   SESSION_INFO_COMING_KEY,    "###_NEW_SESSION_###");
    xpc_dictionary_set_int64(dictionary,    SESSION_ID_KEY,             sessionID);
    xpc_dictionary_set_bool(dictionary,     SESSION_IS_NEW_KEY,         isSessionNew);
    xpc_dictionary_set_bool(dictionary,     STAY_AUTHORIZED_KEY,        _stayAuthorized);
    xpc_dictionary_set_string(dictionary,   LAUNCH_PATH_KEY,            self.launchPath.UTF8String);
    xpc_dictionary_set_string(dictionary,   CURRENT_DIR_KEY,            self.currentDirectoryPath.UTF8String);
    xpc_dictionary_set_value(dictionary,    ARGUMENTS_KEY,              arguments);
    xpc_dictionary_set_value(dictionary,    ENV_VARS_KEY,               environment_variables);
    xpc_dictionary_set_value(dictionary,    ENVIRONMENT_KEY,            environment);
    xpc_dictionary_set_bool(dictionary,     USE_PIPES_KEY,              _usesPipes);
    xpc_connection_send_message(connection, dictionary);
    
    /* Set PID */
    _processIdentifier = xpc_connection_get_pid(connection);
    
    /* Create Termination Checker and Start it... */
    NSThread *termination_checker_th = [[NSThread alloc] initWithBlock:^{
        [self waitUntilExit];
        [self terminationHandler];
    }];
    [termination_checker_th start];
    
    return sessionID;
}

- (void)waitUntilExit
{
    while (_running)
        sleep(2);   // 2 sec
}

- (void)endSession:(NSASession)sessionID
{
    if (!usingNSTask)
    {
        xpc_connection_t conn = [self connection_for_session:sessionID];
        
        if (!conn)
        {
            NSLog(@"Unable to find a connection with id: %li", sessionID);
            return;
        }
        
        /* send a force-quit event to Helper */
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "msg", "force-quit");
        xpc_connection_send_message(connection_handle, msg);
    }
    else
    {
        /* do nothing */
    }
}

- (void)endSession
{
    [self endSession:self->sessionID];
}

- (BOOL)suspend
{
    if (!usingNSTask)
    {
        if (!connection_handle)
            return NO;
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "msg", "SUSPEND");
        xpc_connection_send_message(connection_handle, msg);
        return YES;
    }
    else
    {
        return [tsk suspend];
    }
}
- (BOOL)resume
{
    if (!usingNSTask)
    {
        if (!connection_handle)
            return NO;
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "msg", "RESUME");
        xpc_connection_send_message(connection_handle, msg);
        return YES;
    }
    else
    {
        return [tsk resume];
    }
}
- (void)interrupt
{
    if (!usingNSTask)
    {
        if (!connection_handle)
            return;
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "msg", "INTERRUPT");
        xpc_connection_send_message(connection_handle, msg);
    }
    else
    {
        [tsk interrupt];
    }
}
- (void)terminate
{
    if (!usingNSTask)
    {
        if (!connection_handle)
            return;
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "msg", "TERMINATE");
        xpc_connection_send_message(connection_handle, msg);
    }
    else
    {
        [tsk terminate];
    }
}

@end
