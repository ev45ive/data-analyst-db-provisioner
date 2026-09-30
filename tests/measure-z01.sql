/* Private Z01 measurement. Read-only; run on RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'Z01: August scorecard, two rankings';
SELECT StoreCode, Channel, SalesAreaM2, Transactions, Units,
       CAST(NetRevenue AS DECIMAL(14, 2)) AS NetRevenue,
       NetRevenuePerM2, AvgBasketValue, UnitsPerTransaction
FROM reporting.vw_StoreScorecard
WHERE YearMonth = '2026-08'
ORDER BY NetRevenuePerM2 DESC;

PRINT N'Z01: independent August recount, including online';
SELECT st.StoreCode, st.Channel, st.SalesAreaM2,
       COUNT(DISTINCT f.TransactionNo) AS Transactions,
       SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetRevenue,
       CAST(SUM(f.NetAmount) / NULLIF(st.SalesAreaM2, 0) AS DECIMAL(12, 2)) AS NetRevenuePerM2
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearMonth = '2026-08'
GROUP BY st.StoreCode, st.Channel, st.SalesAreaM2
ORDER BY NetRevenue DESC;

PRINT N'Z01: store dimension and remodeling marker';
SELECT StoreCode, Channel, SalesAreaM2, OpenedDate, RemodelDate
FROM dbo.DimStore
ORDER BY StoreCode;

PRINT N'Z01: Krakow and whole-network revenue by month';
SELECT d.YearMonth,
       CAST(SUM(CASE WHEN st.StoreCode = N'S-KRK-01' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS KrakowNet,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetworkNet,
       CAST(100.0 * SUM(CASE WHEN st.StoreCode = N'S-KRK-01' THEN f.NetAmount ELSE 0 END)
            / NULLIF(SUM(f.NetAmount), 0) AS DECIMAL(10, 4)) AS KrakowSharePct
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearMonth BETWEEN '2026-01' AND '2026-08'
GROUP BY d.YearMonth
ORDER BY d.YearMonth;

PRINT N'Z01: pre/post aggregated share, with STORE-only comparison';
SELECT CASE WHEN d.Date < '2026-04-01' THEN N'Jan-Mar' ELSE N'Apr-Aug' END AS Period,
       CAST(SUM(CASE WHEN st.StoreCode = N'S-KRK-01' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS KrakowNet,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetworkNet,
       CAST(100.0 * SUM(CASE WHEN st.StoreCode = N'S-KRK-01' THEN f.NetAmount ELSE 0 END)
            / NULLIF(SUM(f.NetAmount), 0) AS DECIMAL(10, 4)) AS NetworkSharePct,
       CAST(SUM(CASE WHEN st.Channel = N'STORE' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS StoreNet,
       CAST(100.0 * SUM(CASE WHEN st.StoreCode = N'S-KRK-01' THEN f.NetAmount ELSE 0 END)
            / NULLIF(SUM(CASE WHEN st.Channel = N'STORE' THEN f.NetAmount ELSE 0 END), 0)
            AS DECIMAL(10, 4)) AS StoreSharePct
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.Date >= '2026-01-01' AND d.Date < '2026-09-01'
GROUP BY CASE WHEN d.Date < '2026-04-01' THEN N'Jan-Mar' ELSE N'Apr-Aug' END
ORDER BY Period DESC;

PRINT N'Z01: August repeated receipt lines by store (read-only diagnostic)';
WITH Ranked AS (
    SELECT st.StoreCode, f.NetAmount,
           ROW_NUMBER() OVER (
               PARTITION BY f.DateKey, f.StoreKey, f.TransactionNo, f.LineNumber
               ORDER BY f.SalesKey) AS CopyNo
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
    WHERE d.YearMonth = '2026-08'
)
SELECT StoreCode, COUNT(*) AS RepeatedLines,
       CAST(SUM(NetAmount) AS DECIMAL(14, 2)) AS ExtraNet
FROM Ranked
WHERE CopyNo > 1
GROUP BY StoreCode
ORDER BY StoreCode;
