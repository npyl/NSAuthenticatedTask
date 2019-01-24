//
//  main.m
//  tester
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <NPTask/NSAuthenticatedTask.h>   // include for launchAuthenticated addition

int main(int argc, const char * argv[])
{
// TEST1: stayAuthorized
//    NSAuthenticatedTask *task = [[NSAuthenticatedTask alloc] init];
//
//    /*
//     * Allow us to call another script with admin
//     * privileges without having to type in the password again.
//     */
//    task.stayAuthorized = YES;
//
//    // batch1
//    task.launchPath = @"/bin/mkdir";
//    task.arguments = @[@"/hello.1"];
//    [task launchAuthorized];
//    [task waitUntilExit];
//
//    // batch2
//    task.launchPath = @"/bin/mkdir";
//    task.arguments = @[@"/hello.2"];
//    [task launchAuthorized];
//    [task waitUntilExit];
    
    /*
    NSFileHandle *fh = [[task standardOutput] fileHandleForReading];
    NSData *data = [fh readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"GOT: %@", str);
     */
    
// TEST2: Assign to Pre-authorized Session
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
    }

    return 0;
}
