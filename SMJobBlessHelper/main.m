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

// 0.7: Support pre-authorized sessions
#define HELPER_VER 0.7

@interface SMJobBlessHelper : NSObject
{
    xpc_connection_t    connection_handle;
    xpc_connection_t    service;
    
    NSUInteger          sessionID;
    bool                isSessionNew;
    
    /* data */
    bool                stay_authorized;
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

static NSTask *task = nil;

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
    connection_handle = connection;

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
        NSMutableArray *args = [NSMutableArray array];
        
        //==================================//==================================
        //                                 DATA
        //==================================//==================================

        /*
         * If `stay_authorized' is true, we need to identify what NSTask is sending us;
         * It may be task control-events or a new-session event...
         */
        const char* new_session_stamp = xpc_dictionary_get_string(event, SESSION_INFO_COMING_KEY);
        if (!new_session_stamp)
        {
            const char *msg = xpc_dictionary_get_string(event, "msg");

            helper_log("msg: %s", msg);
            
            if      (strcmp(msg, "SUSPEND") == 0)   { [task suspend];   }
            else if (strcmp(msg, "RESUME") == 0)    { [task resume];    }
            else if (strcmp(msg, "INTERRUPT") == 0) { [task interrupt]; }
            else if (strcmp(msg, "TERMINATE") == 0) { [task terminate]; }
            else if (strcmp(msg, "force-quit") == 0)
            {
                xpc_connection_cancel(connection_handle);
                helper_log("Exiting... (force-quit)");
                exit(EXIT_SUCCESS);
            }
            else
            {
                helper_log("received unknown msg (%s); ignoring.", msg);
            }
            
            return;
        }

        sessionID = xpc_dictionary_get_int64(event, SESSION_ID_KEY);
        isSessionNew = xpc_dictionary_get_bool(event, SESSION_IS_NEW_KEY);
        stay_authorized = xpc_dictionary_get_bool(event, STAY_AUTHORIZED_KEY);
        launch_path = xpc_dictionary_get_string(event, LAUNCH_PATH_KEY);
        current_directory_path = xpc_dictionary_get_string(event, CURRENT_DIR_KEY);
        arguments = xpc_dictionary_get_value(event, ARGUMENTS_KEY);
        environment_variables = xpc_dictionary_get_array(event, ENV_VARS_KEY);
        environment = xpc_dictionary_get_value(event, ENVIRONMENT_KEY);
        uses_pipes = xpc_dictionary_get_bool(event, USE_PIPES_KEY);

        helper_log("sessionID: %d", sessionID);
        helper_log("isSessionNew: %d", isSessionNew);
        helper_log("stay_authzd: %d", stay_authorized);
        helper_log("launch_path: %s", launch_path);
        helper_log("current_directory_path: %s", current_directory_path);
        helper_log("arguments: %p", arguments);
        helper_log("environment_variables: %p", environment_variables);
        helper_log("environment: %p", environment);
        helper_log("pipes: %i", uses_pipes);
    
        if (!launch_path || !current_directory_path || !arguments || !environment_variables || !environment)
        {
            if (stay_authorized)
                return;
            else
            {
                xpc_connection_cancel(connection);
                exit(EXIT_FAILURE);
            }
        }
    
        //==================================//==================================
        //                                LOGGING
        //==================================//==================================
    
        helper_log("ARGUMENTS:\n");
        for (int i = 0; i < xpc_array_get_count(arguments); i++)
        {
            helper_log("%s\n", xpc_array_get_string(arguments, i));
        }
    
        //==================================//==================================
        //                                EXECUTE
        //==================================//==================================
    
        for (int i = 0; i < xpc_array_get_count(arguments); i++)
        {
            NSString *arg = [NSString stringWithUTF8String:xpc_array_get_string(arguments, i)];
            [args addObject:arg];
        }
    
        task = [[NSTask alloc] init];
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

            const char *termStatusStr = [NSString stringWithFormat:@"%i", tsk.terminationStatus].UTF8String;
            
            /* Send termination message */
            xpc_object_t exit_msg = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(exit_msg, "exit_message", termStatusStr);
            xpc_connection_send_message(connection, exit_msg);
            
            task = nil;
            
            helper_log("Task (%@) terminated.", tsk.launchPath.lastPathComponent);
        }];
    
        [task launch];

        /*
         * Invalidate connection and close only if `stay_authorized' is false.
         * This way we keep an authenticated SMJobBlessHelper running and we can
         * execute more scripts/executables.  This should comprise of a SESSION.
         *
         * 0.7: If new session, keep running until teardown of macOS.
         */
        if (!stay_authorized || isSessionNew)
        {
            xpc_connection_cancel(connection_handle);
            helper_log("Exiting...");
            exit(EXIT_SUCCESS);
        }
        
        /*
         * Register connection handle into our registry
         */
        NSString *key = [NSString stringWithFormat:@"%lu", (unsigned long)sessionID];
        [[NSUserDefaults standardUserDefaults] setObject:connection
                                                  forKey:key];
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
    helper_log("NSAuthenticatedTaskHelper v%.1f | npyl", HELPER_VER);
    
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    dispatch_main();
    
    return EXIT_SUCCESS;
}
