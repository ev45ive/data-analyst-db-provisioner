/* Private, read-only measurement for the copied seed. Run on the isolated new DB. */
SET NOCOUNT ON;

PRINT N'E01: weekly sales by channel';
SELECT d.YearWeek,
       st.Channel,
       COUNT(DISTINCT d.Date) AS DaysWithSales,
       SUM(f.Quantity) AS Units,
       COUNT(DISTINCT f.TransactionNo) AS Transactions,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek, st.Channel
ORDER BY d.YearWeek, st.Channel;

PRINT N'E01: independent SQL route through reporting view';
SELECT YearWeek,
       Channel,
       CAST(SUM(NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM reporting.vw_SalesDaily
WHERE YearWeek IN ('2026-W37', '2026-W38')
GROUP BY YearWeek, Channel
ORDER BY YearWeek, Channel;

PRINT N'E01: calendar completeness';
SELECT YearWeek, COUNT(*) AS CalendarDays
FROM dbo.DimDate
WHERE YearWeek IN ('2026-W37', '2026-W38')
GROUP BY YearWeek
ORDER BY YearWeek;

PRINT N'E02: August rows by layer';
SELECT N'src.SalesRaw' AS Layer, COUNT(*) AS RowsInAugust
FROM src.SalesRaw
WHERE SalesDate LIKE N'2026-08-%'
UNION ALL
SELECT N'stg.Sales', COUNT(*) FROM stg.Sales
WHERE SalesDate >= '2026-08-01' AND SalesDate < '2026-09-01'
UNION ALL
SELECT N'dbo.FactSales', COUNT(*) FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
WHERE d.Date >= '2026-08-01' AND d.Date < '2026-09-01';

PRINT N'E02: August value by source, staging, fact and report';
SELECT N'src.SalesRaw' AS Layer,
       CAST(SUM(CAST((TRY_CONVERT(INT, Quantity) * TRY_CONVERT(DECIMAL(10, 2), UnitPrice)
                     - TRY_CONVERT(DECIMAL(10, 2), DiscountAmount)) / 1.23 AS DECIMAL(12, 2))) AS DECIMAL(14, 2)) AS NetAmount
FROM src.SalesRaw WHERE SalesDate LIKE N'2026-08-%'
UNION ALL
SELECT N'stg.Sales',
       CAST(SUM(CAST((Quantity * UnitPrice - DiscountAmount) / 1.23 AS DECIMAL(12, 2))) AS DECIMAL(14, 2))
FROM stg.Sales WHERE SalesDate >= '2026-08-01' AND SalesDate < '2026-09-01'
UNION ALL
SELECT N'dbo.FactSales', CAST(SUM(f.NetAmount) AS DECIMAL(14, 2))
FROM dbo.FactSales AS f JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
WHERE d.Date >= '2026-08-01' AND d.Date < '2026-09-01'
UNION ALL
SELECT N'reporting.vw_SalesDaily', CAST(SUM(NetAmount) AS DECIMAL(14, 2))
FROM reporting.vw_SalesDaily WHERE YearMonth = '2026-08';

PRINT N'E02: source files on 17 August';
SELECT SourceFile, COUNT(*) AS RowsInFile,
       COUNT(DISTINCT TransactionNo) AS Transactions,
       CAST(SUM(CAST((TRY_CONVERT(INT, Quantity) * TRY_CONVERT(DECIMAL(10, 2), UnitPrice)
                     - TRY_CONVERT(DECIMAL(10, 2), DiscountAmount)) / 1.23 AS DECIMAL(12, 2))) AS DECIMAL(14, 2)) AS NetAmount
FROM src.SalesRaw
WHERE SalesDate = N'2026-08-17'
GROUP BY SourceFile ORDER BY SourceFile;

PRINT N'E02: verify the POS retry is a row-for-row copy';
WITH Original AS (
    SELECT TransactionNo, LineNumber, SalesDate, SKU, StoreCode,
           Quantity, UnitPrice, DiscountAmount
    FROM src.SalesRaw WHERE SourceFile = N'POS_20260817.csv'
), Retry AS (
    SELECT TransactionNo, LineNumber, SalesDate, SKU, StoreCode,
           Quantity, UnitPrice, DiscountAmount
    FROM src.SalesRaw WHERE SourceFile = N'POS_20260817_RETRY.csv'
)
SELECT (SELECT COUNT(*) FROM Original) AS OriginalRows,
       (SELECT COUNT(*) FROM Retry) AS RetryRows,
       (SELECT COUNT(*) FROM (
            SELECT * FROM Original EXCEPT SELECT * FROM Retry
       ) AS MissingInRetry) AS MissingInRetry,
       (SELECT COUNT(*) FROM (
            SELECT * FROM Retry EXCEPT SELECT * FROM Original
       ) AS AddedByRetry) AS AddedByRetry;

PRINT N'E02: de-duplicate at fact grain';
WITH Ranked AS (
    SELECT f.NetAmount,
           ROW_NUMBER() OVER (
               PARTITION BY f.DateKey, f.StoreKey, f.TransactionNo, f.LineNumber
               ORDER BY f.SalesKey) AS CopyNo
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    WHERE d.YearMonth = '2026-08'
)
SELECT COUNT(*) AS RowsInReport,
       SUM(CASE WHEN CopyNo > 1 THEN 1 ELSE 0 END) AS DuplicateRows,
       CAST(SUM(NetAmount) AS DECIMAL(14, 2)) AS NetInReport,
       CAST(SUM(CASE WHEN CopyNo = 1 THEN NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS NetAfterDedup
FROM Ranked;

PRINT N'E02: ETL status';
SELECT PackageName, Status, RowsRead, RowsLoaded, RowsRejected
FROM dbo.LoadLog ORDER BY LoadId;
