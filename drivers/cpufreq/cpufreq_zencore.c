/*
 * ZenCore CPU Frequency Governor
 *
 * Features:
 * - Cluster-aware frequency scaling with tunable targets
 * - EAS integration for energy-aware scheduling
 * - Boost on high load with smooth deboost logic
 * - Thermal throttling with hysteresis
 * - Adaptive load smoothing using moving average
 * - Minimal overhead and lightweight design
 */

#include <linux/cpufreq.h>
#include <linux/module.h>
#include <linux/thermal.h>
#include <linux/sched.h>
#include <linux/sched/energy.h>
#include <linux/timer.h>
#include <linux/kernel_stat.h>
#include <linux/slab.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/version.h>

#define GOV_NAME "zencore"
#define BOOST_DURATION_MS 300
#define BOOST_FACTOR 115
#define MAX_STEP_DIVISOR 6
#define HIST_SIZE 4

#define DEFAULT_TARGET_LOAD_LITTLE 55
#define DEFAULT_TARGET_LOAD_BIG 70
#define DEFAULT_ABOVE_HISPEED_DELAY 40000
#define DEFAULT_MIN_SAMPLE_TIME 20000

#define MAX_TEMP_THROTTLE 78
#define MIN_TEMP_RESUME 70
#define CRITICAL_TEMP 85
#define THERMAL_HYSTERESIS 3

struct zencore_cpu_data {
    u64 last_update;
    unsigned int last_freq;
    unsigned int target_freq;
    unsigned int thermal_throttled:1;
    unsigned int boosted:1;
    unsigned int load_history[HIST_SIZE];
    unsigned int hist_index;
};

struct zencore_tunables {
    unsigned int target_load_little;
    unsigned int target_load_big;
    unsigned int above_hispeed_delay;
    unsigned int min_sample_time;
    unsigned int max_temp_throttle;
    unsigned int min_temp_resume;
    unsigned int critical_temp;
    unsigned int boost_threshold;
};

static DEFINE_SPINLOCK(boost_lock);
static struct timer_list boost_timer;
static bool global_boost_active;
static struct kobject *zencore_kobj;
static struct zencore_tunables global_tunables;

static void zencore_boost_end(struct timer_list *t)
{
    spin_lock(&boost_lock);
    global_boost_active = false;
    spin_unlock(&boost_lock);
}

static void zencore_apply_boost(void)
{
    spin_lock(&boost_lock);
    if (!global_boost_active) {
        global_boost_active = true;
        mod_timer(&boost_timer, jiffies + msecs_to_jiffies(BOOST_DURATION_MS));
    }
    spin_unlock(&boost_lock);
}

static unsigned int zencore_calculate_smoothed_load(struct zencore_cpu_data *data, unsigned int new_load)
{
    data->load_history[data->hist_index] = new_load;
    data->hist_index = (data->hist_index + 1) % HIST_SIZE;

    unsigned int sum = 0;
    for (int i = 0; i < HIST_SIZE; i++) {
        sum += data->load_history[i];
    }
    return sum / HIST_SIZE;
}

static unsigned int zencore_get_target_freq(struct cpufreq_policy *policy,
                                           struct zencore_cpu_data *data,
                                           unsigned int load,
                                           unsigned int flags)
{
    unsigned int freq;
    bool is_big = !cpumask_test_cpu(policy->cpu, cpu_lp_mask);
    unsigned int target_load = is_big ?
                              global_tunables.target_load_big :
                              global_tunables.target_load_little;

    if (load < target_load) {
        freq = policy->cur * load / target_load;
    } else {
        freq = policy->cur * load / 100;
        if (global_boost_active || data->boosted) {
            freq = min(policy->cpuinfo.max_freq,
                      (freq * BOOST_FACTOR) / 100);
        }
    }

    unsigned int max_step = policy->max / MAX_STEP_DIVISOR;
    unsigned int delta = abs(freq - data->last_freq);

    if (delta > max_step) {
        freq = (freq > data->last_freq) ?
               min(freq, data->last_freq + max_step) :
               max(freq, data->last_freq - max_step);
    }

    return clamp_val(freq, policy->cpuinfo.min_freq, policy->cpuinfo.max_freq);
}

static void zencore_update(struct cpufreq_policy *policy)
{
    struct zencore_cpu_data *data = policy->governor_data;
    u64 now = ktime_get_ns();
    u64 delta_ns;
    int cpu = smp_processor_id();
    int temp = 0;
    struct thermal_zone_device *tz;
    unsigned int load, freq;
    bool is_big = !cpumask_test_cpu(cpu, cpu_lp_mask);

    tz = thermal_zone_get_zone_by_name("cpu-thermal");
    if (!IS_ERR(tz))
        thermal_zone_get_temp(tz, &temp);
    temp /= 1000;

    if (unlikely(temp >= global_tunables.critical_temp)) {
        freq = policy->cpuinfo.min_freq;
        goto set_freq;
    } else if (temp >= global_tunables.max_temp_throttle) {
        if (!data->thermal_throttled ||
            temp >= (global_tunables.max_temp_throttle + THERMAL_HYSTERESIS)) {
            data->thermal_throttled = 1;
            freq = max(policy->cpuinfo.min_freq, policy->max / 2);
            goto set_freq;
        }
    } else if (temp <= global_tunables.min_temp_resume) {
        data->thermal_throttled = 0;
    }

    if (data->thermal_throttled) {
        freq = max(policy->cpuinfo.min_freq, policy->max / 2);
        goto set_freq;
    }

    delta_ns = now - data->last_update;
    if (delta_ns < global_tunables.min_sample_time * NSEC_PER_USEC)
        return;

    load = sched_get_cpu_util(cpu);

    if (is_big && load > global_tunables.boost_threshold) {
        if (!data->boosted) {
            data->boosted = 1;
            zencore_apply_boost();
        }
    } else {
        data->boosted = 0;
    }

    load = zencore_calculate_smoothed_load(data, load);

    freq = zencore_get_target_freq(policy, data, load, 0);

set_freq:
    if (freq != policy->cur) {
        data->last_freq = policy->cur;
        data->target_freq = freq;
        data->last_update = now;
        __cpufreq_driver_target(policy, freq, CPUFREQ_RELATION_L);
    }
}

