#import "SHAppDelegate.h"
#import <sys/stat.h>
int main(void){@autoreleasepool{
 umask(0077);NSApplication *app=NSApplication.sharedApplication;[app setActivationPolicy:NSApplicationActivationPolicyAccessory];
 SHAppDelegate *delegate=SHAppDelegate.new;app.delegate=delegate;[app run];
}return 0;}
