CREATE TABLE PasswordReset
(
    PasswordResetId INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    Token NVARCHAR(500) NOT NULL,
    ExpiryTime DATETIME2 NOT NULL,
    IsUsed BIT NOT NULL DEFAULT 0,
    CreatedOn DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UsedOn DATETIME2 NULL,

    CONSTRAINT FK_PasswordResetTokens_Users FOREIGN KEY(UserId) REFERENCES Users(UserId),
	
);

GO

CREATE NONCLUSTERED INDEX IX_PasswordResetTokens_Token
ON PasswordReset(Token);

GO

CREATE OR ALTER PROCEDURE SP_ForgotPassword 
(
    @Email NVARCHAR(100),
    @Token NVARCHAR(500)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserId INT;

    -- Check user exists
    SELECT @UserId = U.UserId
    FROM Users U INNER JOIN Employee E ON U.UserId=E.UserId
    WHERE U.Email = @Email
      AND E.IsDeleted = 0
      AND E.IsActive = 1 AND U.IsActive=1;

    IF @UserId IS NULL
    BEGIN
        SELECT
            -1 AS Code,
            'Email does not exist.' AS Message;

        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        -- Expire previous unused tokens
        UPDATE PasswordReset
        SET
            IsUsed = 1,
            UsedOn = GETUTCDATE()
        WHERE UserId = @UserId
          AND IsUsed = 0;

        -- Insert new token
        INSERT INTO PasswordReset
        (
            UserId,
            Token,
            ExpiryTime
        )
        VALUES
        (
            @UserId,
            @Token,
            DATEADD(MINUTE, 5, GETUTCDATE())
        );

        COMMIT TRAN;

        SELECT
            1 AS Code,
            'A reset password link has been sent in Your Gmail Account.' AS Message;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        SELECT
            -1 AS Code,
            ERROR_MESSAGE() AS Message;

    END CATCH
END;

GO


CREATE OR ALTER PROCEDURE SP_ResetPassword
(
    @Token NVARCHAR(500),
    @PasswordHash NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserId INT;

    SELECT @UserId = UserId
    FROM PasswordReset
    WHERE Token = @Token
      AND IsUsed = 0
      AND ExpiryTime > GETUTCDATE();

    IF @UserId IS NULL
    BEGIN
        SELECT
            -1 AS Code,
            'Invalid, expired or already Changed Reset Password.' AS Message;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        -- Update password
        UPDATE Users
        SET PasswordHash = @PasswordHash,IsFistLogin=0
        WHERE UserId = @UserId;

        -- Mark token as used
        UPDATE PasswordReset
        SET
            IsUsed = 1,
            UsedOn = GETUTCDATE()
        WHERE Token = @Token;

        COMMIT TRAN;

        SELECT
            1 AS Code,
            'Password reset successfully.' AS Message;
    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        SELECT
            -1 AS Code,
            ERROR_MESSAGE() AS Message;
    END CATCH
END;
GO