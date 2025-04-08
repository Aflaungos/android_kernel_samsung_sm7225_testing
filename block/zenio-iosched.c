// SPDX-License-Identifier: GPL-2.0

#include <linux/blkdev.h>
#include <linux/elevator.h>
#include <linux/bio.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/init.h>

#define DEFAULT_SYNC_RATIO 4

enum {
	SYNC,
	ASYNC
};

struct zenio_data {
	struct list_head queue[2];
	uint8_t sync_ratio;
};

static inline struct request *zenio_next_entry(struct list_head *queue)
{
	return list_first_entry(queue, struct request, queuelist);
}

static void zenio_merged_requests(struct request_queue *q, struct request *rq,
		struct request *next)
{
	list_del_init(&next->queuelist);
}

static inline int __zenio_dispatch(struct request_queue *q, struct request *rq)
{
	if (unlikely(!rq))
		return -EINVAL;

	list_del_init(&rq->queuelist);
	elv_dispatch_sort(q, rq);

	return 0;
}

static uint16_t zenio_dispatch_batch(struct request_queue *q)
{
	struct zenio_data *zdata = q->elevator->elevator_data;
	uint16_t dispatched = 0;
	uint8_t i;

	for (i = 0; i < zdata->sync_ratio; i++) {
		if (list_empty(&zdata->queue[SYNC]))
			break;

		__zenio_dispatch(q, zenio_next_entry(&zdata->queue[SYNC]));
		dispatched++;
	}

	if (!list_empty(&zdata->queue[ASYNC])) {
		__zenio_dispatch(q, zenio_next_entry(&zdata->queue[ASYNC]));
		dispatched++;
	}

	return dispatched;
}

static uint16_t zenio_dispatch_drain(struct request_queue *q)
{
	struct zenio_data *zdata = q->elevator->elevator_data;
	uint16_t dispatched = 0;

	while (!list_empty(&zdata->queue[SYNC])) {
		__zenio_dispatch(q, zenio_next_entry(&zdata->queue[SYNC]));
		dispatched++;
	}

	while (!list_empty(&zdata->queue[ASYNC])) {
		__zenio_dispatch(q, zenio_next_entry(&zdata->queue[ASYNC]));
		dispatched++;
	}

	return dispatched;
}

static int zenio_dispatch(struct request_queue *q, int force)
{
	if (unlikely(force))
		return zenio_dispatch_drain(q);

	return zenio_dispatch_batch(q);
}

static void zenio_add_request(struct request_queue *q, struct request *rq)
{
	const uint8_t dir = rq_is_sync(rq);
	struct zenio_data *zdata = q->elevator->elevator_data;

	list_add_tail(&rq->queuelist, &zdata->queue[dir]);
}

static int zenio_init_queue(struct request_queue *q, struct elevator_type *elv)
{
	struct zenio_data *zdata;
	struct elevator_queue *eq = elevator_alloc(q, elv);

	if (!eq)
		return -ENOMEM;

	zdata = kmalloc_node(sizeof(*zdata), GFP_KERNEL, q->node);
	if (!zdata) {
		kobject_put(&eq->kobj);
		return -ENOMEM;
	}

	eq->elevator_data = zdata;

	INIT_LIST_HEAD(&zdata->queue[SYNC]);
	INIT_LIST_HEAD(&zdata->queue[ASYNC]);
	zdata->sync_ratio = DEFAULT_SYNC_RATIO;

	spin_lock_irq(q->queue_lock);
	q->elevator = eq;
	spin_unlock_irq(q->queue_lock);

	return 0;
}

static ssize_t zenio_sync_ratio_show(struct elevator_queue *e, char *page)
{
	struct zenio_data *zdata = e->elevator_data;
	return snprintf(page, PAGE_SIZE, "%u\n", zdata->sync_ratio);
}

static ssize_t zenio_sync_ratio_store(struct elevator_queue *e,
		const char *page, size_t count)
{
	struct zenio_data *zdata = e->elevator_data;
	int ret = kstrtou8(page, 0, &zdata->sync_ratio);
	if (ret < 0)
		return ret;

	return count;
}

static struct elv_fs_entry zenio_attrs[] = {
	__ATTR(sync_ratio, 0644, zenio_sync_ratio_show, zenio_sync_ratio_store),
	__ATTR_NULL
};

static struct elevator_type elevator_zenio = {
	.ops.sq = {
		.elevator_merge_req_fn	= zenio_merged_requests,
		.elevator_dispatch_fn	= zenio_dispatch,
		.elevator_add_req_fn	= zenio_add_request,
		.elevator_former_req_fn	= elv_rb_former_request,
		.elevator_latter_req_fn	= elv_rb_latter_request,
		.elevator_init_fn	= zenio_init_queue,
	},
	.elevator_name = "zenio",
	.elevator_attrs = zenio_attrs,
	.elevator_owner = THIS_MODULE,
};

static int __init zenio_init(void)
{
	return elv_register(&elevator_zenio);
}

static void __exit zenio_exit(void)
{
	elv_unregister(&elevator_zenio);
}

module_init(zenio_init);
module_exit(zenio_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Zenio I/O scheduler");
