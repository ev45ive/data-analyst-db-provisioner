/*
    Audit trail: one row per run of an [etl].[Load*] procedure.
*/
CREATE TABLE [dbo].[LoadLog]
(
    [LoadId]       INT             IDENTITY (1, 1) NOT NULL,
    [PackageName]  NVARCHAR (100)  NOT NULL,
    [StartedAt]    DATETIME2 (3)   NOT NULL CONSTRAINT [DF_LoadLog_StartedAt] DEFAULT (SYSUTCDATETIME()),
    [FinishedAt]   DATETIME2 (3)   NULL,
    [Status]       NVARCHAR (20)   NOT NULL CONSTRAINT [DF_LoadLog_Status] DEFAULT (N'RUNNING'),
    [RowsRead]     INT             NULL,
    [RowsLoaded]   INT             NULL,
    [RowsRejected] INT             NULL,
    [ErrorMessage] NVARCHAR (4000) NULL,
    CONSTRAINT [PK_LoadLog] PRIMARY KEY CLUSTERED ([LoadId] ASC),
    CONSTRAINT [CK_LoadLog_Status] CHECK ([Status] IN (N'RUNNING', N'SUCCEEDED', N'FAILED'))
);
