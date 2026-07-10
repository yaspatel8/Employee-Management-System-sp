CREATE TABLE Position
(
    PositionId INT IDENTITY(1,1) PRIMARY KEY,

    PositionName NVARCHAR(100) NOT NULL,

    [Level] INT NOT NULL,

    IsActive BIT NOT NULL DEFAULT(1),

    IsDeleted BIT NOT NULL DEFAULT(0),

    CreatedBy INT NOT NULL,

    CreatedAt DATETIME NOT NULL DEFAULT(GETDATE()),

    UpdatedBy INT NULL,

    UpdatedAt DATETIME NULL
)

GO
--ADD / UPDATE Position sp
CREATE OR ALTER PROCEDURE SP_AddOrUpdatePosition
(
    @PositionId INT = NULL,
    @PositionName NVARCHAR(100),
    @Level INT,
    @CreatedBy INT = NULL,
    @UpdatedBy INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------
    -- INSERT
    -----------------------
    IF ISNULL(@PositionId,0) = 0
    BEGIN

        IF EXISTS
        (
            SELECT 1
            FROM Position
            WHERE LOWER(TRIM(PositionName)) = LOWER(TRIM(@PositionName))
              AND IsDeleted = 0
        )
        BEGIN
            SELECT -1 AS Code,
                   'Position Name already exists.' AS Message;
            RETURN;
        END

        IF EXISTS
        (
            SELECT 1
            FROM Position
            WHERE [Level] = @Level
              AND IsDeleted = 0
        )
        BEGIN
            SELECT -1 AS Code,
                   'Position Level already exists.' AS Message;
            RETURN;
        END

        INSERT INTO Position
        (
            PositionName,
            [Level],
            CreatedBy,
            CreatedAt
        )
        VALUES
        (
            LOWER(TRIM(@PositionName)),
            @Level,
            @CreatedBy,
            GETDATE()
        );

        SELECT 1 AS Code,
               'Position added successfully.' AS Message;

        RETURN;
    END


    -----------------------
    -- UPDATE
    -----------------------

    -- Check duplicate name except current record
    IF EXISTS
    (
        SELECT 1
        FROM Position
        WHERE LOWER(TRIM(PositionName)) = LOWER(TRIM(@PositionName))
          AND PositionId <> @PositionId
          AND IsDeleted = 0
    )
    BEGIN
        SELECT -1 AS Code,
               'Position Name already exists.' AS Message;
        RETURN;
    END

    -- Check duplicate level except current record
    IF EXISTS
    (
        SELECT 1
        FROM Position
        WHERE [Level] = @Level
          AND PositionId <> @PositionId
          AND IsDeleted = 0
    )
    BEGIN
        SELECT -1 AS Code,
               'Position Level already exists.' AS Message;
        RETURN;
    END

    UPDATE Position
    SET PositionName = LOWER(TRIM(@PositionName)),
        [Level] = @Level,
        UpdatedBy = @UpdatedBy,
        UpdatedAt = GETDATE()
    WHERE PositionId = @PositionId;

    IF @@ROWCOUNT > 0
    BEGIN
        SELECT 1 AS Code,
               'Position updated successfully.' AS Message;
    END
    ELSE
    BEGIN
        SELECT 0 AS Code,
               'Failed to update Position.' AS Message;
    END
END
GO

--Get Position all with active
CREATE OR ALTER PROCEDURE SP_GetAllPosition
(
    @Search NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Level',
    @SortOrder NVARCHAR(4) = 'ASC', 
    @PageNumber INT = 1,
    @PageSize INT = 3
)
AS
BEGIN
      SET NOCOUNT ON;   

    SET @Search = NULLIF(LTRIM(RTRIM(@Search)), '');

    IF @PageNumber < 1
        SET @PageNumber = 1;

    IF @PageSize < 1
        SET @PageSize = 3;

    DECLARE @TotalRecords INT;

    SELECT @TotalRecords = COUNT(*)
    FROM Position WHERE IsDeleted = 0
      AND (
            @Search IS NULL
         OR LOWER(PositionName) LIKE '%' + LOWER(@Search) + '%'
         OR CAST([Level] AS NVARCHAR(50)) LIKE '%' + @Search + '%'
         OR PositionId = TRY_CAST(@Search AS INT)
      );

    -- Validate Sort Column
    IF @SortColumn NOT IN
    (
        'PositionId',
        'PositionName',
        'Level'
    )
        SET @SortColumn = 'Level';

     IF UPPER(@SortOrder) NOT IN ('ASC', 'DESC')
        SET @SortOrder = 'DESC';

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    SELECT
        PositionId,
        PositionName,
        [Level],
        CreatedBy,
        CreatedAt,
        IsActive,
        UpdatedBy,
        ' + CAST(@TotalRecords AS NVARCHAR(20)) + ' AS TotalRecords
    FROM Position
    WHERE IsDeleted = 0
      AND (
            @Search IS NULL
         OR LOWER(PositionName) LIKE ''%'' + LOWER(@Search) + ''%''
         OR CAST([Level] AS NVARCHAR(50)) LIKE ''%'' + @Search + ''%''
         OR PositionId = TRY_CAST(@Search AS INT)
      )
    ORDER BY ' +  QUOTENAME(@SortColumn) + ' ' + @SortOrder + '
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY';


    EXEC sp_executesql
        @SQL,
        N'@Search NVARCHAR(200), @PageNumber INT, @PageSize INT',
        @Search,
        @PageNumber,
        @PageSize;
END

GO

--DELETE Position sp
CREATE OR ALTER PROCEDURE SP_DeletePosition
(
    @PositionId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS
        (
            SELECT 1
            FROM Employee
            WHERE PositionId = @PositionId
              AND IsDeleted = 0
              AND IsActive = 1
        )
        BEGIN
            ROLLBACK TRANSACTION;

            SELECT -1 AS Code,
                   'This position is assigned to employees and cannot be deleted.' AS Message;
            RETURN;
        END

        UPDATE Position
        SET IsDeleted = 1
        WHERE PositionId = @PositionId
          AND IsDeleted = 0;

        IF @@ROWCOUNT > 0
        BEGIN
            COMMIT TRANSACTION;

            SELECT 1 AS Code,
                   'Position deleted successfully.' AS Message;
        END
        ELSE
        BEGIN
            ROLLBACK TRANSACTION;

            SELECT 0 AS Code,
                   'Position not found.' AS Message;
        END
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        SELECT -99 AS Code,
               ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

--get position all active only
CREATE OR ALTER PROCEDURE SP_GetAllActivePosition
AS
bEGIN
    SET NOCOUNT ON;
    SELECT PositionId, PositionName, [Level]
    FROM Position
    WHERE IsActive = 1 AND IsDeleted = 0
    ORDER BY [Level] ASC;
END

GO

--update position status
CREATE OR ALTER PROCEDURE SP_Position_UpdateStatus
(
    @PositionId INT,
    @IsActive BIT,
    @UpdatedBy INT
)
AS
BEGIN
    UPDATE Position
    SET IsActive = @IsActive,
        UpdatedAt = GETDATE(),
        UpdatedBy = @UpdatedBy
    WHERE PositionId = @PositionId;
    IF (@@ROWCOUNT > 0)
    BEGIN
        SELECT 1 AS Code, CONCAT('Position status updated successfully by User ID: ', @UpdatedBy) AS [Message];
    END
    ELSE 
    BEGIN
        SELECT 0 AS Code, 'Position status update failed' AS [Message];
    END
END

GO