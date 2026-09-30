/*
    Product dimension at SKU grain.

    A SKU is one size/colour variant of a style, e.g. style W-JKT-001 sold as
    W-JKT-001-CZA-M. Reporting by "model" means grouping on [StyleCode];
    reporting by "product" usually means the SKU.

    [ListPrice] is the current catalogue price including VAT. [UnitCost] is the
    landed cost of one unit.
*/
CREATE TABLE [dbo].[DimProduct]
(
    [ProductKey]  INT             IDENTITY (1, 1) NOT NULL,
    [SKU]         NVARCHAR (40)   NOT NULL,
    [StyleCode]   NVARCHAR (20)   NOT NULL,
    [StyleName]   NVARCHAR (100)  NOT NULL,
    [Department]  NVARCHAR (20)   NOT NULL,
    [Category]    NVARCHAR (30)   NOT NULL,
    [Color]       NVARCHAR (20)   NOT NULL,
    [Size]        NVARCHAR (5)    NOT NULL,
    [ListPrice]   DECIMAL (10, 2) NOT NULL,
    [UnitCost]    DECIMAL (10, 2) NOT NULL,
    [IsActive]    BIT             NOT NULL CONSTRAINT [DF_DimProduct_IsActive] DEFAULT (1),
    CONSTRAINT [PK_DimProduct] PRIMARY KEY CLUSTERED ([ProductKey] ASC)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DimProduct_SKU]
    ON [dbo].[DimProduct] ([SKU] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_DimProduct_StyleCode]
    ON [dbo].[DimProduct] ([StyleCode] ASC)
    INCLUDE ([Category], [Department], [Size]);
