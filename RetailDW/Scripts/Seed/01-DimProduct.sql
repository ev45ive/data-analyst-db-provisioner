PRINT N'  seeding [dbo].[DimProduct]';

IF NOT EXISTS (SELECT 1 FROM [dbo].[DimProduct])
BEGIN
    DECLARE @Styles TABLE
    (
        [StyleCode]  NVARCHAR (20)   NOT NULL,
        [StyleName]  NVARCHAR (100)  NOT NULL,
        [Department] NVARCHAR (20)   NOT NULL,
        [Category]   NVARCHAR (30)   NOT NULL,
        [ListPrice]  DECIMAL (10, 2) NOT NULL,
        [UnitCost]   DECIMAL (10, 2) NOT NULL,
        [Color1]     NVARCHAR (20)   NOT NULL,
        [Code1]      NVARCHAR (3)    NOT NULL,
        [Color2]     NVARCHAR (20)   NOT NULL,
        [Code2]      NVARCHAR (3)    NOT NULL,
        [Sized]      BIT             NOT NULL
    );

    INSERT INTO @Styles VALUES
        (N'W-JKT-001', N'Kurtka pikowana damska', N'WOMEN',  N'Kurtki',    399.00, 148.00, N'Czarny',    N'CZA', N'Piaskowy',   N'PIA', 1),
        (N'W-JKT-002', N'Parka damska',           N'WOMEN',  N'Kurtki',    499.00, 189.00, N'Khaki',     N'KHA', N'Czarny',     N'CZA', 1),
        (N'W-DRS-001', N'Sukienka midi',          N'WOMEN',  N'Sukienki',  199.00,  62.00, N'Czarny',    N'CZA', N'Bordowy',    N'BOR', 1),
        (N'W-DRS-002', N'Sukienka koszulowa',     N'WOMEN',  N'Sukienki',  179.00,  55.00, N'Granatowy', N'GRA', N'Ecru',       N'ECR', 1),
        (N'W-KNT-001', N'Sweter oversize',        N'WOMEN',  N'Swetry',    159.00,  48.00, N'Szary',     N'SZA', N'Kremowy',    N'KRE', 1),
        (N'W-JNS-003', N'Jeansy skinny',          N'WOMEN',  N'Jeansy',    169.00,  52.00, N'Niebieski', N'NIE', N'Czarny',     N'CZA', 1),
        (N'W-TSH-001', N'T-shirt basic damski',   N'WOMEN',  N'T-shirty',   59.00,  14.00, N'Ecru',      N'ECR', N'Czarny',     N'CZA', 1),
        (N'M-JKT-001', N'Kurtka miejska',         N'MEN',    N'Kurtki',    429.00, 160.00, N'Czarny',    N'CZA', N'Granatowy',  N'GRA', 1),
        (N'M-KNT-001', N'Sweter z dzianiny',      N'MEN',    N'Swetry',    179.00,  54.00, N'Granatowy', N'GRA', N'Szary',      N'SZA', 1),
        (N'M-JNS-001', N'Jeansy regular',         N'MEN',    N'Jeansy',    189.00,  58.00, N'Niebieski', N'NIE', N'Grafitowy',  N'GRF', 1),
        (N'M-TSH-001', N'T-shirt basic',          N'MEN',    N'T-shirty',   59.00,  14.00, N'Ecru',      N'ECR', N'Czarny',     N'CZA', 1),
        (N'M-SHI-001', N'Koszula oxford',         N'MEN',    N'Koszule',   199.00,  60.00, N'Ecru',      N'ECR', N'Lazurowy',   N'LAZ', 1),
        (N'A-BAG-001', N'Torebka shopper',        N'WOMEN',  N'Akcesoria', 249.00,  78.00, N'Czarny',    N'CZA', N'Koniakowy',  N'KON', 0),
        (N'A-SCF-001', N'Szalik zimowy',          N'UNISEX', N'Akcesoria',  89.00,  26.00, N'Szary',     N'SZA', N'Bordowy',    N'BOR', 0);

    DECLARE @Sizes TABLE ([Size] NVARCHAR (5) NOT NULL, [Sized] BIT NOT NULL);
    INSERT INTO @Sizes VALUES (N'XS', 1), (N'S', 1), (N'M', 1), (N'L', 1), (N'XL', 1), (N'ONE', 0);

    INSERT INTO [dbo].[DimProduct]
        ([SKU], [StyleCode], [StyleName], [Department], [Category], [Color], [Size],
         [ListPrice], [UnitCost], [IsActive])
    SELECT  CONCAT(s.[StyleCode], N'-', c.[Code], N'-', z.[Size]),
            s.[StyleCode],
            s.[StyleName],
            s.[Department],
            s.[Category],
            c.[Color],
            z.[Size],
            s.[ListPrice],
            s.[UnitCost],
            1
    FROM    @Styles AS s
    CROSS APPLY (VALUES (s.[Color1], s.[Code1]), (s.[Color2], s.[Code2])) AS c ([Color], [Code])
    JOIN    @Sizes  AS z ON z.[Sized] = s.[Sized]
    ORDER BY s.[StyleCode], c.[Code], z.[Size];

    PRINT N'    ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' SKUs';
END
