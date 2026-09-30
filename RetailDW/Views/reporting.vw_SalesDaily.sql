/*
    Daily sales, one row per trading day / store / product category.

    The base view for day-level questions; roll it up on [YearMonth] or
    [YearWeek] for longer periods.
*/
CREATE VIEW [reporting].[vw_SalesDaily]
AS
SELECT  d.[Date]                            AS [SalesDate],
        d.[YearMonth],
        d.[YearWeek],
        st.[StoreCode],
        st.[StoreName],
        st.[Channel],
        st.[Region],
        p.[Department],
        p.[Category],
        SUM(f.[Quantity])                   AS [Units],
        COUNT(DISTINCT f.[TransactionNo])   AS [Transactions],
        SUM(f.[GrossAmount])                AS [GrossAmount],
        SUM(f.[DiscountAmount])             AS [DiscountAmount],
        SUM(f.[NetAmount])                  AS [NetAmount],
        SUM(f.[Quantity] * f.[UnitCost])    AS [CostAmount]
FROM    [dbo].[FactSales]   AS f
JOIN    [dbo].[DimDate]     AS d  ON d.[DateKey]    = f.[DateKey]
JOIN    [dbo].[DimStore]    AS st ON st.[StoreKey]  = f.[StoreKey]
JOIN    [dbo].[DimProduct]  AS p  ON p.[ProductKey] = f.[ProductKey]
GROUP BY d.[Date], d.[YearMonth], d.[YearWeek],
         st.[StoreCode], st.[StoreName], st.[Channel], st.[Region],
         p.[Department], p.[Category];
