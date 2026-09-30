/* Private Z04 control. Read only; run against RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'Z04: date and channel coverage';
SELECT N'Sales' AS SourceName, MIN(d.[Date]) AS FirstDate, MAX(d.[Date]) AS LastDate,
       COUNT(DISTINCT d.[Date]) AS DistinctDates
FROM dbo.FactSales AS f JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
UNION ALL
SELECT N'Returns', MIN(d.[Date]), MAX(d.[Date]), COUNT(DISTINCT d.[Date])
FROM dbo.FactReturns AS r JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey;

PRINT N'Z04: channel return rate, same full history';
WITH Sold AS (
    SELECT st.Channel, SUM(f.Quantity) AS SoldUnits
    FROM dbo.FactSales AS f
    JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
    GROUP BY st.Channel
), Returned AS (
    SELECT st.Channel, SUM(r.Quantity) AS ReturnedUnits,
           SUM(r.ReturnAmount) / 1.23 AS ReturnedNet
    FROM dbo.FactReturns AS r
    JOIN dbo.DimStore AS st ON st.StoreKey = r.StoreKey
    GROUP BY st.Channel
)
SELECT s.Channel, s.SoldUnits, r.ReturnedUnits, r.ReturnedNet,
       CAST(100.0 * r.ReturnedUnits / NULLIF(s.SoldUnits, 0) AS DECIMAL(8,2)) AS ReturnRatePct
FROM Sold AS s JOIN Returned AS r ON r.Channel = s.Channel
ORDER BY s.Channel;

PRINT N'Z04: online products by return rate, minimum 100 sold units';
WITH Sold AS (
    SELECT p.StyleCode, p.StyleName, SUM(f.Quantity) AS SoldUnits
    FROM dbo.FactSales AS f
    JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
    WHERE st.Channel = N'ONLINE'
    GROUP BY p.StyleCode, p.StyleName
), Returned AS (
    SELECT p.StyleCode, SUM(r.Quantity) AS ReturnedUnits
    FROM dbo.FactReturns AS r
    JOIN dbo.DimStore AS st ON st.StoreKey = r.StoreKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
    WHERE st.Channel = N'ONLINE'
    GROUP BY p.StyleCode
)
SELECT s.StyleCode, s.StyleName, s.SoldUnits, r.ReturnedUnits,
       CAST(100.0 * r.ReturnedUnits / NULLIF(s.SoldUnits, 0) AS DECIMAL(8,2)) AS ReturnRatePct
FROM Sold AS s JOIN Returned AS r ON r.StyleCode = s.StyleCode
WHERE s.SoldUnits >= 100
ORDER BY ReturnRatePct DESC, s.SoldUnits DESC;

PRINT N'Z04: online reasons for top returned product and all other products';
WITH TopProduct AS (
    SELECT TOP (1) p.StyleCode
    FROM dbo.FactReturns AS r
    JOIN dbo.DimStore AS st ON st.StoreKey = r.StoreKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
    WHERE st.Channel = N'ONLINE'
    GROUP BY p.StyleCode
    ORDER BY SUM(r.Quantity) DESC
)
SELECT CASE WHEN p.StyleCode IN (SELECT StyleCode FROM TopProduct) THEN N'top-returned-style' ELSE N'other-styles' END AS ProductGroup,
       r.ReturnReason, SUM(r.Quantity) AS ReturnedUnits
FROM dbo.FactReturns AS r
JOIN dbo.DimStore AS st ON st.StoreKey = r.StoreKey
JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
WHERE st.Channel = N'ONLINE'
GROUP BY CASE WHEN p.StyleCode IN (SELECT StyleCode FROM TopProduct) THEN N'top-returned-style' ELSE N'other-styles' END,
         r.ReturnReason
ORDER BY ProductGroup, ReturnedUnits DESC;
