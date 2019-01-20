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
    
    /*
    NSFileHandle *fh = [[task standardOutput] fileHandleForReading];
    NSData *data = [fh readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"GOT: %@", str);
     */
    
    return 0;
}
