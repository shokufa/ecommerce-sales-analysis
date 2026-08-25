-- E-commerce Sales & Customer Analytics
-- SQL Analysis
-- Database: SQLite
-- Source: Cleaned UCI Online Retail transactions


-- Database validation
SELECT COUNT(*) AS total_rows
FROM transactions;

-- Transaction type validation
SELECT
    TransactionType,
    COUNT(*) AS row_count
FROM transactions
GROUP BY TransactionType
ORDER BY row_count DESC;

-- 1. Monthly Sales Performance

SELECT
    strftime('%Y-%m', InvoiceDate) AS month,

    ROUND(
        SUM(
            CASE
                WHEN TransactionType = 'Paid Sale'
                THEN Revenue
                ELSE 0
            END
        ),
        2
    ) AS gross_revenue,

    ROUND(
        SUM(
            CASE
                WHEN TransactionType = 'Cancellation'
                THEN -Revenue
                ELSE 0
            END
        ),
        2
    ) AS cancellation_value,

    ROUND(
        SUM(
            CASE
                WHEN TransactionType IN ('Paid Sale', 'Cancellation')
                THEN Revenue
                ELSE 0
            END
        ),
        2
    ) AS net_transaction_revenue,

    COUNT(
        DISTINCT CASE
            WHEN TransactionType = 'Paid Sale'
            THEN InvoiceNo
        END
    ) AS paid_orders

FROM transactions

GROUP BY strftime('%Y-%m', InvoiceDate)

ORDER BY month;



-- 2. Country Performance

WITH country_sales AS (
    SELECT
        Country,
        SUM(Revenue) AS gross_revenue,
        COUNT(DISTINCT InvoiceNo) AS orders
    FROM transactions
    WHERE TransactionType = 'Paid Sale'
    GROUP BY Country
)

SELECT
    Country,

    ROUND(gross_revenue, 2) AS gross_revenue,

    orders,

    ROUND(
        gross_revenue / orders,
        2
    ) AS average_order_value,

    ROUND(
        gross_revenue
        / SUM(gross_revenue) OVER ()
        * 100,
        2
    ) AS revenue_share_pct

FROM country_sales

ORDER BY gross_revenue DESC;

-- 3. Top Product Performance

WITH description_frequency AS (

    SELECT
        StockCode,
        Description,
        COUNT(*) AS description_count

    FROM transactions

    WHERE TransactionType = 'Paid Sale'
      AND Description IS NOT NULL
      AND TRIM(Description) <> ''
      AND StockCode NOT IN (
          'DOT',
          'POST',
          'M',
          'B',
          'AMAZONFEE'
      )

    GROUP BY
        StockCode,
        Description
),

ranked_descriptions AS (

    SELECT
        StockCode,
        Description,

        ROW_NUMBER() OVER (
            PARTITION BY StockCode
            ORDER BY description_count DESC, Description ASC
        ) AS description_rank

    FROM description_frequency
),

product_performance AS (

    SELECT
        StockCode,

        SUM(
            CASE
                WHEN TransactionType = 'Paid Sale'
                THEN Revenue
                ELSE 0
            END
        ) AS gross_revenue,

        SUM(
            CASE
                WHEN TransactionType = 'Cancellation'
                THEN -Revenue
                ELSE 0
            END
        ) AS cancellation_value

    FROM transactions

    WHERE StockCode NOT IN (
        'DOT',
        'POST',
        'M',
        'B',
        'AMAZONFEE'
    )

    GROUP BY StockCode
)

SELECT
    p.StockCode,
    d.Description,

    ROUND(
        p.gross_revenue,
        2
    ) AS gross_revenue,

    ROUND(
        p.cancellation_value,
        2
    ) AS cancellation_value,

    ROUND(
        p.gross_revenue - p.cancellation_value,
        2
    ) AS net_revenue

FROM product_performance AS p

LEFT JOIN ranked_descriptions AS d
    ON p.StockCode = d.StockCode
   AND d.description_rank = 1

WHERE p.gross_revenue > 0

ORDER BY net_revenue DESC

LIMIT 10;

-- 4. Average Order Value

