/*
    Stock fact. Grain: one row per day / SKU / store, holding the stock level
    at the close of that trading day.

    This is a snapshot, not a movement log - two consecutive rows describe two
    states, and the difference between them is not a transaction.

    Stock is only collected for the current season; there are no rows for dates
    before the start of the feed.
*/
CREATE TABLE [dbo].[FactInventoryDaily]
(
    [InventoryKey]  BIGINT NOT NULL IDENTITY (1, 1),
    [DateKey]       INT    NOT NULL,
    [ProductKey]    INT    NOT NULL,
    [StoreKey]      INT    NOT NULL,
    [StockQuantity] INT    NOT NULL,
    [LoadId]        INT    NOT NULL,
    CONSTRAINT [PK_FactInventoryDaily] PRIMARY KEY CLUSTERED ([InventoryKey] ASC),
    CONSTRAINT [FK_FactInventoryDaily_DimDate] FOREIGN KEY ([DateKey]) REFERENCES [dbo].[DimDate] ([DateKey]),
    CONSTRAINT [FK_FactInventoryDaily_DimProduct] FOREIGN KEY ([ProductKey]) REFERENCES [dbo].[DimProduct] ([ProductKey]),
    CONSTRAINT [FK_FactInventoryDaily_DimStore] FOREIGN KEY ([StoreKey]) REFERENCES [dbo].[DimStore] ([StoreKey])
);
GO

CREATE NONCLUSTERED INDEX [IX_FactInventoryDaily_DateKey]
    ON [dbo].[FactInventoryDaily] ([DateKey] ASC)
    INCLUDE ([ProductKey], [StoreKey], [StockQuantity]);
