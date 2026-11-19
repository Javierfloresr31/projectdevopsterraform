IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        Id int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        Name nvarchar(100) NOT NULL,
        Email nvarchar(255) NOT NULL
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'ana.ejemplo@example.com')
BEGIN
    INSERT INTO dbo.Users (Name, Email)
    VALUES (N'Ana Ejemplo', N'ana.ejemplo@example.com');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'bruno.ejemplo@example.com')
BEGIN
    INSERT INTO dbo.Users (Name, Email)
    VALUES (N'Bruno Ejemplo', N'bruno.ejemplo@example.com');
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'camila.ejemplo@example.com')
BEGIN
    INSERT INTO dbo.Users (Name, Email)
    VALUES (N'Camila Ejemplo', N'camila.ejemplo@example.com');
END;
GO

IF DATABASE_PRINCIPAL_ID(N'appreader') IS NULL
BEGIN
    CREATE USER [appreader] WITH PASSWORD = 'REPLACE_WITH_A_STRONG_PASSWORD';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members AS role_members
    INNER JOIN sys.database_principals AS roles
        ON roles.principal_id = role_members.role_principal_id
    INNER JOIN sys.database_principals AS members
        ON members.principal_id = role_members.member_principal_id
    WHERE roles.name = N'db_datareader'
      AND members.name = N'appreader'
)
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [appreader];
END;
