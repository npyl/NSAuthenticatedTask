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

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testOne {
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    
    /*
     * Allow us to call another script with admin
     * privileges without having to type in the password again.
     */
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
    
    /*
     NSFileHandle *fh = [[task standardOutput] fileHandleForReading];
     NSData *data = [fh readDataToEndOfFile];
     NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
     NSLog(@"GOT: %@", str);
     */
}
- (void)testTwo {
    NSAuthenticatedTask *task2_1 = [[NSAuthenticatedTask alloc] init];
    
    // batch1
    task2_1.launchPath = @"/bin/mkdir";
    task2_1.arguments = @[@"/hello.1"];
    NSASession sessionA = [task2_1 launchAuthorized];
    NSLog(@"SESSIONA: %lu", (unsigned long)sessionA);
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
- (void)testThree {
    NSString *prettyPath = [NSHomeDirectory() stringByAppendingPathComponent:@"this_is_a_test_from_NSAuthTask"];
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[prettyPath];
    [task launch];
    [task waitUntilExit];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    // XXX add test for when we are using currentDirectoryURL instead of currentDirectory
    
    [self testOne];
    [self testTwo];
    [self testThree];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
