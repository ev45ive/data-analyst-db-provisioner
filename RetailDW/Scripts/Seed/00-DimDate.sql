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
