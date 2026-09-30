/*
    Landing zone for the daily POS / e-commerce sales extract.

    Every column arrives as text exactly as the source system wrote it. Nothing
    is validated here - conversion and validation happen in [etl].[LoadSales].
*/
CREATE TABLE [src].[SalesRaw]
(
    [RawId]          BIGINT         IDENTITY (1, 1) NOT NULL,
    [TransactionNo]  NVARCHAR (30)  NULL,
    [LineNumber]         NVARCHAR (10)  NULL,
    [SalesDate]      NVARCHAR (20)  NULL,
    [SKU]            NVARCHAR (40)  NULL,
    [StoreCode]      NVARCHAR (20)  NULL,
    [Quantity]       NVARCHAR (20)  NULL,
    [UnitPrice]      NVARCHAR (20)  NULL,
    [DiscountAmount] NVARCHAR (20)  NULL,
    [SourceFile]     NVARCHAR (100) NULL,
    [ExtractedAt]    DATETIME2 (3)  NOT NULL CONSTRAINT [DF_src_SalesRaw_ExtractedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_src_SalesRaw] PRIMARY KEY CLUSTERED ([RawId] ASC)
);
GO

CREATE NONCLUSTERED INDEX [IX_src_SalesRaw_SourceFile]
    ON [src].[SalesRaw] ([SourceFile] ASC);
