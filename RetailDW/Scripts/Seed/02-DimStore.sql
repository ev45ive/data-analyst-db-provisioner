PRINT N'  seeding [dbo].[DimStore]';

IF NOT EXISTS (SELECT 1 FROM [dbo].[DimStore])
BEGIN
    INSERT INTO [dbo].[DimStore]
        ([StoreCode], [StoreName], [City], [Region], [Channel], [Format],
         [SalesAreaM2], [OpenedDate], [RemodelDate])
    VALUES
        (N'S-WAW-01', N'Warszawa Arkadia',      N'Warszawa', N'Mazowieckie',   N'STORE',  N'Galeria',      420,  '2016-04-15', NULL),
        (N'S-WAW-02', N'Warszawa Mokotow',      N'Warszawa', N'Mazowieckie',   N'STORE',  N'Galeria',      260,  '2019-09-01', NULL),
        (N'S-KRK-01', N'Krakow Rynek',          N'Krakow',   N'Malopolskie',   N'STORE',  N'Ulica',        320,  '2017-11-20', '2026-04-01'),
        (N'S-POZ-01', N'Poznan Stary Browar',   N'Poznan',   N'Wielkopolskie', N'STORE',  N'Galeria',      300,  '2018-03-10', NULL),
        (N'S-GDA-01', N'Gdansk Forum',          N'Gdansk',   N'Pomorskie',     N'STORE',  N'Galeria',      240,  '2021-10-05', NULL),
        (N'S-ONL-01', N'Sklep internetowy',     N'-',        N'Online',        N'ONLINE', N'E-commerce',   NULL, '2015-01-01', NULL);

    PRINT N'    ' + CAST(@@ROWCOUNT AS NVARCHAR (10)) + N' stores';
END
