//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NSAuthenticatedTask.h"

#import <syslog.h>
#import "Shared/Shared.h"
#import <Cocoa/Cocoa.h>

double NSAuthenticatedTaskVersionNumber = 0.76;
const unsigned char NSAuthenticatedTaskVersionString[] = "Basic_Functionality_Still_Alpha_Though";

enum {
    NSA_MODE_NSTASK,
    NSA_MODE_AUTHTSK,
};

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
        
        tsk = [[NSTask alloc] init];
        _stayAuthorized = NO;
        _usesPipes = NO;
        _icon = nil;
        tsk.currentDirectoryPath = [NSString stringWithUTF8String:cwd];
        tsk.environment = [[NSProcessInfo processInfo] environment];
        [self setTerminationHandler:^(NSTask * _Nonnull tsk) {}];
        _terminationStatus = 1; // !0 = error
    }
    return self;
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
    xpc_connection_t conn;
    NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)sessionID];
    
    switch (sessionID)
    {
        /* connection handle for new SESSION */
        case NSA_SESSION_NEW:
            conn = xpc_connection_create_mach_service(HELPER_IDENTIFIER, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);

            NSLog(@"Created new Connection Handle: (%p)", conn);
            break;
        /* connection handle for valid existing SESSION */
        default:
            conn = (xpc_connection_t)[[NSUserDefaults standardUserDefaults] objectForKey:key];

            NSLog(@"Got Previous Connection Handle: (%p)", conn);
            break;
    }
    
    return conn;
}

- (void)launch
{
    mode = NSA_MODE_NSTASK;

    [tsk launch];
    _running = YES;
}

