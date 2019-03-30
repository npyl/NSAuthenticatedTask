//
//  NPTaskTester.m
//  NPTaskTester
//
//  Created by Nickolas Pylarinos Stamatelatos on 24/03/2019.
//  Copyright © 2019 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#include <sys/stat.h>
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
- (void)testNSTaskFunctionality__launch__nil_termination_handler_
{
    NSString *prettyPath = [NSHomeDirectory() stringByAppendingPathComponent:@"this_is_a_test_from_NSAuthTask"];
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[prettyPath];
    [task setTerminationHandler:nil];
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
- (void)testLaunchAuthorizedWithPipes
{
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[@"/hello.1"];
    
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];

    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull fh) {
        NSString *data = [[NSString alloc] initWithData:fh.availableData encoding:NSUTF8StringEncoding];
        NSLog(@"%@", data);
    }];
    [[task.standardError fileHandleForReading] setReadabilityHandler:^(NSFileHandle * _Nonnull fh) {
        NSString *data = [[NSString alloc] initWithData:fh.availableData encoding:NSUTF8StringEncoding];
        NSLog(@"%@", data);
    }];
    
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

- (void)testCase:(SEL)selector withCreatedFile:(NSArray *)createdFiles
{
    NSLog(@"====================================");
    NSLog(@"TESTCASE: %s", sel_getName(selector));
    NSLog(@"====================================");
    printf("\n");

    if (!selector)
    {
        @throw [NSException exceptionWithName:@"Test" reason:@"Did not supply a selector." userInfo:nil];
        return;
    }

    /* remove files */
    for (NSString *file in createdFiles)
    {
        NSLog(@"Deleting: %@", file);

        XCTAssertEqual(remove(file.UTF8String), 0);
    }
    
    //
    // Run method
    //
    {
        IMP imp = [self methodForSelector:selector];
        void (*func)(id, SEL) = (void *)imp;
        
        /* run */
        func(self, selector);
    }
    
    /* just check if file exists */
    for (NSString *file in createdFiles)
    {
        XCTAssertEqual(access(file.UTF8String, F_OK), 0);
    }

    NSLog(@"================END=================");
    printf("\n\n");
}

- (void)testAuthenticatedCase:(SEL)selector withCreatedFile:(NSArray *)createdFiles
{
    NSLog(@"====================================");
    NSLog(@"TESTCASE: %s", sel_getName(selector));
    NSLog(@"====================================");
    printf("\n");
    
    if (!selector)
    {
        @throw [NSException exceptionWithName:@"Test" reason:@"Did not supply a selector." userInfo:nil];
        return;
    }
    
    for (NSString *file in createdFiles)
    {
        NSLog(@"Deleting: %@", file);
    }
    
    //
    // This is our task which cleans up stuff before the test runs
    //
    static NSAuthenticatedTask *janitor = nil;
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"-f"];

    if (!createdFiles)
        [arguments addObjectsFromArray:createdFiles];
    
    if (!janitor)
    {
        janitor = [[NSAuthenticatedTask alloc] init];
        janitor.launchPath = @"/bin/rm";
    }
    
    janitor.arguments = arguments;

    [janitor launchAuthorized];
    [janitor waitUntilExit];
    
    //
    // Run method
    //
    {
        IMP imp = [self methodForSelector:selector];
        void (*func)(id, SEL) = (void *)imp;

        /* run */
        func(self, selector);
    }

    /* check if file's owner is root; (this automatically checks if file */
    for (NSString *file in createdFiles)
    {
        struct stat *stat_info;
        
        int ret = stat(file.UTF8String, stat_info);
        
        if (ret != 0)
        {
            NSLog(@"stat: %s", strerror(errno));
        }
        
        XCTAssertEqual(ret, 0); /* check if stat succeeded */
        XCTAssertEqual(stat_info->st_uid, 0); /* check if owned by root */
    }

    NSLog(@"================END=================");
    printf("\n\n");
}

- (void)testExample
{
    NSString *prettyPath = [NSHomeDirectory() stringByAppendingPathComponent:@"this_is_a_test_from_NSAuthTask"];
    
    // Default Functinality
    [self testCase:@selector(testNSTaskFunctionality__launch_) withCreatedFile:@[prettyPath]];
    [self testCase:@selector(testNSTaskFunctionality__currentDirectoryURL_) withCreatedFile:@[prettyPath]];
    [self testCase:@selector(testNSTaskFunctionality__launch__nil_termination_handler_) withCreatedFile:@[prettyPath]];

    // Authenticated Functionality
    [self testAuthenticatedCase:@selector(testLaunchAuthorized)
                withCreatedFile:@[@"/hello.1"]];
    
    NSLog(@"====================================");
    NSLog(@"TESTCASE: testLaunchAuthorizedWithPipes");
    NSLog(@"====================================");
    printf("\n");
    [self testLaunchAuthorizedWithPipes];   /*
                                             * this should run without our cleanup technics;
                                             * this is because we *NEED* mkdir to fail (and print a message)
                                             */
    NSLog(@"================END=================");
    printf("\n\n");

    [self testAuthenticatedCase:@selector(testAuthenticationIsPreservedAfterTaskTermination)
                withCreatedFile:@[@"/hello.1", @"/hello.2"]];
    [self testAuthenticatedCase:@selector(testSessions)
                withCreatedFile:@[@"/hello.1", @"/hello.2"]];
}

@end
