/*
    Margin by style and month, calculated from the sold lines.

    Used by the merchandising margin review.
*/
CREATE VIEW [reporting].[vw_MarginAnalysis]
AS
SELECT  d.[YearMonth],
        p.[StyleCode],
        p.[StyleName],
        p.[Department],
        p.[Category],
        SUM(f.[Quantity])                   AS [Units],
        SUM(f.[NetAmount])                  AS [NetRevenue],
        SUM(f.[Quantity] * f.[UnitCost])    AS [CostAmount],
        SUM(f.[NetAmount]) - SUM(f.[Quantity] * f.[UnitCost]) AS [GrossMargin],
        CASE WHEN SUM(f.[NetAmount]) = 0 THEN NULL
             ELSE CAST(100.0 * (SUM(f.[NetAmount]) - SUM(f.[Quantity] * f.[UnitCost]))
                       / SUM(f.[NetAmount]) AS DECIMAL (5, 2))
        END                                 AS [GrossMarginPct]
FROM    [dbo].[FactSales]  AS f
JOIN    [dbo].[DimDate]    AS d ON d.[DateKey]    = f.[DateKey]
JOIN    [dbo].[DimProduct] AS p ON p.[ProductKey] = f.[ProductKey]
GROUP BY d.[YearMonth], p.[StyleCode], p.[StyleName], p.[Department], p.[Category];
