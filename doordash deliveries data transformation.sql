WITH
  raw AS (
    SELECT
      delivery_uuid,
      format_timestamp("%F", deliv_created_at, "America/New_York") AS order_date,
      format_timestamp("%u %A", deliv_created_at, "America/New_York") AS order_day_of_week,
      format_timestamp("%T", deliv_created_at, "America/New_York") AS order_time,
      CASE
        WHEN format_timestamp("%T", deliv_created_at, "America/New_York") BETWEEN "06:00:00" AND "11:00:00" THEN "1. Morning"
        WHEN format_timestamp("%T", deliv_created_at, "America/New_York") BETWEEN "11:00:00" AND "13:00:00" THEN "2. Lunch"
        WHEN format_timestamp("%T", deliv_created_at, "America/New_York") BETWEEN "13:00:00" AND "17:00:00" THEN "3. Afternoon"
        WHEN format_timestamp("%T", deliv_created_at, "America/New_York") BETWEEN "17:00:00" AND "21:00:00" THEN "4. Dinner"
        WHEN format_timestamp("%T", deliv_created_at, "America/New_York") BETWEEN "21:00:00" AND "24:00:00" THEN "5. Late Night"
        ELSE "6. Early Morning"
      END AS ordered_time_of_day,
      deliv_store_name,
      deliv_dasher_id,
      deliv_submarket,
      deliv_d2r,
      deliv_is_20_min_late,
      deliv_clat,
      format_timestamp("%F %T", deliv_cancelled_at, "America/New_York") AS deliv_cancelled_at,
      CASE
        WHEN format_timestamp("%T", deliv_cancelled_at, "America/New_York") BETWEEN "06:00:00" AND "11:00:00" THEN "1. Morning"
        WHEN format_timestamp("%T", deliv_cancelled_at, "America/New_York") BETWEEN "11:00:00" AND "13:00:00" THEN "2. Lunch"
        WHEN format_timestamp("%T", deliv_cancelled_at, "America/New_York") BETWEEN "13:00:00" AND "17:00:00" THEN "3. Afternoon"
        WHEN format_timestamp("%T", deliv_cancelled_at, "America/New_York") BETWEEN "17:00:00" AND "21:00:00" THEN "4. Dinner"
        WHEN format_timestamp("%T", deliv_cancelled_at, "America/New_York") BETWEEN "21:00:00" AND "24:00:00" THEN "5. Late Night"
        WHEN deliv_cancelled_at IS null THEN null
        ELSE "6. Early Morning"
      END AS cancelation_time_of_day,
      deliv_missing_incorrect_report,
      was_requested,
      was_missing,
      was_subbed,
      was_found,
      item_name,
      item_price,
      item_category,
      substitute_item_name,
      substitute_item_category
    FROM
      `doordashdeliveries.deliveries`
  ),
  items_per_order AS (
    SELECT
      delivery_uuid,
      deliv_store_name,
      ordered_time_of_day,
      count(item_category) AS count_items_sold,
      round(sum(item_price), 2) AS order_total,
      round(sum(item_price) / count(item_category), 2) AS avg_item_cost
    FROM
      raw
    GROUP BY 1, 2, 3
    ORDER BY 6 DESC
  ),
  avg_orders_by_time_of_day AS (
    SELECT
      deliv_store_name,
      ordered_time_of_day,
      round(avg(count_items_sold), 1) AS avg_items_per_order
    FROM
      items_per_order
    GROUP BY 1, 2
    ORDER BY 1, 2
  ),
  late_deliveries_by_time_of_day AS (
    SELECT
      deliv_store_name,
      ordered_time_of_day,
      round(avg(deliv_d2r), 2) AS avg_d2r,
      round(avg(deliv_clat), 2) AS avg_deliv_clat,
      sum(deliv_is_20_min_late) AS num_late_orders,
      sum(`if`(deliv_missing_incorrect_report IS TRUE, 1, 0)) AS num_complaints,
      round(sum(deliv_is_20_min_late) / count(delivery_uuid) * 100, 2) AS pct_late_orders,
      round(sum(`if`(deliv_missing_incorrect_report IS TRUE, 1, 0)) / count(delivery_uuid) * 100, 2) AS pct_complaints
    FROM
      raw
    GROUP BY 1, 2
    ORDER BY 1, 2
  )
SELECT
  *
FROM
  late_deliveries_by_time_of_day