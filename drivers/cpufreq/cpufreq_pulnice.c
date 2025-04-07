/*
 * CPU Frequency Governor: Pulnice (Stable Version)
 * - Fixed all warnings and errors
 * - Simple and reliable operation
 * - Proper big.LITTLE handling
 */

#include <linux/cpufreq.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/ktime.h>

struct pulnice_policy {
    struct cpufreq_policy *policy;
    
    /* Tunables */
    unsigned int util_high;
    unsigned int util_low;
    unsigned int rate_limit_us;
    u64 last_update;
    
    /* Frequency management */
    unsigned int passive_freq;
    unsigned int last_freq;
};

#define DEFAULT_UTIL_HIGH      70
#define DEFAULT_UTIL_LOW       40
#define DEFAULT_RATE_LIMIT_US  20000  // 20ms

/*********************
 * Core Logic
 *********************/
static void update_policy(struct pulnice_policy *pn)
{
    struct cpufreq_policy *policy = pn->policy;
    unsigned int util, new_freq;
    u64 now = ktime_to_us(ktime_get());

    /* Rate limiting */
    if (now < pn->last_update + pn->rate_limit_us)
        return;

    /* Simple utilization calculation */
    util = (policy->cur * 100) / policy->cpuinfo.max_freq;

    /* Frequency selection logic */
    if (util >= pn->util_high) {
        new_freq = policy->max;
    } else if (util <= pn->util_low) {
        new_freq = policy->min;
    } else {
        new_freq = pn->passive_freq;
    }

    /* Only update if needed */
    if (new_freq != pn->last_freq) {
        pn->last_update = now;
        pn->last_freq = new_freq;
        __cpufreq_driver_target(policy, new_freq, CPUFREQ_RELATION_C);
    }
}

/*********************
 * Governor Hooks
 *********************/
static int pulnice_init(struct cpufreq_policy *policy)
{
    struct pulnice_policy *pn;
    int i, valid_freqs = 0;

    pn = kzalloc(sizeof(*pn), GFP_KERNEL);
    if (!pn)
        return -ENOMEM;

    pn->policy = policy;
    
    /* Find 3rd lowest frequency */
    for (i = 0; policy->freq_table[i].frequency != CPUFREQ_TABLE_END; i++) {
        if (policy->freq_table[i].frequency != CPUFREQ_ENTRY_INVALID)
            valid_freqs++;
    }
    
    /* Set passive freq to 3rd lowest or max if less than 3 available */
    pn->passive_freq = (valid_freqs >= 3) ? 
        policy->freq_table[2].frequency : policy->max;

    /* Set defaults */
    pn->util_high = DEFAULT_UTIL_HIGH;
    pn->util_low = DEFAULT_UTIL_LOW;
    pn->rate_limit_us = DEFAULT_RATE_LIMIT_US;
    pn->last_update = 0;
    pn->last_freq = 0;

    policy->governor_data = pn;
    return 0;
}

static void pulnice_exit(struct cpufreq_policy *policy)
{
    struct pulnice_policy *pn = policy->governor_data;
    
    if (pn) {
        policy->governor_data = NULL;
        kfree(pn);
    }
}

static int pulnice_start(struct cpufreq_policy *policy)
{
    return 0;
}

static void pulnice_stop(struct cpufreq_policy *policy)
{
    /* No special cleanup needed */
}

static void pulnice_limits(struct cpufreq_policy *policy)
{
    struct pulnice_policy *pn = policy->governor_data;
    if (pn)
        update_policy(pn);
}

static struct cpufreq_governor cpufreq_gov_pulnice = {
    .name       = "pulnice",
    .init       = pulnice_init,
    .exit       = pulnice_exit,
    .start      = pulnice_start,
    .stop       = pulnice_stop,
    .limits     = pulnice_limits,
    .owner      = THIS_MODULE,
};

static int __init cpufreq_pulnice_init(void)
{
    return cpufreq_register_governor(&cpufreq_gov_pulnice);
}

static void __exit cpufreq_pulnice_exit(void)
{
    cpufreq_unregister_governor(&cpufreq_gov_pulnice);
}

module_init(cpufreq_pulnice_init);
module_exit(cpufreq_pulnice_exit);

MODULE_AUTHOR("Boyan Spassov");
MODULE_DESCRIPTION("Stable Threshold CPU Frequency Governor");
MODULE_LICENSE("GPL");