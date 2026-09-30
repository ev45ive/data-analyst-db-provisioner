/* Private Z02 measurement. SELECT only; no changes to RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'Z02: inventory coverage by store against June calendar';
WITH dates AS (
    SELECT DateKey, [Date] FROM dbo.DimDate
    WHERE [Date] >= '2026-06-01' AND [Date] < '2026-07-01'
), coverage AS (
    SELECT st.StoreCode, d.[Date], COUNT(i.InventoryKey) AS SnapshotRows
    FROM dbo.DimStore AS st
    CROSS JOIN dates AS d
    LEFT JOIN dbo.FactInventoryDaily AS i
      ON i.StoreKey = st.StoreKey AND i.DateKey = d.DateKey
    GROUP BY st.StoreCode, d.[Date]
)
SELECT StoreCode, COUNT(*) AS CalendarDays,
       SUM(CASE WHEN SnapshotRows > 0 THEN 1 ELSE 0 END) AS ReportedDays,
       SUM(CASE WHEN SnapshotRows = 0 THEN 1 ELSE 0 END) AS MissingDays,
       SUM(SnapshotRows) AS SnapshotRows
FROM coverage GROUP BY StoreCode ORDER BY StoreCode;

PRINT N'Z02: exact missing store-days';
WITH dates AS (
    SELECT DateKey, [Date] FROM dbo.DimDate
    WHERE [Date] >= '2026-06-01' AND [Date] < '2026-07-01'
)
SELECT st.StoreCode, d.[Date] AS MissingDate
FROM dbo.DimStore AS st CROSS JOIN dates AS d
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.FactInventoryDaily AS i
    WHERE i.StoreKey = st.StoreKey AND i.DateKey = d.DateKey
)
ORDER BY d.[Date], st.StoreCode;

PRINT N'Z02: rows by day on missing dates';
SELECT d.[Date], COUNT(*) AS SnapshotRows,
       COUNT(DISTINCT i.StoreKey) AS ReportingStores
FROM dbo.FactInventoryDaily AS i
JOIN dbo.DimDate AS d ON d.DateKey = i.DateKey
WHERE d.[Date] BETWEEN '2026-06-09' AND '2026-06-13'
GROUP BY d.[Date] ORDER BY d.[Date];

PRINT N'Z02: reported availability by store (unweighted category-day average)';
SELECT StoreCode, COUNT(DISTINCT SnapshotDate) AS ReportedDays,
       COUNT(*) AS CategoryDays,
       CAST(AVG(AvailabilityPct) AS DECIMAL(6, 2)) AS AvgCategoryDayPct,
       SUM(SkuInStock) AS SkuInStock,
       SUM(SkuCount) AS SkuCount,
       CAST(100.0 * SUM(SkuInStock) / NULLIF(SUM(SkuCount), 0) AS DECIMAL(6, 2)) AS WeightedSkuPct
FROM reporting.vw_StockAvailability
WHERE SnapshotDate >= '2026-06-01' AND SnapshotDate < '2026-07-01'
GROUP BY StoreCode ORDER BY StoreCode;

PRINT N'Z02: availability on adjacent reported days';
SELECT SnapshotDate, StoreCode,
       SUM(SkuInStock) AS SkuInStock, SUM(SkuCount) AS SkuCount,
       CAST(100.0 * SUM(SkuInStock) / NULLIF(SUM(SkuCount), 0) AS DECIMAL(6, 2)) AS WeightedSkuPct
FROM reporting.vw_StockAvailability
WHERE StoreCode = 'S-POZ-01'
  AND SnapshotDate IN ('2026-06-09', '2026-06-10', '2026-06-11', '2026-06-12', '2026-06-13')
GROUP BY SnapshotDate, StoreCode ORDER BY SnapshotDate;

PRINT N'Z02: source and staging coverage for Poznan on suspect dates';
SELECT 'src.InventoryRaw' AS Layer, r.SnapshotDate AS SnapshotDate,
       r.StoreCode, COUNT(*) AS RowsCount, COUNT(DISTINCT r.SourceFile) AS FilesCount
FROM src.InventoryRaw AS r
WHERE r.StoreCode = 'S-POZ-01' AND r.SnapshotDate BETWEEN '2026-06-09' AND '2026-06-13'
GROUP BY r.SnapshotDate, r.StoreCode
UNION ALL
SELECT 'stg.Inventory', CONVERT(NVARCHAR(20), s.SnapshotDate, 23),
       s.StoreCode, COUNT(*), COUNT(DISTINCT s.SourceFile)
FROM stg.Inventory AS s
WHERE s.StoreCode = 'S-POZ-01' AND s.SnapshotDate BETWEEN '2026-06-09' AND '2026-06-13'
GROUP BY s.SnapshotDate, s.StoreCode
ORDER BY Layer, SnapshotDate;

PRINT N'Z02: latest inventory load result';
SELECT TOP (1) LoadId, PackageName, Status, RowsRead, RowsLoaded, RowsRejected
FROM dbo.LoadLog WHERE PackageName = N'etl.LoadInventory'
ORDER BY LoadId DESC;
