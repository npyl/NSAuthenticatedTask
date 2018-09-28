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

#ifdef DEBUG_MODE
#define DBG_LOG(str) syslog(LOG_NOTICE, str)
#else
#define DBG_LOG(str)
#endif

@interface SMJobBlessHelper : NSObject
{
    xpc_connection_t connection_handle;
    xpc_connection_t service;
}

- (instancetype)init;
- (void)dispatchMain;

@end

@implementation SMJobBlessHelper

- (void) __XPC_Peer_Event_Handler:(xpc_connection_t)connection withEvent:(xpc_object_t)event
{
    xpc_type_t type = xpc_get_type(event);
    
    if (type == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
            syslog(LOG_NOTICE, "CONNECTION_INVALID");
        } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
            // Handle per-connection termination cleanup.
            syslog(LOG_NOTICE, "CONNECTION_IMMINENT");
        } else {
            syslog(LOG_NOTICE, "Got unexpected (and unsupported) XPC ERROR");
        }

    }
    else
    {

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

- (void)dispatchMain
{
    dispatch_main();
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
    NSLog(@"HERE!");
    
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    [helper dispatchMain];
    
    return EXIT_SUCCESS;
}
