//
//  main.m
//  tester
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NPTask/NPTask.h>

int main(int argc, const char * argv[])
{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/echo";                     /* setting this means we can throw error if the launchPath doesn't correspond to real executable */
    task.arguments = @[@"hello", @"konitsua"];          // Thinking about this, it may be a better idea to just use NSTask... and provide the launchAuthenticated as a plugin
    [task launchAuthenticated];

    [task waitUntilExit];

    return 0;
}
