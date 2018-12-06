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

#define HELPER_VER 0.5

enum {
    HELPER_STATE_RUN,       // just run app
    HELPER_STATE_OPR,       // just operate
    HELPER_STATE_BYE,       // just quit-up
    HELPER_STATE_DXT        // disaster exit
};

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
    bool                uses_pipes;
}

- (instancetype)init;

@end

@implementation SMJobBlessHelper

-(void)receivedData:(NSNotification*)notif
{
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        /* if data is found, re-register for more data (and print) */
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "standardOutput", [str UTF8String]);
        xpc_connection_send_message(connection_handle, msg);
    }
}

-(void)receivedError:(NSNotification*)notif
{
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        /* if data is found, re-register for more data (and print) */
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "standardError", [str UTF8String]);
        xpc_connection_send_message(connection_handle, msg);
    }
}

- (void) __XPC_Peer_Event_Handler:(xpc_connection_t)connection withEvent:(xpc_object_t)event
{
//    syslog(LOG_NOTICE, "Received message in generic event handler: %s\n", xpc_copy_description(event));

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
            helper_log("CONNECTION_INVALID");
        }
        else if (event == XPC_ERROR_TERMINATION_IMMINENT)
        {
            // Handle per-connection termination cleanup.
            helper_log("CONNECTION_IMMINENT");
        }
        else
        {
            helper_log("Got unexpected (and unsupported) XPC ERROR");
        }
    }
    else
    {
        static int STATE = HELPER_STATE_RUN;
        
        /* XXX
         * Obj-C is so unmerciful that doesn't allow us to have
         * these inside switch block...
         */
        NSMutableArray *args = [NSMutableArray array];
        NSTask *task = [[NSTask alloc] init];
        
        switch (STATE)
        {
            case HELPER_STATE_RUN:
                
                //==================================//==================================
                //                                 DATA
                //==================================//==================================
                
                helper_log("GETTING LAUNCHINFO...");
                
                /*
                 * All info...
                 */
                launch_path = xpc_dictionary_get_string(event, LAUNCH_PATH_KEY);
                current_directory_path = xpc_dictionary_get_string(event, CURRENT_DIR_KEY);
                arguments = xpc_dictionary_get_value(event, ARGUMENTS_KEY);
                environment_variables = xpc_dictionary_get_array(event, ENV_VARS_KEY);
                environment = xpc_dictionary_get_value(event, ENVIRONMENT_KEY);
                uses_pipes = xpc_dictionary_get_bool(event, USE_PIPES_KEY);
                
                helper_log("launch_path: %s", launch_path);
                helper_log("current_directory_path: %s", current_directory_path);
                helper_log("arguments: %i", arguments);
                helper_log("environment_variables: %i", environment_variables);
                helper_log("environment: %i", environment);
                helper_log("pipes: %i", uses_pipes);
                
                if (!launch_path || !current_directory_path || !arguments || !environment_variables || !environment)
                {
                    xpc_connection_cancel(connection);
                    return;
                }
                
                //==================================//==================================
                //                                LOGGING
                //==================================//==================================
                
                helper_log("ARGUMENTS:\n");
                for (int i = 0; i < xpc_array_get_count(arguments); i++)
                {
                    helper_log("%s\n", xpc_array_get_string(arguments, i));
                }
                
                //        helper_log("ENVIRONMENT:\n");
                //        for (int i = 0; i < xpc_array_get_count(environment_variables); i++)
                //        {
                //            const char *key = xpc_array_get_string(environment_variables, i);
                //            if (!key)
                //            {
                //                helper_log("ignoring %i", i);
                //                continue;
                //            }
                //
                //            helper_log("%s: %s\n", key, xpc_dictionary_get_string(environment_variables, key));
                //        }
                
                //==================================//==================================
                //                                EXECUTE
                //==================================//==================================
                
                for (int i = 0; i < xpc_array_get_count(arguments); i++)
                {
                    NSString *arg = [NSString stringWithUTF8String:xpc_array_get_string(arguments, i)];
                    [args addObject:arg];
                }
                
                //
                // XXX
                // We need to ditch NSTask for exec* family, because:
                // 1) NSTask throws runtime exceptions which we cannot handle
                //      (Helper Crashes => security vurnerability)
                //
                // 2) too heavy code... This is a Helper
                
                task.launchPath = [NSString stringWithUTF8String:launch_path];
                task.currentDirectoryPath = [NSString stringWithUTF8String:current_directory_path];
                task.arguments = args;

                /* if uses pipes, setup the pipe readers... */
                if (uses_pipes)
                {
                    NSFileHandle *output, *error;
                    
                    [task setStandardOutput:[NSPipe pipe]];
                    [task setStandardError:[NSPipe pipe]];
                    
                    output = [task.standardOutput fileHandleForReading];
                    error = [task.standardError fileHandleForReading];
                    
                    [output waitForDataInBackgroundAndNotify];
                    [error waitForDataInBackgroundAndNotify];
                    
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:output];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedError:) name:NSFileHandleDataAvailableNotification object:error];
                }
                
                [task setTerminationHandler:^(NSTask * _Nonnull tsk) {
                    helper_log("BYE1!");
                    STATE = HELPER_STATE_BYE;
                }];
                
                [task launch];
                
                STATE++;
                break;
            case HELPER_STATE_OPR:
                
                /*
                 * Accept general events...
                 */

                helper_log("test_opr");
                break;
                
            case HELPER_STATE_BYE:
                helper_log("BYE2!");
                xpc_connection_cancel(connection_handle);
                exit(EXIT_SUCCESS);
                break;
                
            default:
            case HELPER_STATE_DXT:
                helper_log("Oh Hi Unexpected HELPER_STATE!");
                exit(EXIT_FAILURE);
                break;
        }
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
            helper_log("Failed to create service.");
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
    helper_log("NSAuthenticatedTask v%.1f | npyl", HELPER_VER);
    
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    dispatch_main();
    
    return EXIT_SUCCESS;
}
