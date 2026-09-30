/*
    Loads customer returns from the landing zone into the warehouse.

    Step 1: [src].[ReturnsRaw] -> [stg].[Returns]
    Step 2: [stg].[Returns]    -> [dbo].[FactReturns]

    Full reload, same pattern as [etl].[LoadSales].
*/
CREATE PROCEDURE [etl].[LoadReturns]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoadId INT, @RowsRead INT, @RowsLoaded INT, @RowsRejected INT;

    INSERT INTO [dbo].[LoadLog] ([PackageName]) VALUES (N'etl.LoadReturns');
    SET @LoadId = CAST(SCOPE_IDENTITY() AS INT);

    BEGIN TRY
        SELECT @RowsRead = COUNT(*) FROM [src].[ReturnsRaw];

        DELETE FROM [dbo].[FactReturns];
        DELETE FROM [stg].[Returns];

        INSERT INTO [stg].[Returns]
            ([ReturnNo], [TransactionNo], [ReturnDate], [SKU], [StoreCode],
             [Quantity], [ReturnAmount], [ReturnReason], [SourceFile], [LoadId])
        SELECT  r.[ReturnNo],
                r.[TransactionNo],
                TRY_CAST(r.[ReturnDate] AS DATE),
                r.[SKU],
                r.[StoreCode],
                TRY_CAST(r.[Quantity] AS INT),
                TRY_CAST(r.[ReturnAmount] AS DECIMAL (10, 2)),
                r.[ReturnReason],
                r.[SourceFile],
                @LoadId
        FROM    [src].[ReturnsRaw] AS r
        WHERE   r.[ReturnNo]                                IS NOT NULL
            AND r.[TransactionNo]                           IS NOT NULL
            AND TRY_CAST(r.[ReturnDate]   AS DATE)          IS NOT NULL
            AND r.[SKU]                                     IS NOT NULL
            AND r.[StoreCode]                               IS NOT NULL
            AND TRY_CAST(r.[Quantity]     AS INT)           IS NOT NULL
            AND TRY_CAST(r.[ReturnAmount] AS DECIMAL (10, 2)) IS NOT NULL;

        INSERT INTO [dbo].[FactReturns]
            ([DateKey], [ProductKey], [StoreKey], [ReturnNo], [TransactionNo],
             [Quantity], [ReturnAmount], [ReturnReason], [LoadId])
        SELECT  d.[DateKey],
                p.[ProductKey],
                st.[StoreKey],
                t.[ReturnNo],
                t.[TransactionNo],
                t.[Quantity],
                t.[ReturnAmount],
                t.[ReturnReason],
                @LoadId
        FROM    [stg].[Returns]    AS t
        JOIN    [dbo].[DimDate]    AS d  ON d.[Date]       = t.[ReturnDate]
        JOIN    [dbo].[DimProduct] AS p  ON p.[SKU]        = t.[SKU]
        JOIN    [dbo].[DimStore]   AS st ON st.[StoreCode] = t.[StoreCode];

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
