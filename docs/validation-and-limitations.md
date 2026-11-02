# Validation and limitations

## What I checked

| Check | How | Result |
|---|---|---|
| Reconciliation | On-time plus late equals the final population; the final population plus every exclusion step equals all orders | 89,258 + 6,378 = 95,636; 95,636 + 2,963 + 8 + 1 + 188 + 645 = 99,441 |
| One row per order | `COUNT(*)` versus `COUNT(DISTINCT order_id)` on the final data | Both 95,636, so orders with several reviews are not double counted |
| Hand check | 10 orders (2 clearly on time, 2 clearly late, 4 delivered on the estimated day, 2 delivered one day after). I read the delivered and estimated dates in the raw CSV, decided on time or late myself, then compared with the SQL label | All 10 match, including the edge cases (same day, one day after, delivered 32 minutes after midnight) |
| Independent recount | Group sizes, low-score rates and the percentiles of prep and transit days recomputed outside the database from the raw CSV files | Match the SQL and the Excel summary exactly |
| Sensitivity test | For orders with several reviews, keep the last review (by answer time) instead of the lowest. All 547 multi-review orders have a unique latest answer time. For 89 of them the last review differs from the lowest | Late group: 4,676 / 6,378 = 73.31% (unchanged). On-time group: 15,476 / 89,258 = 17.34% (was 17.39%, 42 fewer low scores). The conclusion does not change |

## Limitations

Each limit is written as what it is and how it could affect the conclusion.

1. **Time and place.** The data is Brazilian marketplace orders from 2016 to 2018. It describes that period only and cannot be applied directly to current logistics or to other countries.
2. **It cannot show why orders are slow.** It shows that orders are late and roughly which stage is slow, not the exact cause (distance, carrier, peak season and sellers are all possible). Finding the cause needs input from the logistics team or the platform, or more data such as location.
3. **Association, not cause.** Late orders and low scores appear together, but low scores can also come from product defects or wrong items, and a third factor such as remote delivery areas could raise both. The analysis shows that the pattern is consistent, not that lateness causes low scores.
4. **Excluded data.** 3,805 orders were excluded, 3.83% of all orders. Of these, 2,963 (about 3.0%) were not delivered or were canceled, so they are outside the question anyway. Only 842 (about 0.85%) were excluded for data problems or because they had no review. Data-quality exclusions are under 1%, so their effect on the conclusion is small.
5. **Lowest score per order.** 547 orders (about 0.55%) have two or three reviews, and I keep the lowest score. This pushes the low-score rate up slightly in both groups. I chose it because the goal is to find low scores. The effect is small, and the last-review sensitivity test above shows the on-time rate moving only from 17.39% to 17.34% with the late rate unchanged.
6. **Late is compared by date only.** The estimated delivery date has no time of day (00:00:00), so any delivery on the estimated day counts as on time, even a very late one. Some of those customers waited the whole day and may have given a low score, which puts them in the on-time group. That raises the on-time group's low-score rate slightly and makes the gap slightly smaller than the true one, so this definition errs on the conservative side. Some of those orders may also be genuine logistics problems that go unnoticed.
7. **Thresholds are my own.** The definition of late (by date), the definition of low score (1 to 3 stars) and the decision lines (the late group's rate above 50% or at least twice the on-time rate; a gap under 5 percentage points means no relation) are my own judgment, not an industry standard. The benefit is that I set them before seeing any result, so I could not adjust them afterwards. If a 3 star review were treated as neutral and only 1 and 2 stars counted as low, the rates would fall. I did not rerun that.
8. **Customers with no rating are not included.** 645 delivered orders have no review, about 0.65%, so their opinion is unknown. As a worst-case check: if all 645 were added to the late group with no low score, the late group's low-score rate would still be 66.6% (4,676 / 7,023), about 3.8 times the on-time rate of 17.4%. If all were added to the on-time group as low scores, the on-time rate would only rise to 18.0% (16,163 / 89,903). The conclusion holds in both extremes.
9. **Only two tables.** The analysis uses orders and reviews only. Product category, seller, customer location and price are not controlled for, so their effects cannot be seen. They are natural next steps.
