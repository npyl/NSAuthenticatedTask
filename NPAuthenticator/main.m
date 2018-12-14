//
//  main.m
//  NPAuthenticator
//
//  Created by Nickolas Pylarinos Stamatelatos on 28/09/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

/* defines */
#define ICON_ARGUMENT_INDEX 1
#define SMJOBBLESSHELPER_BUNDLE_ID @"npyl.NPTask.SMJobBlessHelper"

/*
 * Helper Function
 */
BOOL blessHelperWithLabel(NSString *label, char *icon, NSError **error)
{
    BOOL result = NO;
    
    //icon = "/Users/npyl/Documents/cocoasudo/NPTask/NPAuthenticator/Media.xcassets/AppIcon.appiconset/Key\\ copy\\ 2.png";
    
    AuthorizationItem right = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights authRights  = { 1, &right };
    AuthorizationFlags flags  = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    AuthorizationEnvironment authEnvironment;
    AuthorizationItem kAuthEnv[2];
    authEnvironment.items = kAuthEnv;
    
    AuthorizationRef authRef = NULL;
    CFErrorRef outError = nil;

    const char *prompt = "prompt";
    
    kAuthEnv[0].name = kAuthorizationEnvironmentPrompt;
    kAuthEnv[0].valueLength = strlen(prompt);
    kAuthEnv[0].value = prompt;
    kAuthEnv[0].flags = 0;
    authEnvironment.count++;

    if (icon) {
        kAuthEnv[1].name = kAuthorizationEnvironmentIcon;
        kAuthEnv[1].valueLength = strlen(icon);
        kAuthEnv[1].value = icon;
        kAuthEnv[1].flags = 0;
        
        authEnvironment.count++;
    }
    
    /* Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCreate(&authRights, &authEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess)
    {
        NSLog(@"Failed to create AuthorizationRef. Error code: %d", (int)status);
    }
    else
    {
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, authRef, &outError);
        
        /* get NSError out of CFErrorRef */
        *error = (__bridge NSError *)outError;
    }
    
    return result;
}

int main(int argc, const char * argv[])
{
    NSError *error = nil;

    if (!blessHelperWithLabel(SMJOBBLESSHELPER_BUNDLE_ID, argv[ICON_ARGUMENT_INDEX], &error))
    {
        NSLog(@"Failed to bless helper. Error: %@", error);
        return (-1);
    }
    
    return 0;
}
