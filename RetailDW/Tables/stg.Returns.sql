/*
    Typed, validated returns. Populated by [etl].[LoadReturns] from
    [src].[ReturnsRaw].
*/
CREATE TABLE [stg].[Returns]
(
    [StagingRowId]  BIGINT          IDENTITY (1, 1) NOT NULL,
    [ReturnNo]      NVARCHAR (30)   NOT NULL,
    [TransactionNo] NVARCHAR (30)   NOT NULL,
    [ReturnDate]    DATE            NOT NULL,
    [SKU]           NVARCHAR (40)   NOT NULL,
    [StoreCode]     NVARCHAR (20)   NOT NULL,
    [Quantity]      INT             NOT NULL,
    [ReturnAmount]  DECIMAL (10, 2) NOT NULL,
    [ReturnReason]  NVARCHAR (30)   NULL,
    [SourceFile]    NVARCHAR (100)  NULL,
    [LoadId]        INT             NOT NULL,
    CONSTRAINT [PK_stg_Returns] PRIMARY KEY CLUSTERED ([StagingRowId] ASC)
);
