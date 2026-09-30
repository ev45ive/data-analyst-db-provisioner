/*
Post-deployment script
----------------------
Runs AFTER the schema diff is applied.

  1. Seeds the dimensions.
  2. Prepares the landing zone ([src]).
  3. Runs the three load procedures so the warehouse is queryable.

Every step is guarded, so publishing an already-populated database is a no-op.
*/
PRINT N'[PostDeployment] start';
GO

:r .\Seed\00-DimDate.sql
GO

:r .\Seed\01-DimProduct.sql
GO

:r .\Seed\02-DimStore.sql
GO

:r .\Seed\10-GenerateSourceData.sql
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[FactSales])
BEGIN
    PRINT N'  running the load procedures';
    EXEC [etl].[LoadSales];
    EXEC [etl].[LoadInventory];
    EXEC [etl].[LoadReturns];
END
GO

PRINT N'[PostDeployment] end';
GO
