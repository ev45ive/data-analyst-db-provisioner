/*
    Stock availability: for a given day, store and category, the share of SKUs
    that had stock left at the close of trading.

    Built from the stock feed, so a day only appears for a store that actually
    reported that day.
*/
CREATE VIEW [reporting].[vw_StockAvailability]
AS
SELECT  d.[Date]        AS [SnapshotDate],
        d.[YearMonth],
        d.[YearWeek],
        st.[StoreCode],
        st.[StoreName],
        p.[Department],
        p.[Category],
        COUNT(*)                                                    AS [SkuCount],
        SUM(CASE WHEN i.[StockQuantity] > 0 THEN 1 ELSE 0 END)      AS [SkuInStock],
        CAST(100.0 * SUM(CASE WHEN i.[StockQuantity] > 0 THEN 1 ELSE 0 END) / COUNT(*)
             AS DECIMAL (5, 2))                                     AS [AvailabilityPct],
        SUM(i.[StockQuantity])                                      AS [StockQuantity]
FROM    [dbo].[FactInventoryDaily] AS i
JOIN    [dbo].[DimDate]            AS d  ON d.[DateKey]    = i.[DateKey]
JOIN    [dbo].[DimStore]           AS st ON st.[StoreKey]  = i.[StoreKey]
JOIN    [dbo].[DimProduct]         AS p  ON p.[ProductKey] = i.[ProductKey]
GROUP BY d.[Date], d.[YearMonth], d.[YearWeek],
         st.[StoreCode], st.[StoreName], p.[Department], p.[Category];
