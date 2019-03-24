//
//  NPTaskTester.m
//  NPTaskTester
//
//  Created by Nickolas Pylarinos Stamatelatos on 24/03/2019.
//  Copyright © 2019 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "../NPTask/NSAuthenticatedTask.h"

@interface NPTaskTester : XCTestCase

@end

@implementation NPTaskTester

//
// NSTask Functionality
//
- (void)testNSTaskFunctionality__launch_
{
    NSString *prettyPath = [NSHomeDirectory() stringByAppendingPathComponent:@"this_is_a_test_from_NSAuthTask"];
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[prettyPath];
    [task launch];
    [task waitUntilExit];
}
- (void)testNSTaskFunctionality__currentDirectoryURL_
{
    NSURL *currentDirectoryURL = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSString *prettyPath = @"this_is_a_test_from_NSAuthTask";
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.currentDirectoryURL = currentDirectoryURL;
    task.arguments = @[prettyPath];
    [task launch];
    [task waitUntilExit];
}

//
// Authenticated Functionality
//
- (void)testLaunchAuthorized
{
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];

    task.launchPath = @"/bin/mkdir";
    task.arguments = @[@"/hello.1"];
    [task launchAuthorized];
    [task waitUntilExit];
}

- (void)testAuthenticationIsPreservedAfterTaskTermination
{
    //
    // Test "run 2 tasks with admin privileges BUT authenticate ONCE" case;
    //
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];

    task.stayAuthorized = YES;
    
    // batch1
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[@"/hello.1"];
    [task launchAuthorized];
    [task waitUntilExit];
    
    // batch2
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[@"/hello.2"];
    [task launchAuthorized];
    [task waitUntilExit];
    
    // XXX remember to endSession (Update to newer NSAuthenticatedTask.)
}
- (void)testSessions
{
    NSAuthenticatedTask *task2_1 = [[NSAuthenticatedTask alloc] init];
    
    // batch1
    task2_1.launchPath = @"/bin/mkdir";
    task2_1.arguments = @[@"/hello.1"];
    NSASession sessionA = [task2_1 launchAuthorized];
    [task2_1 waitUntilExit];
    
    if (sessionA == -1)
        NSLog(@"Oopsies: Something went wrong with launching task2_1");
    else
    {
        NSAuthenticatedTask *task2_2 = [[NSAuthenticatedTask alloc] init];
        
        // batch2
        task2_2.launchPath = @"/bin/mkdir";
        task2_2.arguments = @[@"/hello.2"];
        [task2_2 launchAuthorizedWithSession:sessionA];
        [task2_2 waitUntilExit];
        
        /*
         * After we are done with it, we should end the session.
         * This should close the authenticated Helper which is MORE secure,
         * and MORE resource efficient.
         */
        [task2_2 endSession:sessionA];
    }
}

- (void)testExample
{
    // Default Functinality
    [self testNSTaskFunctionality__launch_];
    [self testNSTaskFunctionality__currentDirectoryURL_];

    // Authenticated Functionality
    [self testLaunchAuthorized];
    [self testAuthenticationIsPreservedAfterTaskTermination];
    [self testSessions];
}

@end
