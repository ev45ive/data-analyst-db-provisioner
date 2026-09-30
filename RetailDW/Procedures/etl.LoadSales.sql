/*
    Loads sales from the landing zone into the warehouse.

    Step 1: [src].[SalesRaw] -> [stg].[Sales]      (type conversion, validation)
    Step 2: [stg].[Sales]    -> [dbo].[FactSales]  (dimension lookup, measures)

    Full reload: both targets are truncated first, so the procedure can be
    re-run at any time and always reflects the current content of the landing
    zone.
*/
CREATE PROCEDURE [etl].[LoadSales]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoadId INT, @RowsRead INT, @RowsLoaded INT, @RowsRejected INT;

    INSERT INTO [dbo].[LoadLog] ([PackageName]) VALUES (N'etl.LoadSales');
    SET @LoadId = CAST(SCOPE_IDENTITY() AS INT);

    BEGIN TRY
        SELECT @RowsRead = COUNT(*) FROM [src].[SalesRaw];

        DELETE FROM [dbo].[FactSales];
        DELETE FROM [stg].[Sales];

        -- Step 1: convert text to typed columns. A row that cannot be converted
        -- is dropped here and shows up in the rejected count below.
        INSERT INTO [stg].[Sales]
            ([TransactionNo], [LineNumber], [SalesDate], [SKU], [StoreCode],
             [Quantity], [UnitPrice], [DiscountAmount], [SourceFile], [LoadId])
        SELECT  r.[TransactionNo],
                TRY_CAST(r.[LineNumber] AS INT),
                TRY_CAST(r.[SalesDate] AS DATE),
                r.[SKU],
                r.[StoreCode],
                TRY_CAST(r.[Quantity] AS INT),
                TRY_CAST(r.[UnitPrice] AS DECIMAL (10, 2)),
                ISNULL(TRY_CAST(r.[DiscountAmount] AS DECIMAL (10, 2)), 0),
                r.[SourceFile],
                @LoadId
        FROM    [src].[SalesRaw] AS r
        WHERE   r.[TransactionNo]                       IS NOT NULL
            AND TRY_CAST(r.[LineNumber]    AS INT)          IS NOT NULL
            AND TRY_CAST(r.[SalesDate] AS DATE)         IS NOT NULL
            AND r.[SKU]                                 IS NOT NULL
            AND r.[StoreCode]                           IS NOT NULL
            AND TRY_CAST(r.[Quantity]  AS INT)          IS NOT NULL
            AND TRY_CAST(r.[UnitPrice] AS DECIMAL (10, 2)) IS NOT NULL;

        -- Step 2: resolve dimension keys and derive the measures.
        INSERT INTO [dbo].[FactSales]
            ([DateKey], [ProductKey], [StoreKey], [TransactionNo], [LineNumber],
             [Quantity], [UnitPrice], [DiscountAmount], [GrossAmount], [NetAmount],
             [UnitCost], [LoadId])
        SELECT  d.[DateKey],
                p.[ProductKey],
                st.[StoreKey],
                s.[TransactionNo],
                s.[LineNumber],
                s.[Quantity],
                s.[UnitPrice],
                s.[DiscountAmount],
                CAST(s.[Quantity] * s.[UnitPrice] - s.[DiscountAmount] AS DECIMAL (12, 2)),
                CAST((s.[Quantity] * s.[UnitPrice] - s.[DiscountAmount]) / 1.23 AS DECIMAL (12, 2)),
                p.[UnitCost],
                @LoadId
        FROM    [stg].[Sales]      AS s
        JOIN    [dbo].[DimDate]    AS d  ON d.[Date]      = s.[SalesDate]
        JOIN    [dbo].[DimProduct] AS p  ON p.[SKU]       = s.[SKU]
        JOIN    [dbo].[DimStore]   AS st ON st.[StoreCode] = s.[StoreCode];

        SET @RowsLoaded = @@ROWCOUNT;
        SET @RowsRejected = @RowsRead - @RowsLoaded;

        UPDATE  [dbo].[LoadLog]
        SET     [FinishedAt]   = SYSUTCDATETIME(),
                [Status]       = N'SUCCEEDED',
                [RowsRead]     = @RowsRead,
                [RowsLoaded]   = @RowsLoaded,
                [RowsRejected] = @RowsRejected
        WHERE   [LoadId] = @LoadId;
    END TRY
    BEGIN CATCH
        UPDATE  [dbo].[LoadLog]
        SET     [FinishedAt]   = SYSUTCDATETIME(),
                [Status]       = N'FAILED',
                [ErrorMessage] = ERROR_MESSAGE()
        WHERE   [LoadId] = @LoadId;
        THROW;
    END CATCH
END
