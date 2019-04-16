#  NSAuthenticatedTask

**UNDER DEVELOPMENT (currently supports basic functions)**

A framework that adds administrator Authentication support to NSTask so you can execute your task with root privileges!
Follows Apple's recommended way of doing it (using SMJobBlessHelper and XPC) so no deprecated APIs here!

## Supported Features
- [x] Standard (NSTask) functionality
- [x] Launch Authenticated
- [x] Pass arguments
- [x] Pass current directory
- [x] Custom Authentication Icon (still quite buggy, though! [#3](https://github.com/npyl/NSAuthenticatedTask/issues/3))
- [x] Custom Authentication Text
- [ ] Pass environment variables
- [x] Pipes (nearly done)

## Projects Currently Using NSAuthenticatedTask

[ManageConky](https://github.com/Conky-for-macOS/Manage-Conky) (The de-facto Manager for Conky on macOS)<br>
[cocoasudo](https://github.com/npyl/cocoasudo) (a new implementation)

## Attributions
### Icons
Key by Luis Prado from the Noun Project

## LICENSE

Dual-Licensed under [996ICU License](https://github.com/996icu/996.ICU/blob/master/LICENSE) and [MIT License](https://github.com/npyl/NSAuthenticatedTask/blob/master/LICENSE).

By using this project as a company (or even person), you agree that your company (or yourself) will use the project while abiding to the labor rules of your country's.  For more info, and specific law matters carefully read the 996ICU License.

## SUPPORTING 💰

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=NSV636CUWX754)

[![Become a Patron!](http://npyl.github.io/img/become_a_patron_button.png)](https://www.patreon.com/bePatron?u=11783784)
