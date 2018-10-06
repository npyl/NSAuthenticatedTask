//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NPTask.h"

@implementation NSTask (NPTask)

- (instancetype)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

- (void)launchAuthenticated
{
    /* Call the SMJobBlessHelperCaller */
    [[NSWorkspace sharedWorkspace] openFile:[[NSBundle mainBundle] pathForResource:@"NPAuthenticator" ofType:@"app"]];
    
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

//    @property (nullable, copy) NSString *launchPath;
//    @property (copy) NSString *currentDirectoryPath; // if not set, use current
//    @property (nullable, copy) NSURL *executableURL;
//    @property (nullable, copy) NSArray<NSString *> *arguments;
//    @property (nullable, copy) NSDictionary<NSString *, NSString *> *environment; // if not set, use current
//    @property (nullable, copy) NSURL *currentDirectoryURL;

    /*
     * Send message with launchPath and currentLaunchPath
     */
    xpc_object_t paths = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(paths, "launchPath", self.launchPath.UTF8String);
    xpc_dictionary_set_string(paths, "currentDirectoryPath", self.currentDirectoryPath.UTF8String);
    xpc_connection_send_message(connection, paths);
    
    /*
     * Send the arguments
     */
    /* create array */
    //xpc_object_t arguments = xpc_array_create(NULL, 0);

    /* fill array's contents */
    /*for (NSString *arg in self.arguments)
    {
        if (arg.UTF8String)
            xpc_array_append_value(arguments, xpc_string_create(arg.UTF8String));
        else
            xpc_array_append_value(arguments, xpc_null_create());
    }*/

    /* send array */
    /*@try {
        xpc_connection_send_message(connection, arguments);
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
    } @finally {
        
    }*/

    /*
     * Send environment
     */
    xpc_object_t environment = xpc_dictionary_create(NULL, NULL, 0);
    for (NSString *key in [self.environment keyEnumerator])
    {
        NSString *value = [self.environment objectForKey:key];
        xpc_dictionary_set_string(environment, key.UTF8String, value.UTF8String);
    }
    xpc_connection_send_message(connection, environment);
}

@end
