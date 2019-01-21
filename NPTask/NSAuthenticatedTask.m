//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NSAuthenticatedTask.h"

#import "../Shared.h"
#import <Cocoa/Cocoa.h>
#import <syslog.h>

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

- (void)launchAuthorized
{
    static BOOL calledOnce = NO;
    
    if (!_launchPath)
    {
        [NSException raise:@"launchPath cannot be nil" format:@""];
        return;
    }
    
    if (_standardInput || _standardOutput || _standardError)
        _usesPipes = YES;
    
    /*
     * Call NPAuthenticator to authenticate ONLY ONCE
     * if `_stayAuthorized' is set by user.
     */
    if (_stayAuthorized && calledOnce)
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
         * .../.../.../NPAuthenticator      EXECUTABLE_NAME         ICON
         */
        NSTask *NPAuthenticator = [[NSTask alloc] init];
        NPAuthenticator.launchPath = NPAuthenticatorPath;
        NPAuthenticator.arguments = args;
        [NPAuthenticator launch];
        [NPAuthenticator waitUntilExit];
        
        if ([NPAuthenticator terminationStatus] != 0)
        {
            syslog(LOG_NOTICE, "Authentication failed!");
            return;
        }
    }
    
    calledOnce = YES;
    
    /* Set Running to Yes */
    _running = YES;
    
    /* Lets start communications */
    xpc_connection_t connection = xpc_connection_create_mach_service(HELPER_IDENTIFIER, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    connection_handle = connection;
    if (!connection)
    {
        syslog(LOG_NOTICE, "Failed to create XPC connection.");
        return;
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
                syslog(LOG_NOTICE, "Launch request finished!");
                self->_running = NO;
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
    xpc_dictionary_set_string(dictionary,   NEW_SESSION_KEY,        "###_NEW_SESSION_###");
    xpc_dictionary_set_bool(dictionary,     STAY_AUTHORIZED_KEY,    _stayAuthorized);
    xpc_dictionary_set_string(dictionary,   LAUNCH_PATH_KEY,        self.launchPath.UTF8String);
    xpc_dictionary_set_string(dictionary,   CURRENT_DIR_KEY,        self.currentDirectoryPath.UTF8String);
    xpc_dictionary_set_value(dictionary,    ARGUMENTS_KEY,          arguments);
    xpc_dictionary_set_value(dictionary,    ENV_VARS_KEY,           environment_variables);
    xpc_dictionary_set_value(dictionary,    ENVIRONMENT_KEY,        environment);
    xpc_dictionary_set_bool(dictionary,     USE_PIPES_KEY,          _usesPipes);
    xpc_connection_send_message(connection, dictionary);
    
    /* Set PID */
    _processIdentifier = xpc_connection_get_pid(connection);
    
    /* Create Termination Checker and Start it... */
    NSThread *termination_checker_th = [[NSThread alloc] initWithBlock:^{
        [self waitUntilExit];
        [self terminationHandler];
    }];
    [termination_checker_th start];
}

- (void)waitUntilExit
{
    while (_running)
        sleep(2);   // 2 sec
}

- (BOOL)suspend
{
    if (!connection_handle)
        return NO;
    
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "SUSPEND");
    xpc_connection_send_message(connection_handle, msg);
    return YES;
}
- (BOOL)resume
{
    if (!connection_handle)
        return NO;

    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "RESUME");
    xpc_connection_send_message(connection_handle, msg);
    return YES;
}
- (void)interrupt
{
    if (!connection_handle)
        return;

    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "INTERRUPT");
    xpc_connection_send_message(connection_handle, msg);
}
- (void)terminate
{
    if (!connection_handle)
        return;

    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "TERMINATE");
    xpc_connection_send_message(connection_handle, msg);
}

@end
