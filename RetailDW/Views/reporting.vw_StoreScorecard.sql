/*
    Monthly store scorecard: the productivity measures the area managers get
    every month - revenue, average basket, units per transaction and revenue
    per square metre.
*/
CREATE VIEW [reporting].[vw_StoreScorecard]
AS
SELECT  st.[StoreCode],
        st.[StoreName],
        st.[City],
        st.[Region],
        st.[Channel],
        st.[Format],
        st.[SalesAreaM2],
        d.[YearMonth],
        SUM(f.[NetAmount])                                  AS [NetRevenue],
        SUM(f.[Quantity])                                   AS [Units],
        COUNT(DISTINCT f.[TransactionNo])                   AS [Transactions],
        CAST(SUM(f.[NetAmount]) / COUNT(DISTINCT f.[TransactionNo]) AS DECIMAL (10, 2))
                                                            AS [AvgBasketValue],
        CAST(1.0 * SUM(f.[Quantity]) / COUNT(DISTINCT f.[TransactionNo]) AS DECIMAL (10, 2))
                                                            AS [UnitsPerTransaction],
        CAST(SUM(f.[NetAmount]) / st.[SalesAreaM2] AS DECIMAL (10, 2))
                                                            AS [NetRevenuePerM2]
FROM    [dbo].[FactSales] AS f
JOIN    [dbo].[DimStore]  AS st ON st.[StoreKey] = f.[StoreKey]
JOIN    [dbo].[DimDate]   AS d  ON d.[DateKey]   = f.[DateKey]
WHERE   st.[SalesAreaM2] > 0
GROUP BY st.[StoreCode], st.[StoreName], st.[City], st.[Region], st.[Channel],
         st.[Format], st.[SalesAreaM2], d.[YearMonth];
