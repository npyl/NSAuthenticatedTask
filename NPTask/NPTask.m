//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NPTask.h"

@implementation NPTask

- (void)interrupt {}
- (void)terminate {}

- (BOOL)suspend { return NO; }
- (BOOL)resume { return NO; }

- (void)waitUntilExit {}

- (void)launch {}

- (void)launchAuthenticated
{
    /* Call the SMJobBlessHelperCaller */
    [[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"NPAuthenticator" ofType:@"app"]];
    
    /* Lets start communications */
    xpc_connection_t connection = xpc_connection_create_mach_service("npyl.NPTask.SMJobBlessHelper", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    
    if (!connection)
    {
        NSLog(@"Failed to create XPC connection.");
        return;
    }
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        xpc_type_t type = xpc_get_type(event);
        
        if (type == XPC_TYPE_ERROR)
        {
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                NSLog(@"XPC connection interupted.");
            } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                NSLog(@"XPC connection invalid, releasing.");
            } else {
                NSLog(@"Unexpected XPC connection error.");
            }
            
        }
    });
    
    xpc_connection_resume(connection);

    /*
     * Construct a dictionary of the arguments
     */
    xpc_object_t initialMessage = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(initialMessage, "dummy", "dummy");
    
    /*
     * Send the message
     */
    xpc_connection_send_message(connection, initialMessage);
}

@end
