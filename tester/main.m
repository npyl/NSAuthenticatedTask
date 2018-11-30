//
//  main.m
//  tester
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NPTask/NPTask.h>   // include for launchAuthenticated addition

int main(int argc, const char * argv[])
{
    /* XXX setting this means we can throw error if the launchPath doesn't correspond to real executable */
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/mkdir";
    task.arguments = @[@"-p", @"/usr/local/test1234"];

    [task launchAuthenticated];
    [task waitUntilExit];

    return 0;
}
