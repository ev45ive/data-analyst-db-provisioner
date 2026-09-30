/*
    Sales fact. Grain: one row per sold line of a transaction
    (one SKU within one receipt).

    [GrossAmount] = [Quantity] * [UnitPrice] - [DiscountAmount], VAT included.
    [NetAmount]   = [GrossAmount] / 1.23, VAT excluded.
    [UnitCost]    is copied from the product dimension at load time so that
                  margin can be recalculated without re-joining the dimension.
*/
CREATE TABLE [dbo].[FactSales]
(
    [SalesKey]       BIGINT          IDENTITY (1, 1) NOT NULL,
    [DateKey]        INT             NOT NULL,
    [ProductKey]     INT             NOT NULL,
    [StoreKey]       INT             NOT NULL,
    [TransactionNo]  NVARCHAR (30)   NOT NULL,
    [LineNumber]         INT             NOT NULL,
    [Quantity]       INT             NOT NULL,
    [UnitPrice]      DECIMAL (10, 2) NOT NULL,
    [DiscountAmount] DECIMAL (10, 2) NOT NULL,
    [GrossAmount]    DECIMAL (12, 2) NOT NULL,
    [NetAmount]      DECIMAL (12, 2) NOT NULL,
    [UnitCost]       DECIMAL (10, 2) NOT NULL,
    [LoadId]         INT             NOT NULL,
    CONSTRAINT [PK_FactSales] PRIMARY KEY CLUSTERED ([SalesKey] ASC),
    CONSTRAINT [FK_FactSales_DimDate] FOREIGN KEY ([DateKey]) REFERENCES [dbo].[DimDate] ([DateKey]),
    CONSTRAINT [FK_FactSales_DimProduct] FOREIGN KEY ([ProductKey]) REFERENCES [dbo].[DimProduct] ([ProductKey]),
    CONSTRAINT [FK_FactSales_DimStore] FOREIGN KEY ([StoreKey]) REFERENCES [dbo].[DimStore] ([StoreKey])
);
GO

CREATE NONCLUSTERED INDEX [IX_FactSales_DateKey]
    ON [dbo].[FactSales] ([DateKey] ASC)
    INCLUDE ([ProductKey], [StoreKey], [Quantity], [GrossAmount], [NetAmount]);
GO

CREATE NONCLUSTERED INDEX [IX_FactSales_ProductKey]
    ON [dbo].[FactSales] ([ProductKey] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_FactSales_TransactionNo]
    ON [dbo].[FactSales] ([TransactionNo] ASC);
