//
//  Shared.h
//  NPTask
//
//  Created by Nickolas Pylarinos Stamatelatos on 18/11/2018.
//  Copyright © 2018 Nickolas Pylarinos Stamatelatos. All rights reserved.
//

#ifndef Shared_h
#define Shared_h

#define HELPER_IDENTIFIER   "npyl.NPTask.SMJobBlessHelper"

/*
 * Keys
 */
#define SESSION_INFO_COMING_KEY "session_info_coming_key"
#define SESSION_ID_KEY          "session_id_key"
#define SESSION_IS_NEW_KEY      "is_session_new?_key"
#define STAY_AUTHORIZED_KEY     "stay_authorized_key"
#define LAUNCH_PATH_KEY         "launch_path_key"
#define CURRENT_DIR_KEY         "current_directory_key"
#define ARGUMENTS_KEY           "arguments_key"
#define ENV_VARS_KEY            "environment_variables_key"
#define ENVIRONMENT_KEY         "environment_key"
#define USE_PIPES_KEY           "use_pipes_key"

/*
 * Logging
 */
void helper_log(const char *format, ...);

#endif /* Shared_h */
