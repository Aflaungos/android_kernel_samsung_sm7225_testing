#include <linux/ologk.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/uidgid.h>
#include <linux/sched.h>
#include <linux/cred.h>

void _perflog(int type, int logid, const char *fmt, ...)
{
    // Only allow root or system apps (UID 0 for root and 1000 for system apps)
    if (current_uid().val != 0 && current_uid().val < 1000) {
        pr_err("Unauthorized access to perflog by UID %d\n", current_uid().val);
        return; // Deny access
    }

    // Add your normal logging behavior here for authorized processes
    va_list args;
    va_start(args, fmt);
    vprintk(fmt, args);
    va_end(args);
}

//void perflog_evt(int logid, int arg1) {
//}

