-- Olist: clean and merge orders + reviews (2026-10-26)
-- Two queries below, checked against an independent recount.
--
-- Rules (see data-notes.md section 7):
--   1. keep only delivered orders that have a delivered-to-customer date and a handed-to-carrier date
--   2. drop orders whose timestamps contradict each other (customer delivery before carrier, or carrier before purchase)
--   3. one review per order: keep the lowest score
--   4. inner join on order_id, so orders without any review drop out
-- Equal timestamps are kept (>=), because the rule only excludes "earlier".

-- Query 1. Clean merged data (one row per order). Expected rows: 95,636
with lowest_review as(
	select order_id, min(review_score) as lowest_review_score
	from olist_order_reviews_dataset oord
	group by order_id
),
filtered_orders as(
	select *
	from olist_orders_dataset ood
	where order_status = 'delivered'
		and ood.order_delivered_customer_date is not null
		and ood.order_delivered_carrier_date is not null
		and ood.order_delivered_customer_date >= ood.order_delivered_carrier_date
		and ood.order_delivered_carrier_date >= order_purchase_timestamp
)
select f.order_id, f.order_purchase_timestamp, f.order_delivered_carrier_date,
	f.order_delivered_customer_date, f.order_estimated_delivery_date, l.lowest_review_score
from filtered_orders f
join lowest_review l
on f.order_id = l.order_id;

-- Query 2. Exclusion funnel: orders remaining after each cumulative step, rows removed, and % of all orders
-- Expected count: 99,441 / 96,478 / 96,470 / 96,469 / 96,281 / 95,636
-- Expected removed: NULL / 2,963 / 8 / 1 / 188 / 645 (sum 3,805); pct_of_all: NULL / 2.98 / 0.01 / 0 / 0.19 / 0.65
-- step_no is a number (not quoted) so ORDER BY sorts numerically; 100.0 avoids integer division.
with funnel as (
	with a as(
		with lowest_review as(
					select order_id, min(review_score) as lowest_review_score
					from olist_order_reviews_dataset oord
					group by order_id
				),
				filtered_orders as(
					select *
					from olist_orders_dataset ood
					where order_status = 'delivered'
						and ood.order_delivered_customer_date is not null
						and ood.order_delivered_carrier_date is not null
						and ood.order_delivered_customer_date >= ood.order_delivered_carrier_date
						and ood.order_delivered_carrier_date >= order_purchase_timestamp
				)
			select f.order_id, f.order_purchase_timestamp,f.order_delivered_carrier_date, f.order_delivered_customer_date, f.order_estimated_delivery_date, l.lowest_review_score
			from filtered_orders f
			join lowest_review l
			on f.order_id = l.order_id
		)
		select 1 as step_no, 'All orders' as label, count(*) from olist_orders_dataset ood
		union all
		select 2 as step_no,'order_status_is_delivered' as label, count(*) from olist_orders_dataset ood
		where ood.order_status = 'delivered'
		union all
		select 3 as step_no,'order_delivered_customer_is_not_null' as label, count(*) from olist_orders_dataset ood
		where ood.order_status = 'delivered' and ood.order_delivered_customer_date is not null
		union all
		select 4 as step_no,'order_delivered_carrier_is_not_null' as label, count(*) from olist_orders_dataset ood
		where ood.order_status = 'delivered'
			and ood.order_delivered_customer_date is not null
			and ood.order_delivered_carrier_date is not null
		union all
		select 5 as step_no,'order_delivered_date_not_odd' as label, count(*) from olist_orders_dataset ood
		where ood.order_status = 'delivered'
			and ood.order_delivered_customer_date is not null
			and ood.order_delivered_carrier_date is not null
			and ood.order_delivered_customer_date >= ood.order_delivered_carrier_date
			and ood.order_delivered_carrier_date >= order_purchase_timestamp
		union all
		select 6 as step_no,'review_score_is_not_null' as label, count(*) from a
		order by step_no
)
select step_no,
		label,
		count,
		lag(count) over(order by step_no) - count as removed,
		round(100.0 * (lag(count) over (order by step_no) - count)/first_value(count) over(order by step_no),2) as pct_of_all
		from funnel
		order by step_no;
