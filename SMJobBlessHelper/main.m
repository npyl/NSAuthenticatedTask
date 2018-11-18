//
//  main.m
//  SMJobBlessHelper
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <syslog.h>
#import <xpc/xpc.h>
#import <Foundation/Foundation.h>

#define SMJOBBLESSHELPER_IDENTIFIER "npyl.NPTask.SMJobBlessHelper"

@interface SMJobBlessHelper : NSObject
{
    xpc_connection_t    connection_handle;
    xpc_connection_t    service;
    
    /* data */
    const char          *launchPath;
    const char          *currentDirectoryPath;
    xpc_object_t        arguments;
    
    xpc_object_t        environment;           /* dictionary */
    xpc_object_t        environmentVariables;   /* array: list of keys */

    /* misc */
    size_t              argumentsCount;
    size_t              variablesCount;
}

- (instancetype)init;

@end

@implementation SMJobBlessHelper

enum {
    STATE_LAUNCHINFO,
    STATE_RUN,
    STATE_DONE, /* we can exit now... */
};

int STATE = STATE_LAUNCHINFO;

void advance_state(void) { STATE++; }

- (void) __XPC_Peer_Event_Handler:(xpc_connection_t)connection withEvent:(xpc_object_t)event
{
//    syslog(LOG_NOTICE, "Received message in generic event handler: %p\n", event);
//    syslog(LOG_NOTICE, "%s\n", xpc_copy_description(event));

    xpc_type_t type = xpc_get_type(event);
    
    if (type == XPC_TYPE_ERROR)
    {
        if (event == XPC_ERROR_CONNECTION_INVALID)
        {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
            syslog(LOG_NOTICE, "CONNECTION_INVALID");
        }
        else if (event == XPC_ERROR_TERMINATION_IMMINENT)
        {
            // Handle per-connection termination cleanup.
            syslog(LOG_NOTICE, "CONNECTION_IMMINENT");
        }
        else
        {
            syslog(LOG_NOTICE, "Got unexpected (and unsupported) XPC ERROR");
        }
    }
    else
    {
        switch (STATE)
        {
            case STATE_LAUNCHINFO:
                syslog(LOG_NOTICE, "[Helper]: GETTING LAUNCHINFO...\n");
                
                /*
                 * Paths
                 */
                launchPath = xpc_dictionary_get_string(event, "launchPath");
                currentDirectoryPath = xpc_dictionary_get_string(event, "currentDirectoryPath");
                if (!launchPath || !currentDirectoryPath)
                {
                    syslog(LOG_ERR, "Either launchPath or currentDirectoryPath is null. launchPath = %s \b currentDirectoryPath = %s", launchPath, currentDirectoryPath);
                    return;
                }
                
                /*
                 * Arguments
                 */
                arguments = xpc_dictionary_get_value(event, "arguments");
                if (!arguments)
                {
                    syslog(LOG_ERR, "Arguments is null");
                    return;
                }
                
                /*
                 * Environment
                 */
                environmentVariables = xpc_dictionary_get_value(event, "environmentVariables");
                if (!environmentVariables)
                {
                    syslog(LOG_ERR, "Env Variables is null");
                    return;
                }
                
                environment = xpc_dictionary_get_value(event, "environment");
                if (!environment)
                {
                    syslog(LOG_ERR, "Environment is null");
                    return;
                }

                break;
            case STATE_RUN:
                syslog(LOG_NOTICE, "launchPath = %s \n currentDirectoryPath = %s.",
                       launchPath,
                       currentDirectoryPath);
                
                // exec...
                
                /* fallthrough */

            case STATE_DONE:
            default:
                syslog(LOG_NOTICE, "exiting...");
                exit(0);
                break;
        }
        
        /*  */
        advance_state();
    }
}

- (void) __XPC_Connection_Handler:(xpc_connection_t)connection
{
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event)
                                     {
                                         [self __XPC_Peer_Event_Handler:connection withEvent:event];
                                     });
    
    xpc_connection_resume(connection);
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        service = xpc_connection_create_mach_service(SMJOBBLESSHELPER_IDENTIFIER,
                                                     dispatch_get_main_queue(),
                                                     XPC_CONNECTION_MACH_SERVICE_LISTENER);
        if (!service)
        {
            syslog(LOG_NOTICE, "Failed to create service.");
            exit(EXIT_FAILURE);
        }
        
        xpc_connection_set_event_handler(service, ^(xpc_object_t connection)
                                         {
                                             [self __XPC_Connection_Handler:connection];
                                         });
        xpc_connection_resume(service);
    }
    return self;
}

@end

int main(int argc, const char *argv[])
{
    syslog(LOG_NOTICE, "NSAuthenticatedTask v%f | npyl", 0.2);
    
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    dispatch_main();
    
    return EXIT_SUCCESS;
}
