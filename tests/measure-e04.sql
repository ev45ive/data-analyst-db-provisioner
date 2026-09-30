/* Private, read-only E04 measurement on RetailDW_WorkshopNext. */
SET NOCOUNT ON;

PRINT N'E04: comparable three-week windows; sold lines only';
WITH SaleWindows AS (
    SELECT CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
                WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
                ELSE N'AFTER' END AS WindowName,
           f.Quantity, f.NetAmount, f.DiscountAmount,
           f.Quantity * f.UnitCost AS CostAmount,
           f.TransactionNo
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
    WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
      AND d.[Date] BETWEEN '2026-02-09' AND '2026-04-12'
)
SELECT WindowName, COUNT(*) AS Lines, SUM(Quantity) AS Units,
       COUNT(DISTINCT TransactionNo) AS Receipts,
       CAST(SUM(NetAmount) AS DECIMAL(14, 2)) AS NetAmount,
       CAST(SUM(DiscountAmount) AS DECIMAL(14, 2)) AS DiscountAmountGross,
       CAST(SUM(CostAmount) AS DECIMAL(14, 2)) AS CostAmount,
       CAST(SUM(NetAmount - CostAmount) AS DECIMAL(14, 2)) AS MarginBeforeReturns,
       CAST(100.0 * SUM(NetAmount - CostAmount) / NULLIF(SUM(NetAmount), 0) AS DECIMAL(8, 2)) AS MarginBeforeReturnsPct
FROM SaleWindows GROUP BY WindowName ORDER BY WindowName;

PRINT N'E04: returns in the same reception windows; gross and ex VAT';
SELECT CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
            WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
            ELSE N'AFTER' END AS WindowName,
       COUNT(*) AS ReturnLines, SUM(r.Quantity) AS ReturnUnits,
       CAST(SUM(r.ReturnAmount) AS DECIMAL(14, 2)) AS ReturnsGross,
       CAST(SUM(r.ReturnAmount) / 1.23 AS DECIMAL(14, 2)) AS ReturnsExVat
FROM dbo.FactReturns AS r
JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
  AND d.[Date] BETWEEN '2026-02-09' AND '2026-04-12'
GROUP BY CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
              WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
              ELSE N'AFTER' END
ORDER BY WindowName;

PRINT N'E04: both margin definitions at one row per window; no sales-returns row multiplication';
WITH S AS (
    SELECT CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
                WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
                ELSE N'AFTER' END AS WindowName,
           SUM(f.NetAmount) AS NetAmount,
           SUM(f.NetAmount - f.Quantity * f.UnitCost) AS MarginBeforeReturns
    FROM dbo.FactSales AS f
    JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
    WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
      AND d.[Date] BETWEEN '2026-02-09' AND '2026-04-12'
    GROUP BY CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
                  WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
                  ELSE N'AFTER' END
), R AS (
    SELECT CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
                WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
                ELSE N'AFTER' END AS WindowName,
           SUM(r.ReturnAmount) / 1.23 AS ReturnsExVat
    FROM dbo.FactReturns AS r
    JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey
    JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
    WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
      AND d.[Date] BETWEEN '2026-02-09' AND '2026-04-12'
    GROUP BY CASE WHEN d.[Date] < '2026-03-02' THEN N'BEFORE'
                  WHEN d.[Date] <= '2026-03-22' THEN N'PROMO'
                  ELSE N'AFTER' END
)
SELECT S.WindowName,
       CAST(S.MarginBeforeReturns AS DECIMAL(14, 2)) AS ViewMethodMargin,
       CAST(R.ReturnsExVat AS DECIMAL(14, 2)) AS ReturnsExVat,
       CAST(S.MarginBeforeReturns - R.ReturnsExVat AS DECIMAL(14, 2)) AS DictionaryMargin,
       CAST(100.0 * (S.MarginBeforeReturns - R.ReturnsExVat) / NULLIF(S.NetAmount, 0) AS DECIMAL(8, 2)) AS DictionaryMarginPct
FROM S JOIN R ON R.WindowName = S.WindowName
ORDER BY S.WindowName;

PRINT N'E04: March YoY, sold lines and returns separately';
SELECT d.YearMonth, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount,
       CAST(SUM(f.Quantity * f.UnitCost) AS DECIMAL(14, 2)) AS CostAmount,
       CAST(SUM(f.NetAmount - f.Quantity * f.UnitCost) AS DECIMAL(14, 2)) AS MarginBeforeReturns
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
  AND d.YearMonth IN (N'2025-03', N'2026-03')
GROUP BY d.YearMonth ORDER BY d.YearMonth;

SELECT d.YearMonth, CAST(SUM(r.ReturnAmount) / 1.23 AS DECIMAL(14, 2)) AS ReturnsExVat
FROM dbo.FactReturns AS r
JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = r.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
  AND d.YearMonth IN (N'2025-03', N'2026-03')
GROUP BY d.YearMonth ORDER BY d.YearMonth;

PRINT N'E04: weekly seasonality and promotion boundaries';
SELECT d.YearWeek, MIN(d.[Date]) AS FirstSaleDate, SUM(f.Quantity) AS Units,
       CAST(SUM(f.NetAmount) AS DECIMAL(14, 2)) AS NetAmount,
       CAST(SUM(f.NetAmount - f.Quantity * f.UnitCost) AS DECIMAL(14, 2)) AS MarginBeforeReturns,
       CAST(100.0 * SUM(f.NetAmount - f.Quantity * f.UnitCost) / NULLIF(SUM(f.NetAmount), 0) AS DECIMAL(8, 2)) AS MarginBeforeReturnsPct
FROM dbo.FactSales AS f
JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.Department = N'WOMEN' AND p.Category = N'Sukienki'
  AND d.[Date] BETWEEN '2026-02-09' AND '2026-04-12'
GROUP BY d.YearWeek ORDER BY d.YearWeek;

PRINT N'E04: view cross-check and its monthly grain';
SELECT YearMonth, SUM(Units) AS Units,
       CAST(SUM(NetRevenue) AS DECIMAL(14, 2)) AS NetRevenue,
       CAST(SUM(GrossMargin) AS DECIMAL(14, 2)) AS ViewMarginBeforeReturns
FROM reporting.vw_MarginAnalysis
WHERE Department = N'WOMEN' AND Category = N'Sukienki'
  AND YearMonth IN (N'2025-03', N'2026-03')
GROUP BY YearMonth ORDER BY YearMonth;

PRINT N'E04: latest sales and return dates';
SELECT (SELECT MAX(d.[Date]) FROM dbo.FactSales AS f
        JOIN dbo.DimDate AS d ON d.DateKey = f.DateKey) AS LatestSale,
       (SELECT MAX(d.[Date]) FROM dbo.FactReturns AS r
        JOIN dbo.DimDate AS d ON d.DateKey = r.DateKey) AS LatestReturn;
