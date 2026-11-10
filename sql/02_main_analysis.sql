-- Olist: main analysis (2026-10-26)
-- Question: are late deliveries linked to more low review scores, and is the delay in the prep stage or the transit stage?
-- Built on the clean merged data (01_clean_and_merge.sql, 95,636 orders, one row per order).
-- Both queries were checked against an independent recount from the raw CSVs.
--
-- Definitions (fixed before looking at results, see analysis-log.md):
--   late     = delivered DATE is later than estimated DATE (both cast with ::date); otherwise on_time
--   low score = lowest review score of the order is 1 to 3
--   prep stage    = carrier date - purchase time, in days
--   transit stage = customer delivery date - carrier date, in days
-- Note: percentile_cont returns double precision, so use ::numeric before round(..., 1).

-- Query 1. Low-score share by group
-- Expected: late 6,378 orders / 4,676 low / 73.31%; on_time 89,258 / 15,518 / 17.39%; all_num 95,636
-- pct_of_all is the share of low-score orders within each group (the name is misleading; it is not a share of all orders).
with clean_and_merge as(
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
),
 d as(
	select *,
		case when order_delivered_customer_date::date <= order_estimated_delivery_date::date
				then 'on_time'
				else 'late' end as delivery_status
	from clean_and_merge
	)
select delivery_status,
	count(*) as n,
	sum(count(*))over() as all_num,
	count(*) filter (where lowest_review_score <= 3) as low_score_count,
	round(100.0 * count(*) filter (where lowest_review_score <= 3)/count(*),2) as pct_of_all
from d
group by delivery_status;

-- Query 2. Prep stage and transit stage days by group (p25, p50, p75, p90)
-- Expected p50: prep late 3.5 / on_time 2.1; transit late 26.1 / on_time 6.9
-- Expected n: late 6,378 / on_time 89,258; no negative days.
with clean_and_merge as(
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
),
 d as(
	select *,
		case when order_delivered_customer_date::date <= order_estimated_delivery_date::date
				then 'on_time'
				else 'late' end as delivery_status,
		extract(epoch from (order_delivered_carrier_date - order_purchase_timestamp))/86400 as prep_days,
		extract(epoch from (order_delivered_customer_date - order_delivered_carrier_date))/86400 as transit_days
	from clean_and_merge
	)
select delivery_status,
	count(*) as n,
	percentile_cont(0.25) within group (order by prep_days) as prep_p25,
	percentile_cont(0.5) within group (order by prep_days) as prep_p50,
	percentile_cont(0.75) within group (order by prep_days) as prep_p75,
	percentile_cont(0.90) within group (order by prep_days) as prep_p90,
	percentile_cont(0.25) within group (order by transit_days) as transit_p25,
	percentile_cont(0.5) within group (order by transit_days) as transit_p50,
	percentile_cont(0.75) within group (order by transit_days) as transit_p75,
	percentile_cont(0.90) within group (order by transit_days) as transit_p90
from d
group by delivery_status;
