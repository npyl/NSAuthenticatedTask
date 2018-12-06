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
    task.icon = @"temp";
    task.launchPath = @"/bin/sleep";
    //task.standardOutput = [NSPipe pipe];
    task.arguments = @[@"10"];
    
    [task launchAuthenticated];
    NSLog(@"START WAIT %i", task.processIdentifier);
    [task waitUntilExit];
    NSLog(@"END WAIT");
    
    /*
    NSFileHandle *fh = [[task standardOutput] fileHandleForReading];
    NSData *data = [fh readDataToEndOfFile];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"GOT: %@", str); */
    
    return 0;
}
