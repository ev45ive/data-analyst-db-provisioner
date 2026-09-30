/*
    Store dimension. Covers physical stores and the online shop, which is
    modelled as a store so that every sale has a selling location.

    [SalesAreaM2] is the current selling floor area and is NULL for the online
    shop. [RemodelDate] is the date of the last floor-area change; the area
    stored here is always the current one, not the one in force on a past
    trading day.
*/
CREATE TABLE [dbo].[DimStore]
(
    [StoreKey]    INT            IDENTITY (1, 1) NOT NULL,
    [StoreCode]   NVARCHAR (20)  NOT NULL,
    [StoreName]   NVARCHAR (100) NOT NULL,
    [City]        NVARCHAR (50)  NOT NULL,
    [Region]      NVARCHAR (50)  NOT NULL,
    [Channel]     NVARCHAR (10)  NOT NULL,
    [Format]      NVARCHAR (20)  NOT NULL,
    [SalesAreaM2] INT            NULL,
    [OpenedDate]  DATE           NOT NULL,
    [RemodelDate] DATE           NULL,
    CONSTRAINT [PK_DimStore] PRIMARY KEY CLUSTERED ([StoreKey] ASC),
    CONSTRAINT [CK_DimStore_Channel] CHECK ([Channel] IN (N'STORE', N'ONLINE'))
);
GO

CREATE UNIQUE NONCLUSTERED INDEX [UX_DimStore_StoreCode]
    ON [dbo].[DimStore] ([StoreCode] ASC);
