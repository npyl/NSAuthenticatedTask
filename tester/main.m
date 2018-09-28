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
    NPTask *task = [[NPTask alloc] init];
    task.launchPath = @"/bin/echo";
    task.arguments = @[@"hello", @"konitsua"];
    [task launchAuthenticated];
    
    return 0;
}
