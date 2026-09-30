/*
    Landing zone for the nightly stock feed sent by the warehouse system (WMS).

    One row per store / SKU / day, holding the closing stock level. Stores send
    their own files, so a store that does not report simply produces no rows.
*/
CREATE TABLE [src].[InventoryRaw]
(
    [RawId]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [SnapshotDate]  NVARCHAR (20)  NULL,
    [SKU]           NVARCHAR (40)  NULL,
    [StoreCode]     NVARCHAR (20)  NULL,
    [StockQuantity] NVARCHAR (20)  NULL,
    [SourceFile]    NVARCHAR (100) NULL,
    [ExtractedAt]   DATETIME2 (3)  NOT NULL CONSTRAINT [DF_src_InventoryRaw_ExtractedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_src_InventoryRaw] PRIMARY KEY CLUSTERED ([RawId] ASC)
);
