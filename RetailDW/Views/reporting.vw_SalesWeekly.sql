/*
    Weekly trading numbers by channel, region and category. Weeks follow the
    ISO-8601 calendar (Monday-Sunday), which is the trading week used in the
    Monday report.
*/
CREATE VIEW [reporting].[vw_SalesWeekly]
AS
SELECT  d.[IsoYear],
        d.[IsoWeek],
        d.[YearWeek],
        MIN(d.[Date])                       AS [WeekStart],
        MAX(d.[Date])                       AS [WeekEnd],
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
GROUP BY d.[IsoYear], d.[IsoWeek], d.[YearWeek],
         st.[Channel], st.[Region], p.[Department], p.[Category];