- (NSASession)launchAuthorizedWithSession:(NSASession)passedSessionID
{
    sessionID = -1; /* clear & re-initialise sessionID */
    static BOOL calledFirstTime = YES;
    BOOL isSessionNew = (passedSessionID == NSA_SESSION_NEW);

    /*
     * Generate a SESSION ID
     */
    if (isSessionNew)
    {
        sessionID = arc4random_uniform(10000000);
    }
    
    if (!self.launchPath)
    {
        [NSException raise:@"launchPath cannot be nil" format:@""];
        return (-1);
    }
    
    mode = NSA_MODE_AUTHTSK;
    
    /*
     * Call NPAuthenticator to authenticate ONLY ONCE
     * if `_stayAuthorized' is set by user or if new SESSION.
     */
    if ((_stayAuthorized && calledFirstTime) || isSessionNew)
    {
        NSString *_executableName = [self.launchPath lastPathComponent];
        
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
    
    /* Lets start communications */
    xpc_connection_t connection = [self connection_for_session:passedSessionID];
    connection_handle = connection;
    if (!connection)
    {
        syslog(LOG_NOTICE, "Failed to create XPC connection.");
        return (-1);
    }
    
    /* Set Running to Yes */
    _running = YES;
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event)
                                     {
                                         xpc_type_t type = xpc_get_type(event);
                                         
                                         if (type == XPC_TYPE_ERROR)
                                         {
                                             if (event == XPC_ERROR_CONNECTION_INTERRUPTED)  { syslog(LOG_NOTICE, "XPC connection interupted."); }
                                             else if (event == XPC_ERROR_CONNECTION_INVALID) { syslog(LOG_NOTICE, "XPC connection invalid, releasing."); }
                                             else                                            { syslog(LOG_NOTICE, "Unexpected XPC connection error."); }
                                             
                                             /* Things went south; Doesn't mean we need to stay here forever... */
                                             self->_running = NO;
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
                                             else
                                             {
                                                 // This means we received data from the task;
                                                 // If pipes are being used, then write to our pipes so that user can access the data;
                                                 // else, print to console like NSTask does...

                                                 const char *standardOutput = xpc_dictionary_get_string(event, "standardOutput");
                                                 const char *standardError = xpc_dictionary_get_string(event, "standardError");
                                                 
                                                 if (!self->_usesPipes)
                                                 {
                                                     //
                                                     // Write to stdout/stderr
                                                     //
                                                     printf("================\nPRINTING TO CONSOLE!\n=================\n\n");
                                                     
                                                     if (standardOutput) fprintf(stdout, "%s", standardOutput);
                                                     if (standardError) fprintf(stderr, "%s", standardError);
                                                 }
                                                 else
                                                 {
                                                     NSFileHandle *writeHandle;
                                                     
                                                     if (standardOutput)
                                                     {
                                                         syslog(LOG_NOTICE, "out: %s", standardOutput);
                                                         
                                                         writeHandle = [self.standardOutput fileHandleForWriting];
                                                         [writeHandle writeData:[[NSString stringWithUTF8String:standardOutput] dataUsingEncoding:NSUTF8StringEncoding]];
                                                     }
                                                     if (standardError)
                                                     {
                                                         syslog(LOG_NOTICE, "err: %s", standardError);
                                                         
                                                         writeHandle = [self.standardError fileHandleForWriting];
                                                         [writeHandle writeData:[[NSString stringWithUTF8String:standardError] dataUsingEncoding:NSUTF8StringEncoding]];
                                                     }
                                                 }
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

- (NSASession)launchAuthorized
{
    return [self launchAuthorizedWithSession:NSA_SESSION_NEW];
}

- (void)waitUntilExit
{
    while (_running)
        sleep(2);   // 2 sec
}

- (void)endSession:(NSASession)sessionID
{
    if (mode == NSA_MODE_NSTASK)
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
    if (mode == NSA_MODE_NSTASK)
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
    if (mode == NSA_MODE_NSTASK)
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
    if (mode == NSA_MODE_NSTASK)
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
    if (mode == NSA_MODE_NSTASK)
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

//
// SETTERS/GETTERS
// Bridge everything to NSTask.
//

- (void)setLaunchPath:(NSString *)launchPath
{
    tsk.launchPath = launchPath;
    
    /* Get Icon for File */
    _icon = [self GetImageForFile:tsk.launchPath];
}
- (NSString *)launchPath {
    return tsk.launchPath;
}

- (NSURL *)executableURL {
    return tsk.executableURL;
}
- (void)setExecutableURL:(NSURL *)url {
    tsk.executableURL = url;
}

- (NSArray *)arguments {
    return tsk.arguments;
}
- (void)setArguments:(NSArray *)args {
    tsk.arguments = args;
}

- (NSDictionary *)environment {
    return tsk.environment;
}
- (void)setEnvironment:(NSDictionary *)environment {
    tsk.environment = environment;
}

- (NSURL *)currentDirectoryURL {
    return tsk.currentDirectoryURL;
}
- (void)setCurrentDirectoryURL:(NSURL *)currentDirectoryURL {
    tsk.currentDirectoryURL = currentDirectoryURL;
}

- (NSString *)currentDirectoryPath {
    return tsk.currentDirectoryPath;
}
- (void)setCurrentDirectoryPath:(NSString *)currentDirectoryPath {
    tsk.currentDirectoryPath = currentDirectoryPath;
}

- (int)processIdentifier {
    return (mode == NSA_MODE_NSTASK) ? tsk.processIdentifier : _processIdentifier;
}
- (int)terminationStatus {
    return (mode == NSA_MODE_NSTASK) ? tsk.terminationStatus : _terminationStatus;
}
- (NSTaskTerminationReason)isTerminationReason {
    return (mode == NSA_MODE_NSTASK) ? tsk.terminationReason : _terminationReason;
}

- (void (^)(NSTask *_Nonnull))terminationHandler {
    return tsk.terminationHandler;
}
- (void)setTerminationHandler:(void (^)(NSTask * _Nonnull))terminationHandler {
    tsk.terminationHandler = ^(NSTask * _Nonnull _tsk) {
        /* call passed handler */
        if (terminationHandler)
            terminationHandler(_tsk);
        
        NSLog(@"Task finished!");
        
        /* notify our NSAuthenticatedTask that we are done here (task exited)... */
        self->_running = NO;
    };
}

- (id)standardInput {
    return tsk.standardInput;
}
- (void)setStandardInput:(id)standardInput {
    tsk.standardInput = standardInput;
    _usesPipes = YES;
}

- (id)standardOutput {
    return tsk.standardOutput;
}
- (void)setStandardOutput:(id)standardOutput {
    tsk.standardOutput = standardOutput;
    _usesPipes = YES;
}

- (id)standardError {
    return tsk.standardError;
}
- (void)setStandardError:(id)standardError {
    tsk.standardError = standardError;
    _usesPipes = YES;
}

//
// (npyl): Find a way to remove me;
// I was brought to life because terminationHandler doesn't use NSAuthenticatedTask
// but NSTask and we have a problem converting it...
//
- (NSTask *)task {
    return self->tsk.copy;
}

@end
