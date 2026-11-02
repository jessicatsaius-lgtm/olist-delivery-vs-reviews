-- Olist: sensitivity test, keep the LAST review per order instead of the lowest (2026-10-29)
-- Question: does the main result change if an order with several reviews uses its latest review score?
-- Only the review step differs from 02_main_analysis.sql Query 1; filtered_orders, grouping and the low-score rule are unchanged.
-- Written by Jessica: ranked_reviews (row_number over review_answer_timestamp desc, checked: 98,673 orders, no ties on the latest time).
-- Written by Claude at Jessica's request: wiring it into the full query.
-- Main result to compare with: late 6,378 / 4,676 low / 73.31%; on_time 89,258 / 15,518 / 17.39%.

with ranked_reviews as(
	select order_id,
		review_score,
		row_number() over(partition by order_id order by review_answer_timestamp desc) as row_num
	from olist_order_reviews_dataset oord
),
last_review as(
	select order_id, review_score as last_review_score
	from ranked_reviews
	where row_num = 1
),
filtered_orders as(
	select *
	from olist_orders_dataset ood
	where order_status = 'delivered'
		and ood.order_delivered_customer_date is not null
		and ood.order_delivered_carrier_date is not null
		and ood.order_delivered_customer_date >= ood.order_delivered_carrier_date
		and ood.order_delivered_carrier_date >= order_purchase_timestamp
),
d as(
	select f.order_id,
		l.last_review_score,
		case when f.order_delivered_customer_date::date <= f.order_estimated_delivery_date::date
				then 'on_time'
				else 'late' end as delivery_status
	from filtered_orders f
	join last_review l
	on f.order_id = l.order_id
)
select delivery_status,
	count(*) as n,
	sum(count(*)) over() as all_num,
	count(*) filter (where last_review_score <= 3) as low_score_count,
	round(100.0 * count(*) filter (where last_review_score <= 3) / count(*), 2) as low_score_pct
from d
group by delivery_status;
