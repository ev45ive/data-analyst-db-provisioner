/* Private, read-only E05 measurement. Run on RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'E05: exact result from the participant fixture';
SELECT s.Channel AS Kanal,
       COUNT(*) AS Transakcje,
       SUM(s.Units) AS Sztuki,
       SUM(s.NetRevenue) AS Przychod,
       CAST(AVG(s.AvgBasketValue) AS DECIMAL(10, 2)) AS SredniKoszyk
FROM reporting.vw_StoreScorecard AS s
WHERE s.YearMonth = '2026-08'
GROUP BY s.Channel
ORDER BY s.Channel;

PRINT N'E05: scorecard grain and weighted basket';
SELECT s.Channel, COUNT(*) AS ViewRows,
       SUM(s.Transactions) AS ReceiptSum,
       SUM(s.Units) AS Units,
       CAST(SUM(s.NetRevenue) AS DECIMAL(14, 2)) AS NetRevenue,
       CAST(AVG(s.AvgBasketValue) AS DECIMAL(10, 2)) AS MeanOfStoreAverages,
       CAST(SUM(s.NetRevenue) / NULLIF(SUM(s.Transactions), 0) AS DECIMAL(10, 2)) AS WeightedBasket
FROM reporting.vw_StoreScorecard AS s
WHERE s.YearMonth = '2026-08'
GROUP BY s.Channel;

PRINT N'E05: independent recount from FactSales';
SELECT st.Channel,
       COUNT(DISTINCT f.TransactionNo) AS Receipts,
       SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetRevenue,
       CAST(SUM(f.NetAmount) / NULLIF(COUNT(DISTINCT f.TransactionNo), 0) AS DECIMAL(10, 2)) AS AvgBasket
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearMonth = '2026-08'
GROUP BY st.Channel ORDER BY st.Channel;

PRINT N'E05: second receipt count route at receipt grain';
WITH Receipts AS (
    SELECT st.Channel, st.StoreCode, d.Date, f.TransactionNo
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
    WHERE d.YearMonth = '2026-08'
    GROUP BY st.Channel, st.StoreCode, d.Date, f.TransactionNo
)
SELECT Channel, COUNT(*) AS Receipts
FROM Receipts GROUP BY Channel ORDER BY Channel;

PRINT N'E05: August store-level rows and missing online store';
SELECT s.StoreCode, s.Channel, s.Transactions, s.Units,
       CAST(s.NetRevenue AS DECIMAL(14, 2)) AS NetRevenue,
       s.AvgBasketValue
FROM reporting.vw_StoreScorecard AS s
WHERE s.YearMonth = '2026-08'
ORDER BY s.StoreCode;
SELECT st.StoreCode, st.Channel, st.SalesAreaM2,
       COUNT(CASE WHEN d.DateKey IS NOT NULL THEN f.SalesKey END) AS AugustFactRows
FROM dbo.DimStore AS st
LEFT JOIN dbo.FactSales AS f ON f.StoreKey = st.StoreKey
LEFT JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    AND d.YearMonth = '2026-08'
WHERE st.Channel = N'ONLINE'
GROUP BY st.StoreCode, st.Channel, st.SalesAreaM2;

PRINT N'E05: duplicate POS file value and independent row comparison';
SELECT r.SourceFile, COUNT(*) AS RowsInFile,
       COUNT(DISTINCT r.TransactionNo) AS Receipts,
       CAST(SUM(CAST((TRY_CONVERT(INT, r.Quantity) * TRY_CONVERT(DECIMAL(10, 2), r.UnitPrice)
                - TRY_CONVERT(DECIMAL(10, 2), r.DiscountAmount)) / 1.23 AS DECIMAL(12, 2)))
            AS DECIMAL(14, 2)) AS NetRevenue
FROM src.SalesRaw AS r
WHERE r.SourceFile IN (N'POS_20260817.csv', N'POS_20260817_RETRY.csv')
GROUP BY r.SourceFile ORDER BY r.SourceFile;

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
       (SELECT COUNT(*) FROM (SELECT * FROM Original EXCEPT SELECT * FROM Retry) AS x) AS OnlyOriginal,
       (SELECT COUNT(*) FROM (SELECT * FROM Retry EXCEPT SELECT * FROM Original) AS x) AS OnlyRetry;

PRINT N'E05: corrected August channel totals without changing data';
WITH Ranked AS (
    SELECT st.Channel, f.TransactionNo, f.Quantity, f.NetAmount,
           ROW_NUMBER() OVER (
               PARTITION BY f.DateKey, f.StoreKey, f.TransactionNo, f.LineNumber
               ORDER BY f.SalesKey) AS CopyNo
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
    WHERE d.YearMonth = '2026-08'
)
SELECT Channel,
       COUNT(DISTINCT TransactionNo) AS Receipts,
       SUM(CASE WHEN CopyNo = 1 THEN Quantity ELSE 0 END) AS UnitsAfterDedup,
       CAST(SUM(CASE WHEN CopyNo = 1 THEN NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS NetAfterDedup,
       CAST(SUM(CASE WHEN CopyNo = 1 THEN NetAmount ELSE 0 END)
            / NULLIF(COUNT(DISTINCT TransactionNo), 0) AS DECIMAL(10, 2)) AS BasketAfterDedup,
       SUM(CASE WHEN CopyNo > 1 THEN 1 ELSE 0 END) AS RemovedRows
FROM Ranked GROUP BY Channel ORDER BY Channel;
