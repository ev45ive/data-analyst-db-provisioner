/*
    Landing zone for customer returns registered in stores and in the online
    returns portal.
*/
CREATE TABLE [src].[ReturnsRaw]
(
    [RawId]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [ReturnNo]      NVARCHAR (30)  NULL,
    [TransactionNo] NVARCHAR (30)  NULL,
    [ReturnDate]    NVARCHAR (20)  NULL,
    [SKU]           NVARCHAR (40)  NULL,
    [StoreCode]     NVARCHAR (20)  NULL,
    [Quantity]      NVARCHAR (20)  NULL,
    [ReturnAmount]  NVARCHAR (20)  NULL,
    [ReturnReason]  NVARCHAR (30)  NULL,
    [SourceFile]    NVARCHAR (100) NULL,
    [ExtractedAt]   DATETIME2 (3)  NOT NULL CONSTRAINT [DF_src_ReturnsRaw_ExtractedAt] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_src_ReturnsRaw] PRIMARY KEY CLUSTERED ([RawId] ASC)
);
