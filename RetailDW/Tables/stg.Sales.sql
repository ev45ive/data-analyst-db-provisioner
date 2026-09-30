/*
    Typed, validated sales rows. Populated by [etl].[LoadSales] from
    [src].[SalesRaw]; rows that fail conversion never reach this table.
*/
CREATE TABLE [stg].[Sales]
(
    [StagingRowId]   BIGINT          IDENTITY (1, 1) NOT NULL,
    [TransactionNo]  NVARCHAR (30)   NOT NULL,
    [LineNumber]         INT             NOT NULL,
    [SalesDate]      DATE            NOT NULL,
    [SKU]            NVARCHAR (40)   NOT NULL,
    [StoreCode]      NVARCHAR (20)   NOT NULL,
    [Quantity]       INT             NOT NULL,
    [UnitPrice]      DECIMAL (10, 2) NOT NULL,
    [DiscountAmount] DECIMAL (10, 2) NOT NULL,
    [SourceFile]     NVARCHAR (100)  NULL,
    [LoadId]         INT             NOT NULL,
    CONSTRAINT [PK_stg_Sales] PRIMARY KEY CLUSTERED ([StagingRowId] ASC)
);
GO

CREATE NONCLUSTERED INDEX [IX_stg_Sales_SalesDate]
    ON [stg].[Sales] ([SalesDate] ASC);