WITH order_values AS (
    SELECT
        InvoiceNo,
        SUM(Revenue) AS order_value
    FROM transactions
    WHERE TransactionType = 'Paid Sale'
    GROUP BY InvoiceNo
)

SELECT
    COUNT(*) AS total_orders,

    ROUND(
        AVG(order_value),
        2
    ) AS average_order_value

FROM order_values;

-- 5. Top Customers by Net Revenue

WITH customer_performance AS (
    SELECT
        CustomerID,

        COUNT(
            DISTINCT CASE
                WHEN TransactionType = 'Paid Sale'
                THEN InvoiceNo
            END
        ) AS orders,

        SUM(
            CASE
                WHEN TransactionType = 'Paid Sale'
                THEN Revenue
                ELSE 0
            END
        ) AS gross_revenue,

        SUM(
            CASE
                WHEN TransactionType = 'Cancellation'
                THEN -Revenue
                ELSE 0
            END
        ) AS cancellation_value

    FROM transactions

    WHERE CustomerID IS NOT NULL

    GROUP BY CustomerID
)

SELECT
    CustomerID,
    orders,

    ROUND(
        gross_revenue,
        2
    ) AS gross_revenue,

    ROUND(
        cancellation_value,
        2
    ) AS cancellation_value,

    ROUND(
        gross_revenue - cancellation_value,
        2
    ) AS net_revenue

FROM customer_performance

WHERE orders > 0

ORDER BY net_revenue DESC

LIMIT 10;

-- 6. Repeat Customer Analysis

WITH customer_performance AS (

    SELECT
        CustomerID,

        COUNT(
            DISTINCT CASE
                WHEN TransactionType = 'Paid Sale'
                THEN InvoiceNo
            END
        ) AS paid_orders,

        SUM(
            CASE
                WHEN TransactionType = 'Paid Sale'
                THEN Revenue
                ELSE 0
            END
        ) AS gross_revenue,

        SUM(
            CASE
                WHEN TransactionType = 'Cancellation'
                THEN -Revenue
                ELSE 0
            END
        ) AS cancellation_value

    FROM transactions

    WHERE CustomerID IS NOT NULL

    GROUP BY CustomerID
),

customer_types AS (

    SELECT
        CustomerID,

        CASE
            WHEN paid_orders = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_type,

        gross_revenue - cancellation_value AS net_revenue

    FROM customer_performance

    WHERE paid_orders > 0
),

type_summary AS (

    SELECT
        customer_type,
        COUNT(*) AS customers,
        SUM(net_revenue) AS net_revenue

    FROM customer_types

    GROUP BY customer_type
),

total_revenue AS (

    SELECT
        SUM(net_revenue) AS total_net_revenue

    FROM type_summary
)

SELECT
    customer_type,

    customers,

    ROUND(
        net_revenue,
        2
    ) AS net_revenue,

    ROUND(
        net_revenue * 100.0 /
        total_net_revenue,
        2
    ) AS net_revenue_share_pct

FROM type_summary

CROSS JOIN total_revenue

ORDER BY customer_type;

-- 7. Monthly Revenue Growth

WITH monthly_revenue AS (

    SELECT
        strftime('%Y-%m', InvoiceDate) AS month,

        SUM(
            CASE
                WHEN TransactionType = 'Paid Sale'
                THEN Revenue
                ELSE 0
            END
        ) AS revenue

    FROM transactions

    GROUP BY strftime('%Y-%m', InvoiceDate)
),

monthly_with_previous AS (

    SELECT
        month,
        revenue,

        LAG(revenue) OVER (
            ORDER BY month
        ) AS previous_revenue

    FROM monthly_revenue
)

SELECT
    month,

    ROUND(
        revenue,
        2
    ) AS revenue,

    CASE
        WHEN month = '2011-12' THEN NULL

        ELSE ROUND(
            (revenue - previous_revenue)
            * 100.0
            / NULLIF(previous_revenue, 0),
            2
        )
    END AS mom_growth_pct,

    CASE
        WHEN month = '2011-12'
        THEN 'Partial month'
        ELSE 'Complete month'
    END AS period_status

FROM monthly_with_previous

ORDER BY month;