static int zencore_start(struct cpufreq_policy *policy)
{
    struct zencore_cpu_data *data;
    int cpu = policy->cpu;

    data = kzalloc(sizeof(*data), GFP_KERNEL);
    if (!data)
        return -ENOMEM;

    data->last_freq = policy->cur;
    data->target_freq = policy->cur;
    data->last_update = ktime_get_ns();
    memset(data->load_history, 0, sizeof(data->load_history));
    data->hist_index = 0;

    policy->governor_data = data;
    return 0;
}

static void zencore_stop(struct cpufreq_policy *policy)
{
    kfree(policy->governor_data);
    policy->governor_data = NULL;
}

static ssize_t show_tunables(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    return sprintf(buf,
        "target_load_little=%u\n"
        "target_load_big=%u\n"
        "above_hispeed_delay=%u\n"
        "min_sample_time=%u\n"
        "max_temp_throttle=%u\n"
        "min_temp_resume=%u\n"
        "critical_temp=%u\n"
        "boost_threshold=%u\n",
        global_tunables.target_load_little,
        global_tunables.target_load_big,
        global_tunables.above_hispeed_delay,
        global_tunables.min_sample_time,
        global_tunables.max_temp_throttle,
        global_tunables.min_temp_resume,
        global_tunables.critical_temp,
        global_tunables.boost_threshold);
}

static ssize_t store_tunables(struct kobject *kobj, struct kobj_attribute *attr,
                             const char *buf, size_t count)
{
    unsigned int val;

    if (sscanf(buf, "target_load_little=%u", &val) == 1) {
        global_tunables.target_load_little = clamp_val(val, 10, 90);
    } else if (sscanf(buf, "target_load_big=%u", &val) == 1) {
        global_tunables.target_load_big = clamp_val(val, 20, 95);
    } else if (sscanf(buf, "above_hispeed_delay=%u", &val) == 1) {
        global_tunables.above_hispeed_delay = clamp_val(val, 10000, 100000);
    } else if (sscanf(buf, "min_sample_time=%u", &val) == 1) {
        global_tunables.min_sample_time = clamp_val(val, 10000, 100000);
    } else if (sscanf(buf, "max_temp_throttle=%u", &val) == 1) {
        global_tunables.max_temp_throttle = clamp_val(val, 60, 90);
    } else if (sscanf(buf, "min_temp_resume=%u", &val) == 1) {
        global_tunables.min_temp_resume = clamp_val(val, 50, 80);
    } else if (sscanf(buf, "critical_temp=%u", &val) == 1) {
        global_tunables.critical_temp = clamp_val(val, 70, 95);
    } else if (sscanf(buf, "boost_threshold=%u", &val) == 1) {
        global_tunables.boost_threshold = clamp_val(val, 50, 95);
    }

    return count;
}

static struct kobj_attribute zencore_attr =
    __ATTR(tunables, 0664, show_tunables, store_tunables);

static int __init zencore_init(void)
{
    global_tunables.target_load_little = DEFAULT_TARGET_LOAD_LITTLE;
    global_tunables.target_load_big = DEFAULT_TARGET_LOAD_BIG;
    global_tunables.above_hispeed_delay = DEFAULT_ABOVE_HISPEED_DELAY;
    global_tunables.min_sample_time = DEFAULT_MIN_SAMPLE_TIME;
    global_tunables.max_temp_throttle = MAX_TEMP_THROTTLE;
    global_tunables.min_temp_resume = MIN_TEMP_RESUME;
    global_tunables.critical_temp = CRITICAL_TEMP;
    global_tunables.boost_threshold = 80;

    timer_setup(&boost_timer, zencore_boost_end, 0);

    if (cpufreq_register_governor(&(struct cpufreq_governor){
        .name = GOV_NAME,
        .start = zencore_start,
        .stop = zencore_stop,
        .limits = zencore_update,
        .owner = THIS_MODULE,
    })) {
        return -ENODEV;
    }

    zencore_kobj = kobject_create_and_add("zencore", kernel_kobj);
    if (zencore_kobj)
        sysfs_create_file(zencore_kobj, &zencore_attr.attr);

    return 0;
}

static void __exit zencore_exit(void)
{
    cpufreq_unregister_governor(&(struct cpufreq_governor){ .name = GOV_NAME });
    if (zencore_kobj) {
        sysfs_remove_file(zencore_kobj, &zencore_attr.attr);
        kobject_put(zencore_kobj);
    }
    del_timer_sync(&boost_timer);
}

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("ZenCore CPU frequency governor");
MODULE_VERSION("2.0");

module_init(zencore_init);
module_exit(zencore_exit);
