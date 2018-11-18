//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NPTask.h"

@implementation NSTask (NPTask)

- (void)launchAuthenticated
{
    /* Call the NPAuthenticator */
    NSTask *NPAuthenticator = [[NSTask alloc] init];
    NPAuthenticator.launchPath = [[NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"NPAuthenticator" ofType:@"app"]] executablePath];
    [NPAuthenticator launch];
    [NPAuthenticator waitUntilExit];
    
    if ([NPAuthenticator terminationStatus] != 0)
    {
        NSLog(@"Authentication failed!");
        return;
    }
    
    /* Lets start communications */
    xpc_connection_t connection = xpc_connection_create_mach_service("npyl.NPTask.SMJobBlessHelper",
                                                                     NULL,
                                                                     XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    
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
    });
    
    xpc_connection_resume(connection);

    /*
     * Send the arguments
     */
    xpc_object_t arguments = xpc_array_create(NULL, 0);
    for (NSString *arg in self.arguments)
    {
        xpc_array_append_value(arguments, xpc_string_create(arg.UTF8String));
    }
    
    /*
     * Send message with launchPath and currentLaunchPath
     */
    xpc_object_t dictionary = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(dictionary, "launchPath", self.launchPath.UTF8String);
    xpc_dictionary_set_string(dictionary, "currentDirectoryPath", self.currentDirectoryPath.UTF8String);
    xpc_dictionary_set_value(dictionary, "arguments", arguments);
    // XXX env
    xpc_connection_send_message(connection, dictionary);    
}

@end
