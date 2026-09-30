/* Private, read-only E03 measurement on RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'E03: jacket trend';
SELECT d.YearWeek, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.IsoYear = 2026 AND d.IsoWeek BETWEEN 30 AND 38
GROUP BY d.YearWeek ORDER BY d.YearWeek;

PRINT N'E03: category comparison';
SELECT p.Department, p.Category,
       CAST(SUM(CASE WHEN d.YearWeek = '2026-W37' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS W37,
       CAST(SUM(CASE WHEN d.YearWeek = '2026-W38' THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS W38
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY p.Department, p.Category
ORDER BY p.Department, p.Category;

PRINT N'E03: jackets by store and week';
SELECT d.YearWeek, st.StoreCode, st.Channel,
       SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek, st.StoreCode, st.Channel
ORDER BY st.StoreCode, d.YearWeek;

PRINT N'E03: jackets by size and week';
SELECT d.YearWeek, p.Size, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek, p.Size
ORDER BY p.Size, d.YearWeek;

PRINT N'E03: jackets by model and week';
SELECT d.YearWeek, p.StyleCode, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek, p.StyleCode
ORDER BY p.StyleCode, d.YearWeek;

PRINT N'E03: jacket store x size W38';
SELECT st.StoreCode, p.Size, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.YearWeek = '2026-W38'
GROUP BY st.StoreCode, p.Size
ORDER BY st.StoreCode, p.Size;

PRINT N'E03: M/L stock trend in four stores';
SELECT d.Date, SUM(i.StockQuantity) AS StockQuantity,
       COUNT(*) AS SnapshotRows,
       COUNT(DISTINCT st.StoreCode) AS StoresReporting
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = i.StoreKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND p.Size IN ('M', 'L')
  AND st.StoreCode IN ('S-WAW-01', 'S-WAW-02', 'S-POZ-01', 'S-GDA-01')
  AND d.Date BETWEEN '2026-09-07' AND '2026-09-20'
GROUP BY d.Date ORDER BY d.Date;

PRINT N'E03: M/L stock by store on 13 and 20 September';
SELECT d.Date, st.StoreCode, p.Size,
       SUM(i.StockQuantity) AS StockQuantity,
       COUNT(*) AS SnapshotRows
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = i.StoreKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND p.Size IN ('M', 'L')
  AND d.Date IN ('2026-09-13', '2026-09-20')
GROUP BY d.Date, st.StoreCode, p.Size
ORDER BY d.Date, st.StoreCode, p.Size;

PRINT N'E03: all-category receipts by store and week';
SELECT d.YearWeek, st.StoreCode,
       COUNT(DISTINCT f.TransactionNo) AS Receipts
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek, st.StoreCode
ORDER BY st.StoreCode, d.YearWeek;

PRINT N'E03: M/L in four stores vs whole jacket category';
SELECT d.YearWeek,
       SUM(CASE WHEN p.Size IN ('M', 'L')
                AND st.StoreCode IN ('S-WAW-01', 'S-WAW-02', 'S-POZ-01', 'S-GDA-01')
                THEN f.Quantity ELSE 0 END) AS FourStoreMLUnits,
       CAST(SUM(CASE WHEN p.Size IN ('M', 'L')
                     AND st.StoreCode IN ('S-WAW-01', 'S-WAW-02', 'S-POZ-01', 'S-GDA-01')
                     THEN f.NetAmount ELSE 0 END) AS DECIMAL(14, 2)) AS FourStoreMLNet,
       SUM(f.Quantity) AS CategoryUnits,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS CategoryNet
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = f.StoreKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND d.YearWeek IN ('2026-W37', '2026-W38')
GROUP BY d.YearWeek ORDER BY d.YearWeek;

PRINT N'E03: independent reporting view totals';
SELECT YearWeek, SUM(Units) AS Units,
       CAST(SUM(NetAmount) AS DECIMAL(14, 2)) AS NetAmount
FROM reporting.vw_SalesWeekly
WHERE YearWeek IN ('2026-W37', '2026-W38')
  AND Department = N'WOMEN' AND Category = N'Kurtki'
GROUP BY YearWeek ORDER BY YearWeek;

PRINT N'E03: stock availability view on 20 September';
SELECT StoreCode, SkuCount, SkuInStock, AvailabilityPct, StockQuantity
FROM reporting.vw_StockAvailability
WHERE SnapshotDate = '2026-09-20'
  AND Department = N'WOMEN' AND Category = N'Kurtki'
ORDER BY StoreCode;

PRINT N'E03: source-vs-fact M/L stock in four stores on 20 September';
SELECT N'src.InventoryRaw' AS Layer,
       COUNT(*) AS RowsCount,
       SUM(TRY_CONVERT(INT, r.StockQuantity)) AS StockQuantity
FROM src.InventoryRaw AS r
JOIN dbo.DimProduct AS p ON p.SKU = r.SKU
WHERE r.SnapshotDate = N'2026-09-20'
  AND p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND p.Size IN ('M', 'L')
  AND r.StoreCode IN ('S-WAW-01', 'S-WAW-02', 'S-POZ-01', 'S-GDA-01')
UNION ALL
SELECT N'dbo.FactInventoryDaily', COUNT(*), SUM(i.StockQuantity)
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
JOIN dbo.DimStore AS st ON st.StoreKey = i.StoreKey
WHERE d.Date = '2026-09-20'
  AND p.Department = N'WOMEN' AND p.Category = N'Kurtki'
  AND p.Size IN ('M', 'L')
  AND st.StoreCode IN ('S-WAW-01', 'S-WAW-02', 'S-POZ-01', 'S-GDA-01');

PRINT N'E03: latest dates';
SELECT (SELECT MAX(d.Date) FROM dbo.FactSales AS f
        JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey) AS LatestSale,
       (SELECT MAX(d.Date) FROM dbo.FactInventoryDaily AS i
        JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey) AS LatestStockSnapshot;
