//
//  Shared.m
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 02/12/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import "Shared.h"

#import <syslog.h>
#import <Foundation/Foundation.h>

void helper_log(const char *format, ...)
{
    va_list vargs;
    va_start(vargs, format);
    NSString* formattedMessage = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:vargs];
    va_end(vargs);
    
    syslog(LOG_NOTICE, "[HELPER]: %s", formattedMessage.UTF8String);
}
