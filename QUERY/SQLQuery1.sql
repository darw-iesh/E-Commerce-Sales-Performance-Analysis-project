USE [E-Commerce_Sales_Performance_Analysis]

-- Cleaning Data and remove duplicates Take column by column
SELECT *
FROM
(
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY CustomerID
               ORDER BY Country
           ) AS rn
    FROM [Online Retail2]
) t
WHERE rn > 1 AND UPPER(InvoiceNo) Like 'C%'

-- InvoiceNo Drop a cancellation and CustomerID is NULL
SELECT * 
FROM [Online Retail2]
WHERE UPPER(InvoiceNo) LIKE 'C%'

IF OBJECT_ID('retails', 'U') IS NOT NULL DROP TABLE retails;
SELECT * 
INTO retails
FROM [Online Retail2]

DELETE FROM retails
WHERe UPPER(InvoiceNo) LIKE 'C%'
OR CustomerID IS NULL

SELECT * FROM retails
WHERE UnitPrice<=0

SELECT DISTINCT StockCode FROM retails
WHERE len(StockCode)<5
/*
Notes
Stock Code
StockCode is meant to follow the pattern [0-9]{5} but seems to have legit values for [0-9]{5}[a-zA-Z]+
Also contains other values: | Code | Description | Action | 
| DCGS | Looks valid, some quantities are negative though and customer ID is null 
| Exclude from clustering | | D | Looks valid, represents discount values | Exclude from clustering | 
| DOT | Looks valid, represents postage charges | Exclude from clustering | 
| M or m | Looks valid, represents manual transactions | Exclude from clustering | 
| C2 | Carriage transaction - not sure what this means | Exclude from clustering |
| C3 | Not sure, only 1 transaction | Exclude | | BANK CHARGES or B | Bank charges | Exclude from clustering |
| S | Samples sent to customer | Exclude from clustering | | TESTXXX | Testing data, not valid | Exclude from clustering | 
| gift__XXX | Purchases with gift cards, might be interesting for another analysis, but no customer data | Exclude | 
| PADS | Looks like a legit stock code for padding | Include | | SP1002 | Looks like a special request item, only 2 transactions, 3 look legit, 1 has 0 pricing | Exclude for now| 
| AMAZONFEE | Looks like fees for Amazon shipping or something | Exclude for now | | ADJUSTX | Looks like manual account adjustments by admins | Exclude for now |
*/
DELETE
FROM [retails]
WHERE StockCode  IN
(
'DCGS',
'D',
'DOT',
'M',
'm',
'C2',
'C3',
'BANK CHARGES',
'B',
'S',
'SP1002',
'AMAZONFEE',
'ADJUST'
)
or StockCode  LIKE 'TEST%'
or StockCode  LIKE 'gift%';

-- Unite Price Column Cleaning

WITH PriceCTE AS
(
    SELECT *,
          
               AVG(NULLIF(UnitPrice, 0)) OVER (PARTITION BY Description) AS AvgPrice
    FROM retails
)

UPDATE PriceCTE
SET UnitPrice = AvgPrice
WHERE UnitPrice = 0;


-- CustomerID check cleaning
SELECT CustomerID FROM retails
WHERE LEN(CustomerID) >5


--•	Calculate total revenue and monitor monthly sales performance.
SELECT YEAR(InvoiceDate) AS SalesYear
FROM retails
GROUP BY YEAR(InvoiceDate) 

SELECT
    YEAR(InvoiceDate) AS SalesYear,
    MONTH(InvoiceDate) AS SalesMonth,
    DATENAME(MONTH, InvoiceDate) AS MonthName,
    ROUND(SUM(Quantity * UnitPrice), 2) AS TotalRevenue
FROM retails
GROUP BY
    YEAR(InvoiceDate),
    MONTH(InvoiceDate),
    DATENAME(MONTH, InvoiceDate)
ORDER BY
    SalesYear,
    SalesMonth;

--• Monthly growth
SELECT
    YEAR(InvoiceDate) AS SalesYear,
    MONTH(InvoiceDate) AS SalesMonth,
    SUM(Quantity*UnitPrice) AS Revenue,
    LAG(SUM(Quantity*UnitPrice))
        OVER(
            ORDER BY YEAR(InvoiceDate),
                     MONTH(InvoiceDate)
        ) AS PreviousRevenue
FROM retails
GROUP BY
    YEAR(InvoiceDate),
    MONTH(InvoiceDate);


--• Identify the best-selling and highest-revenue products.
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS TotalQuantitySold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS TotalRevenue
FROM retails
GROUP BY
    StockCode,
    Description
ORDER BY TotalRevenue DESC;


--•	Analyze customer purchasing behavior and repeat purchase frequency.
SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    SUM(Quantity) AS TotalItemsPurchased,
    ROUND(SUM(Quantity * UnitPrice), 2) AS TotalSpent
FROM retails
GROUP BY CustomerID
ORDER BY TotalSpent DESC;


--•	Rank customers based on lifetime spending.
SELECT
    CustomerID,
    ROUND(SUM(Quantity * UnitPrice), 2) AS TotalSpent,
    DENSE_RANK() OVER (
        ORDER BY SUM(Quantity * UnitPrice) DESC
    ) AS CustomerRank
FROM retails
GROUP BY CustomerID
ORDER BY CustomerRank;


--•	Evaluate sales performance across different countries.
SELECT
    Country,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    COUNT(DISTINCT CustomerID) AS TotalCustomers,
    SUM(Quantity) AS TotalItemsSold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS TotalRevenue
FROM retails
GROUP BY Country
ORDER BY TotalRevenue DESC;

--•	Generate business insights to support revenue optimization and customer retention strategies.
--Average Order Value
SELECT
    ROUND(
        SUM(Quantity * UnitPrice) /
        COUNT(DISTINCT InvoiceNo),2
    ) AS Average_Order_Value
FROM retails ;

--Best Selling Products
SELECT TOP 10
    Description,
    SUM(Quantity) AS Units_Sold,
    ROUND(SUM(Quantity * UnitPrice),2) AS Revenue
FROM retails
GROUP BY Description
ORDER BY Revenue DESC;

--Low Performing Products
SELECT TOP 10
    Description,
    SUM(Quantity) AS Units_Sold,
    ROUND(SUM(Quantity * UnitPrice),2) AS Revenue
FROM retails
GROUP BY Description
ORDER BY Revenue;

-- Customer Retention
SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS Orders
FROM retails
GROUP BY CustomerID
HAVING COUNT(DISTINCT InvoiceNo) > 1
ORDER BY Orders DESC;

--Cancellation Impact
SELECT
    ROUND(ABS(SUM(Quantity * UnitPrice)),2) AS Revenue_Lost
FROM [Online Retail2]
WHERE InvoiceNo LIKE 'C%';

--Monthly New Customers
WITH FirstPurchase AS
(
    SELECT
        CustomerID,
        MIN(InvoiceDate) AS FirstPurchaseDate
    FROM retails
    GROUP BY CustomerID
)

SELECT
    YEAR(FirstPurchaseDate) AS Year,
    MONTH(FirstPurchaseDate) AS Month,
    COUNT(*) AS New_Customers
FROM FirstPurchase
GROUP BY
    YEAR(FirstPurchaseDate),
    MONTH(FirstPurchaseDate)
ORDER BY
    Year,
    Month;