//
//  main.m
//  tester
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <NPTask/NSAuthenticatedTask.h>   // include for launchAuthenticated addition

//#define TEST1 // stayAuthorized
//#define TEST2 // Assign to Pre-authorized Session
#define TEST3 // Test normal NSTask functionality

int main(int argc, const char * argv[])
{
#ifdef TEST1
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
#endif

#ifdef TEST2
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
#endif

#ifdef TEST3
    NSString *prettyPath = [NSHomeDirectory() stringByAppendingPathComponent:@"this_is_a_test_from_NSAuthTask"];
    
    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[prettyPath];
    [task launch];
    [task waitUntilExit];
#endif

    return 0;
}
