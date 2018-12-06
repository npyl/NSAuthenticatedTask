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

@implementation NSAuthenticatedTask

- (BOOL)suspend
{
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "SUSPEND");
    xpc_connection_send_message(connection_handle, msg);
    return YES;
}
- (BOOL)resume
{
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "RESUME");
    xpc_connection_send_message(connection_handle, msg);
    return YES;
}
- (void)interrupt
{
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "INTERRUPT");
    xpc_connection_send_message(connection_handle, msg);
}
- (void)terminate
{
    xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(msg, "msg", "TERMINATE");
    xpc_connection_send_message(connection_handle, msg);
}

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
        
        _usesPipes = NO;
        _icon = nil;
        _currentDirectoryPath = [NSString stringWithUTF8String:cwd];
        _environment = [[NSProcessInfo processInfo] environment];
    }
    return self;
}

- (void)launchAuthenticated
{
    if (_standardInput || _standardOutput || _standardError)
        _usesPipes = YES;
    
    /*
     * Call the NPAuthenticator
     */
    NSBundle *thisFramework = [NSBundle bundleWithIdentifier:@"npyl.NPTask"];
    NSBundle *NPAuthBundle = [NSBundle bundleWithPath:[thisFramework pathForResource:@"NPAuthenticator" ofType:@"app"]];
    NSString *NPAuthenticatorPath = [NPAuthBundle executablePath];
    
    NSTask *NPAuthenticator = [[NSTask alloc] init];
    NPAuthenticator.launchPath = NPAuthenticatorPath;
    if (_icon) NPAuthenticator.arguments = @[_icon];
    [NPAuthenticator launch];
    [NPAuthenticator waitUntilExit];
    
    if ([NPAuthenticator terminationStatus] != 0)
    {
        NSLog(@"Authentication failed!");
        return;
    }
    
    /* Set Running to Yes */
    _running = YES;
    
    /* Lets start communications */
    xpc_connection_t connection = xpc_connection_create_mach_service(HELPER_IDENTIFIER, NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    connection_handle = connection;
    if (!connection)
    {
        NSLog(@"Failed to create XPC connection.");
        return;
    }
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event)
    {
        xpc_type_t type = xpc_get_type(event);
        
        if (type == XPC_TYPE_ERROR)
        {
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED)  { NSLog(@"XPC connection interupted."); }
            else if (event == XPC_ERROR_CONNECTION_INVALID) { NSLog(@"XPC connection invalid, releasing."); }
            else                                            { NSLog(@"Unexpected XPC connection error."); }
        }
        else if (self->_usesPipes)
        {
            /*
             * Ok, we are starting to get pipe data...
             */
            const char *standardOutput = xpc_dictionary_get_string(event, "standardOutput");
            const char *standardError = xpc_dictionary_get_string(event, "standardError");
            
            NSFileHandle *writeHandle;
            
            if (standardOutput)
            {
                NSLog(@"out: %s", standardOutput);
                
                writeHandle = [self->_standardOutput fileHandleForWriting];
                [writeHandle writeData:[[NSString stringWithUTF8String:standardOutput] dataUsingEncoding:NSUTF8StringEncoding]];
            }
            if (standardError)
            {
                NSLog(@"err: %s", standardError);

                writeHandle = [self->_standardError fileHandleForWriting];
                [writeHandle writeData:[[NSString stringWithUTF8String:standardError] dataUsingEncoding:NSUTF8StringEncoding]];
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
    xpc_dictionary_set_string(dictionary,   LAUNCH_PATH_KEY,    self.launchPath.UTF8String);
    xpc_dictionary_set_string(dictionary,   CURRENT_DIR_KEY,    self.currentDirectoryPath.UTF8String);
    xpc_dictionary_set_value(dictionary,    ARGUMENTS_KEY,      arguments);
    xpc_dictionary_set_value(dictionary,    ENV_VARS_KEY,       environment_variables);
    xpc_dictionary_set_value(dictionary,    ENVIRONMENT_KEY,    environment);
    xpc_dictionary_set_bool(dictionary,     USE_PIPES_KEY,      _usesPipes);
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
    int status;
    waitpid(_processIdentifier, &status, 0);
    
    /* Set Running to NO */
    _running = NO;
}

@end
