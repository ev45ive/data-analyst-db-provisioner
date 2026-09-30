/*
    Product scorecard at SKU level.

    [UnitsSoldSeason] and [SellThroughPct] cover the current season only, i.e.
    the period for which the stock feed has data - sell-through compares what
    was sold with what is still on the shelf, so both sides have to describe
    the same intake.
*/
CREATE VIEW [reporting].[vw_ProductPerformance]
AS
WITH [SeasonStart] AS
(
    SELECT MIN([DateKey]) AS [DateKey] FROM [dbo].[FactInventoryDaily]
),
[StockNow] AS
(
    SELECT  i.[ProductKey],
            SUM(i.[StockQuantity]) AS [StockQuantity]
    FROM    [dbo].[FactInventoryDaily] AS i
    WHERE   i.[DateKey] = (SELECT MAX([DateKey]) FROM [dbo].[FactInventoryDaily])
    GROUP BY i.[ProductKey]
),
[SoldTotal] AS
(
    SELECT  f.[ProductKey],
            SUM(f.[Quantity])  AS [Units],
            SUM(f.[NetAmount]) AS [NetAmount]
    FROM    [dbo].[FactSales] AS f
    GROUP BY f.[ProductKey]
),
[SoldSeason] AS
(
    SELECT  f.[ProductKey],
            SUM(f.[Quantity]) AS [Units]
    FROM    [dbo].[FactSales] AS f
    WHERE   f.[DateKey] >= (SELECT [DateKey] FROM [SeasonStart])
    GROUP BY f.[ProductKey]
),
[Returned] AS
(
    SELECT  r.[ProductKey],
            SUM(r.[Quantity])     AS [Units],
            SUM(r.[ReturnAmount]) AS [ReturnAmount]
    FROM    [dbo].[FactReturns] AS r
    GROUP BY r.[ProductKey]
)
SELECT  p.[SKU],
        p.[StyleCode],
        p.[StyleName],
        p.[Department],
        p.[Category],
        p.[Color],
        p.[Size],
        p.[ListPrice],
        ISNULL(t.[Units], 0)            AS [UnitsSoldTotal],
        ISNULL(t.[NetAmount], 0)        AS [NetRevenueTotal],
        ISNULL(ss.[Units], 0)           AS [UnitsSoldSeason],
        ISNULL(rt.[Units], 0)           AS [UnitsReturned],
        ISNULL(rt.[ReturnAmount], 0)    AS [ReturnAmount],
        ISNULL(sn.[StockQuantity], 0)   AS [StockOnHand],
        CASE WHEN ISNULL(ss.[Units], 0) + ISNULL(sn.[StockQuantity], 0) = 0
             THEN NULL
             ELSE CAST(100.0 * ISNULL(ss.[Units], 0)
                       / (ISNULL(ss.[Units], 0) + ISNULL(sn.[StockQuantity], 0)) AS DECIMAL (5, 2))
        END                             AS [SellThroughPct]
FROM    [dbo].[DimProduct] AS p
LEFT JOIN [SoldTotal]  AS t  ON t.[ProductKey]  = p.[ProductKey]
LEFT JOIN [SoldSeason] AS ss ON ss.[ProductKey] = p.[ProductKey]
LEFT JOIN [Returned]   AS rt ON rt.[ProductKey] = p.[ProductKey]
LEFT JOIN [StockNow]   AS sn ON sn.[ProductKey] = p.[ProductKey];
