/* Private E06 measurement. SELECT-only; do not distribute to participants. */
SET NOCOUNT ON;

PRINT N'E06: complete and boundary weeks';
SELECT d.YearWeek,
       MIN(d.Date) AS FirstSaleDate,
       MAX(d.Date) AS LastSaleDate,
       COUNT(DISTINCT d.Date) AS SaleDays,
       COUNT(DISTINCT f.StoreKey) AS Stores,
       COUNT(*) AS SaleLines,
       COUNT(DISTINCT f.TransactionNo) AS Receipts,
       SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14,2)) AS NetAmount,
       CAST(SUM(f.NetAmount) / NULLIF(COUNT(DISTINCT f.TransactionNo),0) AS DECIMAL(14,2)) AS BasketNet
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
WHERE d.YearWeek IN ('2025-W01','2025-W36','2025-W38',
                     '2026-W35','2026-W36','2026-W37','2026-W38')
GROUP BY d.YearWeek
ORDER BY d.YearWeek;

PRINT N'E06: calendar boundaries versus sale coverage';
SELECT d.YearWeek, MIN(d.Date) AS CalendarStart, MAX(d.Date) AS CalendarEnd,
       COUNT(DISTINCT d.Date) AS CalendarDays,
       COUNT(DISTINCT CASE WHEN f.SalesKey IS NOT NULL THEN d.Date END) AS SaleDays
FROM dbo.DimDate AS d
LEFT JOIN dbo.FactSales AS f ON f.DateKey = d.DateKey
WHERE d.YearWeek IN ('2025-W01','2026-W36','2026-W38')
GROUP BY d.YearWeek
ORDER BY d.YearWeek;

PRINT N'E06: daily/store coverage in candidate report weeks';
SELECT d.YearWeek, d.Date, COUNT(DISTINCT f.StoreKey) AS Stores,
       COUNT(*) AS SaleLines, CAST(SUM(f.NetAmount) AS DECIMAL(14,2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
WHERE d.YearWeek IN ('2025-W01','2026-W36','2026-W38')
GROUP BY d.YearWeek, d.Date
ORDER BY d.YearWeek, d.Date;

PRINT N'E06: W37/W38 channels';
SELECT d.YearWeek, st.Channel,
       CAST(SUM(f.NetAmount) AS DECIMAL(14,2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearWeek IN ('2026-W37','2026-W38')
GROUP BY d.YearWeek, st.Channel
ORDER BY st.Channel, d.YearWeek;

PRINT N'E06: weekly view cross-check (same sales fact, separate aggregation)';
SELECT YearWeek, CAST(SUM(NetAmount) AS DECIMAL(14,2)) AS ViewNetAmount
FROM reporting.vw_SalesWeekly
WHERE YearWeek IN ('2025-W36','2025-W38','2026-W35',
                   '2026-W36','2026-W37','2026-W38')
GROUP BY YearWeek
ORDER BY YearWeek;

PRINT N'E06: W37/W38 category contributions';
SELECT p.Department, p.Category,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W37' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14,2)) AS W37Net,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W38' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14,2)) AS W38Net,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W38' THEN f.NetAmount ELSE -f.NetAmount END) AS DECIMAL(14,2)) AS Contribution
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE d.YearWeek IN ('2026-W37','2026-W38')
GROUP BY p.Department, p.Category
ORDER BY Contribution;

PRINT N'E06: W35/W36 channels and category contributions for second run';
SELECT st.Channel,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W35' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14,2)) AS W35Net,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W36' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14,2)) AS W36Net
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearWeek IN ('2026-W35','2026-W36')
GROUP BY st.Channel
ORDER BY st.Channel;

SELECT p.Department, p.Category,
       CAST(SUM(CASE WHEN d.YearWeek='2026-W36' THEN f.NetAmount ELSE -f.NetAmount END) AS DECIMAL(14,2)) AS Contribution
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE d.YearWeek IN ('2026-W35','2026-W36')
GROUP BY p.Department, p.Category
ORDER BY Contribution;

PRINT N'E06: returns by acceptance week';
SELECT d.YearWeek, SUM(r.Quantity) AS ReturnUnits,
       CAST(SUM(r.ReturnAmount)/1.23 AS DECIMAL(14,2)) AS ReturnNet
FROM dbo.FactReturns AS r
JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey
WHERE d.YearWeek IN ('2026-W37','2026-W38')
GROUP BY d.YearWeek
ORDER BY d.YearWeek;

PRINT N'E06: source file coverage and duplicate sale lines';
SELECT d.YearWeek,
       COUNT(DISTINCT CASE WHEN sr.SourceFile LIKE 'POS%' THEN sr.SourceFile END) AS PosFiles,
       COUNT(DISTINCT CASE WHEN sr.SourceFile LIKE 'WEB%' THEN sr.SourceFile END) AS WebFiles,
       COUNT(*) AS RawLines,
       COUNT(*)-COUNT(DISTINCT CONCAT(sr.TransactionNo,'|',sr.LineNumber)) AS RawDuplicateLines
FROM src.SalesRaw AS sr
JOIN dbo.DimDate AS d ON d.Date = TRY_CONVERT(DATE,sr.SalesDate,23)
WHERE d.YearWeek IN ('2025-W01','2026-W36','2026-W38')
GROUP BY d.YearWeek
ORDER BY d.YearWeek;

PRINT N'E06: fact duplicate sale lines';
SELECT d.YearWeek, COUNT(*) AS FactLines,
       COUNT(*)-COUNT(DISTINCT CONCAT(f.TransactionNo,'|',f.LineNumber)) AS FactDuplicateLines
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
WHERE d.YearWeek IN ('2025-W01','2026-W36','2026-W38')
GROUP BY d.YearWeek
ORDER BY d.YearWeek;
