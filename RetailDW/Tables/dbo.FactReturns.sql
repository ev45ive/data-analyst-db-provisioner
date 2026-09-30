/*
    Returns fact. Grain: one row per returned line.

    [ReturnAmount] is the refunded amount, VAT included, and is stored as a
    positive number.
*/
CREATE TABLE [dbo].[FactReturns]
(
    [ReturnKey]     BIGINT          IDENTITY (1, 1) NOT NULL,
    [DateKey]       INT             NOT NULL,
    [ProductKey]    INT             NOT NULL,
    [StoreKey]      INT             NOT NULL,
    [ReturnNo]      NVARCHAR (30)   NOT NULL,
    [TransactionNo] NVARCHAR (30)   NOT NULL,
    [Quantity]      INT             NOT NULL,
    [ReturnAmount]  DECIMAL (12, 2) NOT NULL,
    [ReturnReason]  NVARCHAR (30)   NULL,
    [LoadId]        INT             NOT NULL,
    CONSTRAINT [PK_FactReturns] PRIMARY KEY CLUSTERED ([ReturnKey] ASC),
    CONSTRAINT [FK_FactReturns_DimDate] FOREIGN KEY ([DateKey]) REFERENCES [dbo].[DimDate] ([DateKey]),
    CONSTRAINT [FK_FactReturns_DimProduct] FOREIGN KEY ([ProductKey]) REFERENCES [dbo].[DimProduct] ([ProductKey]),
    CONSTRAINT [FK_FactReturns_DimStore] FOREIGN KEY ([StoreKey]) REFERENCES [dbo].[DimStore] ([StoreKey])
);
GO

CREATE NONCLUSTERED INDEX [IX_FactReturns_DateKey]
    ON [dbo].[FactReturns] ([DateKey] ASC)
    INCLUDE ([ProductKey], [StoreKey], [Quantity], [ReturnAmount]);
