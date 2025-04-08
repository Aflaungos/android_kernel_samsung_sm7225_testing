/*
 * CPU Frequency Governor: Pulnice (Optimized Version)
 * - Performance optimizations
 * - Reduced branch mispredictions
 * - Better cache utilization
 * - Optimized frequency selection logic
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
    unsigned int min_freq;
    unsigned int max_freq;
    unsigned int freq_step;
};

#define DEFAULT_UTIL_HIGH      100
#define DEFAULT_UTIL_LOW       50
#define DEFAULT_RATE_LIMIT_US  20000  // 20ms

/*********************
 * Core Logic - Optimized
 *********************/
static void update_policy(struct pulnice_policy *pn)
{
    struct cpufreq_policy *policy = pn->policy;
    unsigned int util, new_freq;
    u64 now = ktime_get_ns() / NSEC_PER_USEC;

    /* Fast path: rate limiting check first */
    if (likely(now - pn->last_update < pn->rate_limit_us))
        return;

    /* Optimized utilization calculation */
    util = (policy->cur * 100U) / policy->cpuinfo.max_freq;

    /* Branchless frequency selection */
    new_freq = (util >= pn->util_high) ? pn->max_freq :
              ((util <= pn->util_low) ? pn->min_freq : pn->passive_freq);

    /* Only update if needed */
    if (unlikely(new_freq != pn->last_freq)) {
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
    unsigned int min_freq = UINT_MAX, max_freq = 0;

    pn = kzalloc(sizeof(*pn), GFP_KERNEL);
    if (!pn)
        return -ENOMEM;

    pn->policy = policy;
    
    /* Single pass through frequency table to:
     * 1. Count valid frequencies
     * 2. Find min/max frequencies
     */
    for (i = 0; policy->freq_table[i].frequency != CPUFREQ_TABLE_END; i++) {
        unsigned int freq = policy->freq_table[i].frequency;
        if (freq != CPUFREQ_ENTRY_INVALID) {
            valid_freqs++;
            if (freq < min_freq) min_freq = freq;
            if (freq > max_freq) max_freq = freq;
        }
    }
    
    /* Cache min/max frequencies */
    pn->min_freq = min_freq;
    pn->max_freq = max_freq;

    /* Set passive freq to 3rd lowest or max if less than 3 available */
    if (valid_freqs >= 3) {
        unsigned int first = UINT_MAX, second = UINT_MAX, third = UINT_MAX;
        for (i = 0; policy->freq_table[i].frequency != CPUFREQ_TABLE_END; i++) {
            unsigned int freq = policy->freq_table[i].frequency;
            if (freq != CPUFREQ_ENTRY_INVALID) {
                if (freq < first) {
                    third = second;
                    second = first;
                    first = freq;
                } else if (freq < second) {
                    third = second;
                    second = freq;
                } else if (freq < third) {
                    third = freq;
                }
            }
        }
        pn->passive_freq = third;
    } else {
        pn->passive_freq = max_freq;
    }

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
    if (likely(pn)) {
        pn->min_freq = policy->min;
        pn->max_freq = policy->max;
        update_policy(pn);
    }
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
MODULE_DESCRIPTION("Optimized Threshold CPU Frequency Governor");
MODULE_LICENSE("GPL");