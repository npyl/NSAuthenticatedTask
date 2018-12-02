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
    task.launchPath = @"/bin/mkdir";
    task.standardOutput = [NSPipe pipe];
    task.arguments = @[@"-p"];

    [task launchAuthenticated];
    [task waitUntilExit];

    return 0;
}
