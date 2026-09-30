/*
    Typed, validated stock levels. Populated by [etl].[LoadInventory] from
    [src].[InventoryRaw].
*/
CREATE TABLE [stg].[Inventory]
(
    [StagingRowId]  BIGINT         IDENTITY (1, 1) NOT NULL,
    [SnapshotDate]  DATE           NOT NULL,
    [SKU]           NVARCHAR (40)  NOT NULL,
    [StoreCode]     NVARCHAR (20)  NOT NULL,
    [StockQuantity] INT            NOT NULL,
    [SourceFile]    NVARCHAR (100) NULL,
    [LoadId]        INT            NOT NULL,
    CONSTRAINT [PK_stg_Inventory] PRIMARY KEY CLUSTERED ([StagingRowId] ASC)
);
GO

CREATE NONCLUSTERED INDEX [IX_stg_Inventory_SnapshotDate]
    ON [stg].[Inventory] ([SnapshotDate] ASC);
