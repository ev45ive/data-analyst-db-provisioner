/* Private Z03 control. Read only; run against RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'Z03: date coverage';
SELECT N'Sales' AS SourceName, MIN(d.[Date]) AS FirstDate, MAX(d.[Date]) AS LastDate,
       COUNT(DISTINCT d.[Date]) AS DistinctDates
FROM dbo.FactSales AS f JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
UNION ALL
SELECT N'Inventory', MIN(d.[Date]), MAX(d.[Date]), COUNT(DISTINCT d.[Date])
FROM dbo.FactInventoryDaily AS i JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey;

PRINT N'Z03: size curve for AW26 sales through last snapshot, all apparel';
WITH Sold AS (
    SELECT p.Size, SUM(f.Quantity) AS Units
    FROM dbo.FactSales AS f
    JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    WHERE d.Season = N'AW26' AND d.[Date] <= '2026-09-20'
      AND p.Size IN (N'XS', N'S', N'M', N'L', N'XL')
    GROUP BY p.Size
), Stock AS (
    SELECT p.Size, SUM(i.StockQuantity) AS Units, COUNT(*) AS SnapshotRows,
           COUNT(DISTINCT i.ProductKey) AS SKUs, COUNT(DISTINCT i.StoreKey) AS Stores
    FROM dbo.FactInventoryDaily AS i
    JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
    JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
    WHERE d.[Date] = '2026-09-20'
      AND p.Size IN (N'XS', N'S', N'M', N'L', N'XL')
    GROUP BY p.Size
)
SELECT s.Size, s.Units AS SoldUnits, st.Units AS StockUnits,
       CAST(100.0 * s.Units / NULLIF(s.Units + st.Units, 0) AS DECIMAL(8, 2)) AS SellThroughPct,
       CAST(100.0 * s.Units / NULLIF(SUM(s.Units) OVER (), 0) AS DECIMAL(8, 2)) AS SoldSharePct,
       CAST(100.0 * st.Units / NULLIF(SUM(st.Units) OVER (), 0) AS DECIMAL(8, 2)) AS StockSharePct,
       st.SnapshotRows, st.SKUs, st.Stores
FROM Sold AS s JOIN Stock AS st ON st.Size = s.Size
ORDER BY CASE s.Size WHEN N'XS' THEN 1 WHEN N'S' THEN 2 WHEN N'M' THEN 3 WHEN N'L' THEN 4 ELSE 5 END;

PRINT N'Z03: same calculation by department and category';
WITH Sold AS (
    SELECT p.Department, p.Category, p.Size, SUM(f.Quantity) AS Units
    FROM dbo.FactSales AS f
    JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    WHERE d.Season = N'AW26' AND d.[Date] <= '2026-09-20'
      AND p.Size IN (N'XS', N'S', N'M', N'L', N'XL')
    GROUP BY p.Department, p.Category, p.Size
), Stock AS (
    SELECT p.Department, p.Category, p.Size, SUM(i.StockQuantity) AS Units,
           COUNT(*) AS SnapshotRows
    FROM dbo.FactInventoryDaily AS i
    JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
    JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
    WHERE d.[Date] = '2026-09-20'
      AND p.Size IN (N'XS', N'S', N'M', N'L', N'XL')
    GROUP BY p.Department, p.Category, p.Size
)
SELECT s.Department, s.Category, s.Size, s.Units AS SoldUnits,
       st.Units AS StockUnits,
       CAST(100.0 * s.Units / NULLIF(s.Units + st.Units, 0) AS DECIMAL(8, 2)) AS SellThroughPct,
       CAST(100.0 * s.Units / NULLIF(SUM(s.Units) OVER (PARTITION BY s.Department, s.Category), 0) AS DECIMAL(8, 2)) AS SoldSharePct,
       CAST(100.0 * st.Units / NULLIF(SUM(st.Units) OVER (PARTITION BY s.Department, s.Category), 0) AS DECIMAL(8, 2)) AS StockSharePct,
       st.SnapshotRows
FROM Sold AS s JOIN Stock AS st
  ON st.Department = s.Department AND st.Category = s.Category AND st.Size = s.Size
ORDER BY s.Department, s.Category,
         CASE s.Size WHEN N'XS' THEN 1 WHEN N'S' THEN 2 WHEN N'M' THEN 3 WHEN N'L' THEN 4 ELSE 5 END;

PRINT N'Z03: view season differs from calendar AW26';
SELECT p.Size, SUM(p.UnitsSoldSeason) AS ViewSoldUnits, SUM(p.StockOnHand) AS ViewStockUnits
FROM reporting.vw_ProductPerformance AS p
WHERE p.Size IN (N'XS', N'S', N'M', N'L', N'XL')
GROUP BY p.Size
ORDER BY CASE p.Size WHEN N'XS' THEN 1 WHEN N'S' THEN 2 WHEN N'M' THEN 3 WHEN N'L' THEN 4 ELSE 5 END;

PRINT N'Z03: AW26 start and inventory footprint';
SELECT MIN(CASE WHEN d.Season = N'AW26' THEN d.[Date] END) AS AW26Start,
       MIN(CASE WHEN i.InventoryKey IS NOT NULL THEN d.[Date] END) AS InventoryStart,
       MAX(CASE WHEN i.InventoryKey IS NOT NULL THEN d.[Date] END) AS InventoryEnd
FROM dbo.DimDate AS d LEFT JOIN dbo.FactInventoryDaily AS i ON i.DateKey = d.DateKey;

PRINT N'Z03: stock rows at last snapshot by size including ONE';
SELECT p.Size, COUNT(*) AS SnapshotRows, SUM(i.StockQuantity) AS StockUnits,
       COUNT(DISTINCT i.ProductKey) AS SKUs, COUNT(DISTINCT i.StoreKey) AS Stores
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
WHERE d.[Date] = '2026-09-20'
GROUP BY p.Size ORDER BY p.Size;

PRINT N'Z03: women jackets stock source vs fact on last snapshot';
SELECT N'src.InventoryRaw' AS LayerName, COUNT(*) AS SnapshotRows,
       SUM(TRY_CONVERT(INT, r.StockQuantity)) AS StockUnits
FROM src.InventoryRaw AS r
JOIN dbo.DimProduct AS p ON p.SKU = r.SKU
WHERE r.SnapshotDate = N'2026-09-20'
  AND p.Department = N'WOMEN' AND p.Category = N'Kurtki'
UNION ALL
SELECT N'dbo.FactInventoryDaily', COUNT(*), SUM(i.StockQuantity)
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimProduct AS p ON p.ProductKey = i.ProductKey
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
WHERE d.[Date] = '2026-09-20'
  AND p.Department = N'WOMEN' AND p.Category = N'Kurtki';
