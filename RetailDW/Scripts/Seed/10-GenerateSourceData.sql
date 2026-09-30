/*
    ⛔ FILE OUT OF SCOPE FOR DATA ANALYSTS
    
    This script generates SYNTHETIC TEST DATA for local development only.
    It is part of the database deployment/seeding infrastructure.
    Data analysts MUST NOT read, reference, or analyze this file.
    
    Synthetic data generation details are irrelevant to business analysis.
    Treat the landing zone tables (src.*) as if they contain real data from
    the source systems — that is the analyst's perspective.
    
    ---
    
    Builds the landing zone ([src].*) for the trading history covered by this
    environment. Runs once, on an empty database; publishing an already
    populated database leaves the data alone.

    The result is reproducible: the same deployment always produces the same
    landing zone.
*/
PRINT N'  preparing [src] data';

IF NOT EXISTS (SELECT 1 FROM [src].[SalesRaw])
BEGIN
    DECLARE @SalesFrom DATE = '2025-01-01',
            @SalesTo   DATE = '2026-09-20',
            @StockFrom DATE = '2026-06-01';

    -- -----------------------------------------------------------------------
    -- Per-product and per-store weights used by the demand model.
    -- -----------------------------------------------------------------------
    SELECT  p.[SKU],
            p.[StyleCode],
            p.[Category],
            p.[Size],
            p.[ListPrice],
            [Base] = CASE p.[Category]
                        WHEN N'Kurtki'   THEN 0.55
                        WHEN N'Sukienki' THEN 0.85
                        WHEN N'Swetry'   THEN 0.75
                        WHEN N'Jeansy'   THEN 0.95
                        WHEN N'T-shirty' THEN 1.35
                        WHEN N'Koszule'  THEN 0.60
                        ELSE                  0.70
                     END,
            [SizeShare] = CASE p.[Size]
                        WHEN N'XS' THEN 0.08
                        WHEN N'S'  THEN 0.22
                        WHEN N'M'  THEN 0.30
                        WHEN N'L'  THEN 0.28
                        WHEN N'XL' THEN 0.12
                        ELSE            1.00
                     END,
            [ColorShare] = CASE WHEN ROW_NUMBER() OVER (PARTITION BY p.[StyleCode], p.[Size]
                                                        ORDER BY p.[Color]) = 1
                                THEN 0.58 ELSE 0.42 END,
            -- Share of the season's intake that is still expected to be on the
            -- shelf at the end of the month, by size.
            [TargetSellThrough] = CASE p.[Size]
                        WHEN N'XS' THEN 0.50
                        WHEN N'S'  THEN 0.78
                        WHEN N'M'  THEN 0.90
                        WHEN N'L'  THEN 0.88
                        WHEN N'XL' THEN 0.55
                        ELSE            0.75
                     END
    INTO    #Prod
    FROM    [dbo].[DimProduct] AS p;

    SELECT  s.[StoreCode],
            s.[Channel],
            [StoreFactor] = CASE s.[StoreCode]
                        WHEN N'S-WAW-01' THEN 1.60
                        WHEN N'S-WAW-02' THEN 1.00
                        WHEN N'S-KRK-01' THEN 0.80
                        WHEN N'S-POZ-01' THEN 1.15
                        WHEN N'S-GDA-01' THEN 0.90
                        ELSE                  1.45
                     END
    INTO    #Store
    FROM    [dbo].[DimStore] AS s;

    -- -----------------------------------------------------------------------
    -- One row per sold line. A line exists on a day when the deterministic
    -- draw falls under that day's demand for the store/SKU combination.
    -- -----------------------------------------------------------------------
    SELECT  d.[Date],
            d.[DateKey],
            d.[YearMonth],
            st.[StoreCode],
            st.[Channel],
            p.[SKU],
            p.[StyleCode],
            p.[Category],
            p.[Size],
            [UnitPrice] = p.[ListPrice],
            -- How many separate receipts contained this SKU on this day.
            [Receipts]  = rc.[Receipts],
            [DiscountPct] = CASE
                        WHEN p.[Category] = N'Sukienki'
                             AND d.[Date] BETWEEN '2026-03-02' AND '2026-03-22' THEN 0.30
                        WHEN d.[Date] BETWEEN '2025-11-24' AND '2025-11-30' THEN 0.20
                        ELSE 0.00
                     END
    INTO    #Lines
    FROM    [dbo].[DimDate] AS d
    CROSS JOIN #Store       AS st
    CROSS JOIN #Prod        AS p
    CROSS APPLY (SELECT
                    [Rnd]  = (ABS(CHECKSUM(CONCAT(st.[StoreCode], N'|', p.[SKU], N'|', d.[DateKey]))) % 10000) / 10000.0,
                    [Rnd2] = (ABS(CHECKSUM(CONCAT(p.[SKU], N'#', st.[StoreCode], N'#', d.[DateKey]))) % 10000) / 10000.0,
                    [Doy]  = DATEPART(DAYOFYEAR, d.[Date])
                ) AS r
    -- Seasonality is a smooth yearly curve per category: [Peak] is the day of
    -- year the category sells best, [Amp] how pronounced the season is.
    CROSS APPLY (SELECT
                    [Peak] = CASE p.[Category]
                                WHEN N'Kurtki'   THEN 345 WHEN N'Swetry'   THEN 340
                                WHEN N'Sukienki' THEN 185 WHEN N'T-shirty' THEN 195
                                WHEN N'Koszule'  THEN 300 WHEN N'Jeansy'   THEN 285
                                ELSE 345 END,
                    [Amp]  = CASE p.[Category]
                                WHEN N'Kurtki'   THEN 0.85 WHEN N'Swetry'   THEN 0.72
                                WHEN N'Sukienki' THEN 0.50 WHEN N'T-shirty' THEN 0.55
                                WHEN N'Koszule'  THEN 0.20 WHEN N'Jeansy'   THEN 0.18
                                ELSE 0.30 END
                ) AS sea
    CROSS APPLY (SELECT [Demand] =
                    p.[Base] * p.[SizeShare] * p.[ColorShare] * st.[StoreFactor]
                  -- Day-of-week pattern: stores peak on Saturday, the online
                  -- shop peaks on Sunday and Monday.
                  * CASE WHEN st.[Channel] = N'ONLINE'
                         THEN CHOOSE(d.[DayOfWeek], 1.10, 1.05, 1.00, 1.00, 0.95, 0.90, 1.15)
                         ELSE CHOOSE(d.[DayOfWeek], 0.75, 0.78, 0.85, 0.95, 1.20, 1.60, 0.95)
                    END
                  * (1 + sea.[Amp] * COS(2 * PI() * (r.[Doy] - sea.[Peak]) / 365.0))
                  * (1 + 0.85 * EXP(-SQUARE((r.[Doy] - 349) / 11.0)))
                  * CASE WHEN d.[Date] BETWEEN '2025-11-24' AND '2025-11-30' THEN 1.90 ELSE 1.00 END
                  * (1 + 0.06 * DATEDIFF(DAY, @SalesFrom, d.[Date]) / 628.0)
                  * CASE WHEN st.[StoreCode] = N'S-KRK-01' AND d.[Date] >= '2026-04-01' THEN 1.26 ELSE 1.00 END
                  * CASE WHEN p.[Category] = N'Sukienki'
                              AND d.[Date] BETWEEN '2026-03-02' AND '2026-03-22' THEN 1.55 ELSE 1.00 END
                ) AS m
    -- Turn expected demand into a whole number of receipts. The fractional
    -- part decides probabilistically, so slow sellers still appear only on
    -- some days while fast sellers keep a stable daily rate.
    CROSS APPLY (SELECT [Receipts] =
                    CAST(m.[Demand] * 3.6 AS INT)
                  + CASE WHEN (m.[Demand] * 3.6) - CAST(m.[Demand] * 3.6 AS INT) > r.[Rnd]
                         THEN 1 ELSE 0 END
                ) AS rc
    WHERE   d.[Date] BETWEEN @SalesFrom AND @SalesTo
        AND rc.[Receipts] >= 1

        AND NOT (p.[StyleCode] IN (N'W-JKT-001', N'W-JKT-002')
                 AND p.[Size] IN (N'M', N'L')
                 AND st.[StoreCode] IN (N'S-WAW-01', N'S-WAW-02', N'S-POZ-01', N'S-GDA-01')
                 AND d.[Date] >= '2026-09-14');

    CREATE CLUSTERED INDEX [IX_Lines] ON #Lines ([StoreCode], [SKU], [Date]);

    -- -----------------------------------------------------------------------
    -- Expand into individual receipt lines and group them into receipts:
    -- roughly 2.3 lines per transaction.
    -- -----------------------------------------------------------------------
    SELECT  l.[Date],
            l.[DateKey],
            l.[YearMonth],
            l.[StoreCode],
            l.[Channel],
            l.[SKU],
            l.[StyleCode],
            l.[Category],
            l.[Size],
            l.[UnitPrice],
            l.[DiscountPct],
            [Quantity] = 1 + CASE WHEN (n.[i] * 37 + LEN(l.[SKU]) * 11) % 100 < 18 THEN 1 ELSE 0 END,
            [Basket]   = (CAST(ROW_NUMBER() OVER (PARTITION BY l.[Date], l.[StoreCode]
                                                  ORDER BY n.[i], l.[SKU]) - 1 AS INT) * 10) / 23 + 1,
            [Seq]      = ROW_NUMBER() OVER (PARTITION BY l.[Date], l.[StoreCode]
                                            ORDER BY n.[i], l.[SKU])
    INTO    #Baskets
    FROM    #Lines AS l
    CROSS APPLY (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)) AS n ([i])
    WHERE   n.[i] <= l.[Receipts];

    CREATE CLUSTERED INDEX [IX_Baskets] ON #Baskets ([StoreCode], [SKU], [Date]);

    INSERT INTO [src].[SalesRaw]
        ([TransactionNo], [LineNumber], [SalesDate], [SKU], [StoreCode],
         [Quantity], [UnitPrice], [DiscountAmount], [SourceFile])
    SELECT  CONCAT(N'T-', b.[StoreCode], N'-', CONVERT(CHAR (8), b.[Date], 112), N'-',
                   RIGHT(CONCAT(N'0000', b.[Basket]), 4)),
            CAST(ROW_NUMBER() OVER (PARTITION BY b.[Date], b.[StoreCode], b.[Basket]
                                    ORDER BY b.[Seq]) AS NVARCHAR (10)),
            CONVERT(NVARCHAR (10), b.[Date], 23),
            b.[SKU],
            b.[StoreCode],
            CAST(b.[Quantity] AS NVARCHAR (20)),
            CAST(b.[UnitPrice] AS NVARCHAR (20)),
            CAST(CAST(ROUND(b.[Quantity] * b.[UnitPrice] * b.[DiscountPct], 2) AS DECIMAL (10, 2)) AS NVARCHAR (20)),
            CONCAT(CASE WHEN b.[Channel] = N'ONLINE' THEN N'WEB_' ELSE N'POS_' END,
                   CONVERT(CHAR (8), b.[Date], 112), N'.csv')
    FROM    #Baskets AS b;

    PRINT N'    src.SalesRaw: ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' rows';

    -- Second copy of one day's point-of-sale export.
    INSERT INTO [src].[SalesRaw]
        ([TransactionNo], [LineNumber], [SalesDate], [SKU], [StoreCode],
         [Quantity], [UnitPrice], [DiscountAmount], [SourceFile])
    SELECT  [TransactionNo], [LineNumber], [SalesDate], [SKU], [StoreCode],
            [Quantity], [UnitPrice], [DiscountAmount],
            N'POS_20260817_RETRY.csv'
    FROM    [src].[SalesRaw]
    WHERE   [SalesDate] = N'2026-08-17'
        AND [SourceFile] = N'POS_20260817.csv';

    PRINT N'    src.SalesRaw: ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' extra rows';

    -- -----------------------------------------------------------------------
    -- Stock feed. Each store takes one delivery for the season and sells it
    -- down; the closing stock of a day is what the feed reports.
    -- -----------------------------------------------------------------------
    SELECT  [StoreCode], [SKU], [Units] = SUM([Quantity])
    INTO    #SeasonUnits
    FROM    #Baskets
    WHERE   [Date] >= @StockFrom
    GROUP BY [StoreCode], [SKU];

    SELECT  [Date], [StoreCode], [SKU], [Units] = SUM([Quantity])
    INTO    #DailyUnits
    FROM    #Baskets
    GROUP BY [Date], [StoreCode], [SKU];

    CREATE CLUSTERED INDEX [IX_DailyUnits] ON #DailyUnits ([StoreCode], [SKU], [Date]);

    SELECT  su.[StoreCode],
            su.[SKU],
            [Allocation] = CASE WHEN CEILING(su.[Units] / p.[TargetSellThrough]) < 3
                                THEN 3
                                ELSE CEILING(su.[Units] / p.[TargetSellThrough]) END
    INTO    #Allocation
    FROM    #SeasonUnits AS su
    JOIN    #Prod        AS p ON p.[SKU] = su.[SKU];

    CREATE CLUSTERED INDEX [IX_Allocation] ON #Allocation ([StoreCode], [SKU]);

    INSERT INTO [src].[InventoryRaw]
        ([SnapshotDate], [SKU], [StoreCode], [StockQuantity], [SourceFile])
    SELECT  CONVERT(NVARCHAR (10), g.[Date], 23),
            g.[SKU],
            g.[StoreCode],
            CAST(CASE WHEN g.[Allocation] - g.[SoldToDate] < 0 THEN 0
                      ELSE g.[Allocation] - g.[SoldToDate] END AS NVARCHAR (20)),
            CONCAT(N'WMS_', CONVERT(CHAR (8), g.[Date], 112), N'.csv')
    FROM (
        SELECT  d.[Date],
                st.[StoreCode],
                p.[SKU],
                [Allocation] = CASE
                        WHEN p.[StyleCode] IN (N'W-JKT-001', N'W-JKT-002')
                             AND p.[Size] IN (N'M', N'L')
                             AND st.[StoreCode] IN (N'S-WAW-01', N'S-WAW-02', N'S-POZ-01', N'S-GDA-01')
                        THEN ISNULL(su.[Units], 0)
                        ELSE ISNULL(a.[Allocation], 3)
                    END,
                [SoldToDate] = SUM(ISNULL(du.[Units], 0)) OVER (
                                   PARTITION BY st.[StoreCode], p.[SKU]
                                   ORDER BY d.[Date] ROWS UNBOUNDED PRECEDING)
        FROM    [dbo].[DimDate] AS d
        CROSS JOIN #Store       AS st
        CROSS JOIN #Prod        AS p
        LEFT JOIN #Allocation   AS a  ON a.[StoreCode] = st.[StoreCode]
                                     AND a.[SKU]       = p.[SKU]
        LEFT JOIN #SeasonUnits  AS su ON su.[StoreCode] = st.[StoreCode]
                                     AND su.[SKU]       = p.[SKU]
        LEFT JOIN #DailyUnits   AS du ON du.[StoreCode] = st.[StoreCode]
                                     AND du.[SKU]       = p.[SKU]
                                     AND du.[Date]      = d.[Date]
        WHERE   d.[Date] BETWEEN @StockFrom AND @SalesTo
            AND NOT (st.[StoreCode] = N'S-POZ-01'
                     AND d.[Date] BETWEEN '2026-06-10' AND '2026-06-12')
    ) AS g;

    PRINT N'    src.InventoryRaw: ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' rows';

    -- -----------------------------------------------------------------------
    -- Returns.
    -- -----------------------------------------------------------------------
    INSERT INTO [src].[ReturnsRaw]
        ([ReturnNo], [TransactionNo], [ReturnDate], [SKU], [StoreCode],
         [Quantity], [ReturnAmount], [ReturnReason], [SourceFile])
    SELECT  CONCAT(N'R-', CONVERT(CHAR (8), s.[ReturnDate], 112), N'-',
                   RIGHT(CONCAT(N'000000', ROW_NUMBER() OVER (ORDER BY s.[ReturnDate], s.[TransactionNo], s.[SKU])), 6)),
            s.[TransactionNo],
            CONVERT(NVARCHAR (10), s.[ReturnDate], 23),
            s.[SKU],
            s.[StoreCode],
            N'1',
            CAST(s.[UnitPrice] AS NVARCHAR (20)),
            s.[ReturnReason],
            CONCAT(N'RET_', CONVERT(CHAR (6), s.[ReturnDate], 112), N'.csv')
    FROM (
        SELECT  b.[TransactionNo],
                b.[SKU],
                b.[StoreCode],
                b.[UnitPrice],
                [ReturnDate] = DATEADD(DAY, 3 + CAST(rr.[Rnd] * 18 AS INT), b.[Date]),
                [ReturnReason] = CASE
                        -- One-size items are never sent back for a bad fit.
                        WHEN b.[Size] = N'ONE' THEN
                            CASE WHEN rr.[Rnd2] < 0.62 THEN N'CHANGED_MIND'
                                 WHEN rr.[Rnd2] < 0.88 THEN N'DAMAGED'
                                 ELSE N'OTHER' END
                        WHEN b.[Channel] = N'ONLINE' AND b.[StyleCode] = N'W-JNS-003' THEN
                            CASE WHEN rr.[Rnd2] < 0.70 THEN N'WRONG_SIZE'
                                 WHEN rr.[Rnd2] < 0.88 THEN N'CHANGED_MIND'
                                 WHEN rr.[Rnd2] < 0.95 THEN N'DAMAGED'
                                 ELSE N'OTHER' END
                        WHEN b.[Channel] = N'ONLINE' THEN
                            CASE WHEN rr.[Rnd2] < 0.45 THEN N'WRONG_SIZE'
                                 WHEN rr.[Rnd2] < 0.80 THEN N'CHANGED_MIND'
                                 WHEN rr.[Rnd2] < 0.92 THEN N'DAMAGED'
                                 ELSE N'OTHER' END
                        ELSE
                            CASE WHEN rr.[Rnd2] < 0.45 THEN N'CHANGED_MIND'
                                 WHEN rr.[Rnd2] < 0.70 THEN N'WRONG_SIZE'
                                 WHEN rr.[Rnd2] < 0.90 THEN N'DAMAGED'
                                 ELSE N'OTHER' END
                    END
        FROM (
            SELECT  CONCAT(N'T-', l.[StoreCode], N'-', CONVERT(CHAR (8), l.[Date], 112), N'-',
                           RIGHT(CONCAT(N'0000', l.[Basket]), 4)) AS [TransactionNo],
                    l.[Date], l.[SKU], l.[StoreCode], l.[Channel], l.[StyleCode], l.[Size], l.[UnitPrice]
            FROM    #Baskets AS l
        ) AS b
        CROSS APPLY (SELECT
                        [Rnd]  = (ABS(CHECKSUM(CONCAT(N'ret', b.[TransactionNo], b.[SKU]))) % 10000) / 10000.0,
                        [Rnd2] = (ABS(CHECKSUM(CONCAT(b.[SKU], N'ret', b.[TransactionNo]))) % 10000) / 10000.0
                    ) AS rr
        WHERE   rr.[Rnd] < CASE
                    WHEN b.[Channel] = N'ONLINE' AND b.[StyleCode] = N'W-JNS-003' THEN 0.34
                    WHEN b.[Channel] = N'ONLINE'                                  THEN 0.18
                    ELSE                                                               0.04
                END
    ) AS s
    WHERE   s.[ReturnDate] <= @SalesTo;

    PRINT N'    src.ReturnsRaw: ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' rows';

    DROP TABLE #Prod, #Store, #Lines, #Baskets, #SeasonUnits, #DailyUnits, #Allocation;
END
ELSE
BEGIN
    PRINT N'    [src] already populated, skipping';
END
