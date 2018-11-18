//
//  main.m
//  SMJobBlessHelper
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <syslog.h>
#import <xpc/xpc.h>
#import "../Shared.h"
#import <Foundation/Foundation.h>

@interface SMJobBlessHelper : NSObject
{
    xpc_connection_t    connection_handle;
    xpc_connection_t    service;
    
    /* data */
    const char          *launch_path;
    const char          *current_directory_path;
    xpc_object_t        arguments;
    xpc_object_t        environment;            /* dictionary */
    xpc_object_t        environment_variables;  /* array: list of keys */
}

- (instancetype)init;

@end

@implementation SMJobBlessHelper

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
        //==================================//==================================
        //                                 DATA
        //==================================//==================================

        syslog(LOG_NOTICE, "[Helper]: GETTING LAUNCHINFO...\n");
    
        /*
         * Paths
         */
        launch_path = xpc_dictionary_get_string(event, LAUNCH_PATH_KEY);
        current_directory_path = xpc_dictionary_get_string(event, CURRENT_DIR_KEY);
        if (!launch_path || !current_directory_path)
        {
            syslog(LOG_ERR, "Either launchPath or currentDirectoryPath is null. launchPath = %s \b currentDirectoryPath = %s", launch_path, current_directory_path);
            return;
        }
    
        /*
         * Arguments
         */
        arguments = xpc_dictionary_get_value(event, ARGUMENTS_KEY);
        if (!arguments)
        {
            syslog(LOG_ERR, "Arguments is null");
            exit(EXIT_FAILURE);
        }
    
        /*
         * Environment
         */
        environment_variables = xpc_dictionary_get_value(event, ENV_VARS_KEY);
        if (!environment_variables)
        {
            syslog(LOG_ERR, "Env Variables is null");
            exit(EXIT_FAILURE);
        }
    
        environment = xpc_dictionary_get_value(event, ENVIRONMENT_KEY);
        if (!environment)
        {
            syslog(LOG_ERR, "Environment is null");
            exit(EXIT_FAILURE);
        }
        
        //==================================//==================================
        //                                LOGGING
        //==================================//==================================

        syslog(LOG_NOTICE, "launch_path = %s \n current_directory_path = %s.", launch_path, current_directory_path);
        
        syslog(LOG_NOTICE, "ARGUMENTS:\n");
        for (int i = 0; i < xpc_array_get_count(arguments); i++)
        {
            syslog(LOG_NOTICE, "%s\n", xpc_array_get_string(arguments, i));
        }

        syslog(LOG_NOTICE, "ENVIRONMENT:\n");
        for (int i = 0; i < xpc_array_get_count(environment_variables); i++)
        {
            const char *key = xpc_array_get_string(environment_variables, i);
            syslog(LOG_NOTICE, "%s: %s\n", key, xpc_dictionary_get_string(environment_variables, key));
        }
        
        //==================================//==================================
        //                                EXECUTE
        //==================================//==================================
        
        syslog(LOG_NOTICE, "exiting...");
        exit(EXIT_SUCCESS);
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
        service = xpc_connection_create_mach_service(HELPER_IDENTIFIER,
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
    syslog(LOG_NOTICE, "NSAuthenticatedTask v%.1f | npyl", 0.3);
    
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    dispatch_main();
    
    return EXIT_SUCCESS;
}
