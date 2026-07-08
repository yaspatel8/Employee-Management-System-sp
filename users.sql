CREATE TABLE Users
(
	UserId INT IDENTITY(1,1) PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(MAX) NOT NULL,
    
	RoleId INT NOT NULL,

    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
    IsActive BIT NOT NULL DEFAULT 1 ,
	FOREIGN KEY(RoleId)
    REFERENCES Roles(RoleId)
)

GO
--ALTER TABLE Users ADD IsFistLogin BIT NOT NULL DEFAULT(1)

CREATE OR ALTER PROCEDURE SP_Register
(
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100),
    @PasswordHash NVARCHAR(MAX)
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @RoleId INT;
	DECLARE @UserId INT;
    
	IF EXISTS(SELECT Email FROM Users WHERE Email = LOWER(TRIM(@Email)))
		BEGIN
			SELECT -1 AS Code , 'Email already exists' AS [Message]
		    RETURN;
		END

		SELECT @RoleId = RoleId FROM Roles WHERE RoleName = LOWER(TRIM('employee'));

		INSERT INTO Users
		(
		    FullName,
		    Email,
		    PasswordHash,
		    RoleId,
			IsFistLogin
		)
		VALUES
		(
		   LOWER(@FullName),
		   LOWER(@Email),
		   @PasswordHash,
		   @RoleId,0
		)

		SET @UserId = SCOPE_IDENTITY();

		INSERT INTO Employee
		(
		    UserId
		)
		VALUES
		(
		    @UserId
		);

		SELECT 1 AS Code , 'User registered successfully' AS [Message]
END
GO

CREATE OR ALTER PROCEDURE SP_Login (
    @Email NVARCHAR(100)
)
AS
BEGIN

    SELECT
        U.UserId,
        U.FullName,
        U.Email,
        U.PasswordHash,
        U.RoleId,
        R.RoleName,
		U.IsFistLogin
    FROM Users U
    INNER JOIN Roles R
        ON U.RoleId = R.RoleId
    WHERE U.Email = LOWER(TRIM(@Email)) AND U.IsActive=1

	
END
GO