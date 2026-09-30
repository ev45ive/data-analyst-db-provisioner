/*
    Loads stock levels from the landing zone into the warehouse.

    Step 1: [src].[InventoryRaw] -> [stg].[Inventory]
    Step 2: [stg].[Inventory]    -> [dbo].[FactInventoryDaily]

    Full reload, same pattern as [etl].[LoadSales].
*/
CREATE PROCEDURE [etl].[LoadInventory]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoadId INT, @RowsRead INT, @RowsLoaded INT, @RowsRejected INT;

    INSERT INTO [dbo].[LoadLog] ([PackageName]) VALUES (N'etl.LoadInventory');
    SET @LoadId = CAST(SCOPE_IDENTITY() AS INT);

    BEGIN TRY
        SELECT @RowsRead = COUNT(*) FROM [src].[InventoryRaw];

        DELETE FROM [dbo].[FactInventoryDaily];
        DELETE FROM [stg].[Inventory];

        INSERT INTO [stg].[Inventory]
            ([SnapshotDate], [SKU], [StoreCode], [StockQuantity], [SourceFile], [LoadId])
        SELECT  TRY_CAST(r.[SnapshotDate] AS DATE),
                r.[SKU],
                r.[StoreCode],
                TRY_CAST(r.[StockQuantity] AS INT),
                r.[SourceFile],
                @LoadId
        FROM    [src].[InventoryRaw] AS r
        WHERE   TRY_CAST(r.[SnapshotDate]  AS DATE) IS NOT NULL
            AND r.[SKU]                             IS NOT NULL
            AND r.[StoreCode]                       IS NOT NULL
            AND TRY_CAST(r.[StockQuantity] AS INT)  IS NOT NULL;

        INSERT INTO [dbo].[FactInventoryDaily]
            ([DateKey], [ProductKey], [StoreKey], [StockQuantity], [LoadId])
        SELECT  d.[DateKey],
                p.[ProductKey],
                st.[StoreKey],
                i.[StockQuantity],
                @LoadId
        FROM    [stg].[Inventory]  AS i
        JOIN    [dbo].[DimDate]    AS d  ON d.[Date]       = i.[SnapshotDate]
        JOIN    [dbo].[DimProduct] AS p  ON p.[SKU]        = i.[SKU]
        JOIN    [dbo].[DimStore]   AS st ON st.[StoreCode] = i.[StoreCode];

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
