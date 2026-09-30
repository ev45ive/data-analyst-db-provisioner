/*
Post-deployment script
----------------------
Runs AFTER the schema diff is applied.

  1. Seeds the dimensions.
  2. Prepares the landing zone ([src]).
  3. Runs the three load procedures so the warehouse is queryable.

Every step is guarded, so publishing an already-populated database is a no-op.
*/
PRINT N'[PostDeployment] start';
GO

PRINT N'  seeding [dbo].[DimDate]';

IF NOT EXISTS (SELECT 1 FROM [dbo].[DimDate])
BEGIN
    DECLARE @CalendarFrom DATE = '2024-12-01',
            @CalendarTo   DATE = '2026-12-31';

    ;WITH [Sequence] AS
    (
        SELECT TOP (DATEDIFF(DAY, @CalendarFrom, @CalendarTo) + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS [Offset]
        FROM   sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    ),
    [Calendar] AS
    (
        SELECT DATEADD(DAY, [Offset], @CalendarFrom) AS [Date] FROM [Sequence]
    )
    INSERT INTO [dbo].[DimDate]
        ([DateKey], [Date], [Year], [Quarter], [Month], [MonthName], [YearMonth],
         [IsoYear], [IsoWeek], [YearWeek], [DayOfWeek], [DayName], [IsWeekend], [Season])
    SELECT
        CONVERT(INT, CONVERT(CHAR (8), c.[Date], 112)),
        c.[Date],
        DATEPART(YEAR, c.[Date]),
        DATEPART(QUARTER, c.[Date]),
        DATEPART(MONTH, c.[Date]),
        CHOOSE(DATEPART(MONTH, c.[Date]),
               N'Styczen', N'Luty', N'Marzec', N'Kwiecien', N'Maj', N'Czerwiec',
               N'Lipiec', N'Sierpien', N'Wrzesien', N'Pazdziernik', N'Listopad', N'Grudzien'),
        CONVERT(CHAR (7), c.[Date], 126),
        -- The ISO year is the year that owns the ISO week, which is not always
        -- the calendar year: 2025-12-29 belongs to ISO week 1 of 2026.
        DATEPART(YEAR, DATEADD(DAY, 26 - DATEPART(ISO_WEEK, c.[Date]), c.[Date])),
        DATEPART(ISO_WEEK, c.[Date]),
        CONCAT(DATEPART(YEAR, DATEADD(DAY, 26 - DATEPART(ISO_WEEK, c.[Date]), c.[Date])),
               N'-W', RIGHT(N'0' + CAST(DATEPART(ISO_WEEK, c.[Date]) AS NVARCHAR (2)), 2)),
        ((DATEPART(WEEKDAY, c.[Date]) + @@DATEFIRST - 2) % 7) + 1,
        CHOOSE(((DATEPART(WEEKDAY, c.[Date]) + @@DATEFIRST - 2) % 7) + 1,
               N'Poniedzialek', N'Wtorek', N'Sroda', N'Czwartek', N'Piatek', N'Sobota', N'Niedziela'),
        CASE WHEN ((DATEPART(WEEKDAY, c.[Date]) + @@DATEFIRST - 2) % 7) + 1 >= 6 THEN 1 ELSE 0 END,
        -- Retail seasons: spring/summer runs February-July, autumn/winter August-January.
        CASE WHEN DATEPART(MONTH, c.[Date]) BETWEEN 2 AND 7
             THEN CONCAT(N'SS', RIGHT(CAST(DATEPART(YEAR, c.[Date]) AS NVARCHAR (4)), 2))
             WHEN DATEPART(MONTH, c.[Date]) = 1
             THEN CONCAT(N'AW', RIGHT(CAST(DATEPART(YEAR, c.[Date]) - 1 AS NVARCHAR (4)), 2))
             ELSE CONCAT(N'AW', RIGHT(CAST(DATEPART(YEAR, c.[Date]) AS NVARCHAR (4)), 2))
        END
    FROM [Calendar] AS c;

    PRINT N'    ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' days';
END

GO

PRINT N'  seeding [dbo].[DimProduct]';

IF NOT EXISTS (SELECT 1 FROM [dbo].[DimProduct])
BEGIN
    DECLARE @Styles TABLE
    (
        [StyleCode]  NVARCHAR (20)   NOT NULL,
        [StyleName]  NVARCHAR (100)  NOT NULL,
        [Department] NVARCHAR (20)   NOT NULL,
        [Category]   NVARCHAR (30)   NOT NULL,
        [ListPrice]  DECIMAL (10, 2) NOT NULL,
        [UnitCost]   DECIMAL (10, 2) NOT NULL,
        [Color1]     NVARCHAR (20)   NOT NULL,
        [Code1]      NVARCHAR (3)    NOT NULL,
        [Color2]     NVARCHAR (20)   NOT NULL,
        [Code2]      NVARCHAR (3)    NOT NULL,
        [Sized]      BIT             NOT NULL
    );

    INSERT INTO @Styles VALUES
        (N'W-JKT-001', N'Kurtka pikowana damska', N'WOMEN',  N'Kurtki',    399.00, 148.00, N'Czarny',    N'CZA', N'Piaskowy',   N'PIA', 1),
        (N'W-JKT-002', N'Parka damska',           N'WOMEN',  N'Kurtki',    499.00, 189.00, N'Khaki',     N'KHA', N'Czarny',     N'CZA', 1),
        (N'W-DRS-001', N'Sukienka midi',          N'WOMEN',  N'Sukienki',  199.00,  62.00, N'Czarny',    N'CZA', N'Bordowy',    N'BOR', 1),
        (N'W-DRS-002', N'Sukienka koszulowa',     N'WOMEN',  N'Sukienki',  179.00,  55.00, N'Granatowy', N'GRA', N'Ecru',       N'ECR', 1),
        (N'W-KNT-001', N'Sweter oversize',        N'WOMEN',  N'Swetry',    159.00,  48.00, N'Szary',     N'SZA', N'Kremowy',    N'KRE', 1),
        (N'W-JNS-003', N'Jeansy skinny',          N'WOMEN',  N'Jeansy',    169.00,  52.00, N'Niebieski', N'NIE', N'Czarny',     N'CZA', 1),
        (N'W-TSH-001', N'T-shirt basic damski',   N'WOMEN',  N'T-shirty',   59.00,  14.00, N'Ecru',      N'ECR', N'Czarny',     N'CZA', 1),
        (N'M-JKT-001', N'Kurtka miejska',         N'MEN',    N'Kurtki',    429.00, 160.00, N'Czarny',    N'CZA', N'Granatowy',  N'GRA', 1),
        (N'M-KNT-001', N'Sweter z dzianiny',      N'MEN',    N'Swetry',    179.00,  54.00, N'Granatowy', N'GRA', N'Szary',      N'SZA', 1),
        (N'M-JNS-001', N'Jeansy regular',         N'MEN',    N'Jeansy',    189.00,  58.00, N'Niebieski', N'NIE', N'Grafitowy',  N'GRF', 1),
        (N'M-TSH-001', N'T-shirt basic',          N'MEN',    N'T-shirty',   59.00,  14.00, N'Ecru',      N'ECR', N'Czarny',     N'CZA', 1),
        (N'M-SHI-001', N'Koszula oxford',         N'MEN',    N'Koszule',   199.00,  60.00, N'Ecru',      N'ECR', N'Lazurowy',   N'LAZ', 1),
        (N'A-BAG-001', N'Torebka shopper',        N'WOMEN',  N'Akcesoria', 249.00,  78.00, N'Czarny',    N'CZA', N'Koniakowy',  N'KON', 0),
        (N'A-SCF-001', N'Szalik zimowy',          N'UNISEX', N'Akcesoria',  89.00,  26.00, N'Szary',     N'SZA', N'Bordowy',    N'BOR', 0);

    DECLARE @Sizes TABLE ([Size] NVARCHAR (5) NOT NULL, [Sized] BIT NOT NULL);
    INSERT INTO @Sizes VALUES (N'XS', 1), (N'S', 1), (N'M', 1), (N'L', 1), (N'XL', 1), (N'ONE', 0);

    INSERT INTO [dbo].[DimProduct]
        ([SKU], [StyleCode], [StyleName], [Department], [Category], [Color], [Size],
         [ListPrice], [UnitCost], [IsActive])
    SELECT  CONCAT(s.[StyleCode], N'-', c.[Code], N'-', z.[Size]),
            s.[StyleCode],
            s.[StyleName],
            s.[Department],
            s.[Category],
            c.[Color],
            z.[Size],
            s.[ListPrice],
            s.[UnitCost],
            1
    FROM    @Styles AS s
    CROSS APPLY (VALUES (s.[Color1], s.[Code1]), (s.[Color2], s.[Code2])) AS c ([Color], [Code])
    JOIN    @Sizes  AS z ON z.[Sized] = s.[Sized]
    ORDER BY s.[StyleCode], c.[Code], z.[Size];

    PRINT N'    ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' SKUs';
END

GO

PRINT N'  seeding [dbo].[DimStore]';

IF NOT EXISTS (SELECT 1 FROM [dbo].[DimStore])
BEGIN
    INSERT INTO [dbo].[DimStore]
        ([StoreCode], [StoreName], [City], [Region], [Channel], [Format],
         [SalesAreaM2], [OpenedDate], [RemodelDate])
    VALUES
        (N'S-WAW-01', N'Warszawa Arkadia',      N'Warszawa', N'Mazowieckie',   N'STORE',  N'Galeria',      420,  '2016-04-15', NULL),
        (N'S-WAW-02', N'Warszawa Mokotow',      N'Warszawa', N'Mazowieckie',   N'STORE',  N'Galeria',      260,  '2019-09-01', NULL),
        (N'S-KRK-01', N'Krakow Rynek',          N'Krakow',   N'Malopolskie',   N'STORE',  N'Ulica',        320,  '2017-11-20', '2026-04-01'),
        (N'S-POZ-01', N'Poznan Stary Browar',   N'Poznan',   N'Wielkopolskie', N'STORE',  N'Galeria',      300,  '2018-03-10', NULL),
        (N'S-GDA-01', N'Gdansk Forum',          N'Gdansk',   N'Pomorskie',     N'STORE',  N'Galeria',      240,  '2021-10-05', NULL),
        (N'S-ONL-01', N'Sklep internetowy',     N'-',        N'Online',        N'ONLINE', N'E-commerce',   NULL, '2015-01-01', NULL);

    PRINT N'    ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' stores';
END

GO

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

GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[FactSales])
BEGIN
    PRINT N'  running the load procedures';
    EXEC [etl].[LoadSales];
    EXEC [etl].[LoadInventory];
    EXEC [etl].[LoadReturns];
END
GO

PRINT N'[PostDeployment] end';
GO
