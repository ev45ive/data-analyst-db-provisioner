/*
    Calendar dimension. One row per day.

    [YearWeek] uses the ISO-8601 week numbering, which is what the trading
    calendar in the weekly reports is based on - note that the ISO year can
    differ from the calendar year around 1 January.
*/
CREATE TABLE [dbo].[DimDate]
(
    [DateKey]    INT           NOT NULL, -- yyyymmdd
    [Date]       DATE          NOT NULL,
    [Year]       SMALLINT      NOT NULL,
    [Quarter]    TINYINT       NOT NULL,
    [Month]      TINYINT       NOT NULL,
    [MonthName]  NVARCHAR (20) NOT NULL,
    [YearMonth]  NVARCHAR (7)  NOT NULL, -- '2026-09'
    [IsoYear]    SMALLINT      NOT NULL,
    [IsoWeek]    TINYINT       NOT NULL,
    [YearWeek]   NVARCHAR (8)  NOT NULL, -- '2026-W38'
    [DayOfWeek]  TINYINT       NOT NULL, -- 1 = Monday
    [DayName]    NVARCHAR (20) NOT NULL,
    [IsWeekend]  BIT           NOT NULL,
    [Season]     NVARCHAR (10) NOT NULL, -- retail season the day belongs to
    CONSTRAINT [PK_DimDate] PRIMARY KEY CLUSTERED ([DateKey] ASC)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DimDate_Date]
    ON [dbo].[DimDate] ([Date] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_DimDate_YearWeek]
    ON [dbo].[DimDate] ([YearWeek] ASC);
