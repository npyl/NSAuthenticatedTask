//
//  NPTask.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "NPTask.h"

@implementation NPTask

- (void)interrupt {}
- (void)terminate {}

- (BOOL)suspend { return NO; }
- (BOOL)resume { return NO; }

- (void)waitUntilExit {}

- (void)launch {}

- (void)launchAuthenticated
{
    
}

@end
