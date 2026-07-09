CREATE TABLE Department (
	DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
	DepartmentName NVARCHAR(100) NOT NULL UNIQUE,

	CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),

	IsDeleted BIT NOT NULL DEFAULT 0,
	IsActive BIT NOT NULL DEFAULT 1 ,
	UpdateAt DATETIME NULL,
	UpdatedBy INT NULL,
	CreatedBy INT NOT NULL
)

GO

--CREATE OR ALTER PROCEDURE SP_Department_Get
--@DepartmentId INT = NULL
--AS
--BEGIN
--    IF @DepartmentId IS NULL OR @DepartmentId = 0
--		BEGIN	
--			SELECT * FROM Department WHERE IsDeleted=0;
--		END
--    ELSE
--		BEGIN
--			SELECT * FROM Department WHERE DepartmentId=@DepartmentId AND IsDeleted=0;
--		END
--	END
--GO




CREATE OR ALTER PROCEDURE SP_Department_Save
(
    @DepartmentId INT = NULL,
    @DepartmentName NVARCHAR(100),
	@UpdatedBy INT = NULL, 
	@CreatedBy INT = NULL
)
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS(SELECT DepartmentName FROM Department WHERE DepartmentName=LOWER(TRIM(@DepartmentName)))
		BEGIN
			SELECT -1 AS Code , 'Department already exists' AS [Message]
			RETURN;
		END

    IF @DepartmentId IS NULL OR @DepartmentId = 0
		BEGIN	
			INSERT INTO Department ( DepartmentName,CreatedBy) VALUES ( LOWER(TRIM(@DepartmentName)),  @CreatedBy);
			IF(@@ROWCOUNT > 0)
				BEGIN
					SELECT 1 AS Code , CONCAT('Department Inserted successfully by User ID: ', @CreatedBy) AS [Message]
				ENd
			ELSE 
				BEGIN
					SELECT 0 AS Code , 'Department Insertion Failed' AS [Message]
				END
		END
    ELSE
		BEGIN
			UPDATE Department SET DepartmentName = LOWER(@DepartmentName), UpdateAt = GETDATE(),Updatedby=@UpdatedBy WHERE DepartmentId = @DepartmentId;
			IF(@@ROWCOUNT > 0)
				BEGIN
					SELECT 1 AS Code ,  CONCAT('Department Updated successfully by User ID: ', @UpdatedBy) AS [Message]
				
				ENd
			ELSE 
				BEGIN
					SELECT 0 AS Code , 'Department Updation Failed' AS [Message]
				ENd
		END
	END
GO

CREATE OR ALTER PROCEDURE SP_Department_Get
AS
BEGIN
	SELECT DepartmentId,DepartmentName FROM Department WHERE IsDeleted=0 AND IsActive=1
END
GO

CREATE OR ALTER PROCEDURE SP_Department_GetAll
(
    @SearchText NVARCHAR(100) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 3,
    @SortColumn NVARCHAR(50) = 'DepartmentId',
    @SortOrder NVARCHAR(4) = 'DESC'
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchText = NULLIF(TRIM(@SearchText), '');

    IF @PageNumber < 1
        SET @PageNumber = 1;

    IF @PageSize < 1
        SET @PageSize = 3;

    DECLARE @TotalRecords INT;

    SELECT @TotalRecords = COUNT(*)
    FROM Department
    WHERE IsDeleted = 0
      AND (
            @SearchText IS NULL
            OR LOWER(DepartmentName) LIKE '%' + LOWER(@SearchText) + '%'
            OR DepartmentId = TRY_CAST(@SearchText AS INT)
          );

    -- Validation
    IF @SortColumn NOT IN ('DepartmentId', 'DepartmentName', 'CreatedAt', 'UpdateAt', 'IsActive')
        SET @SortColumn = 'DepartmentId';

    IF UPPER(@SortOrder) NOT IN ('ASC', 'DESC')
        SET @SortOrder = 'DESC';

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    SELECT
        DepartmentId,
        DepartmentName,
        CreatedAt,
        UpdateAt,
        IsDeleted,
        IsActive,
        ' + CAST(@TotalRecords AS NVARCHAR(20)) + ' AS TotalRecords
    FROM Department
    WHERE IsDeleted = 0
      AND (
            @SearchText IS NULL
            OR LOWER(DepartmentName) LIKE ''%'' + LOWER(@SearchText) + ''%''
            OR DepartmentId = TRY_CAST(@SearchText AS INT)
          )
    ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortOrder + '
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY';

    EXEC sp_executesql
        @SQL,
        N'@SearchText NVARCHAR(100), @PageNumber INT, @PageSize INT',
        @SearchText,
        @PageNumber,
        @PageSize;
END
GO

CREATE OR ALTER PROCEDURE SP_Department_Delete
@DepartmentId INT
AS
BEGIN
	UPDATE Department SET IsDeleted=1 WHERE DepartmentId=@DepartmentId
	IF(@@ROWCOUNT > 0)
		BEGIN
			SELECT 1 AS Code , 'Department Deleted successfully' AS [Message]
		
		ENd
	ELSE 
		BEGIN
			SELECT 0 AS Code , 'Department Deleted Failed' AS [Message]
		ENd
END
GO

--CREATE OR ALTER PROCEDURE SP_Department_Get
--@DepartmentId INT
--AS
--BEGIN
--	SELECT * FROM Department WHERE DepartmentId=@DepartmentId
--END

--GO


--update department satus
CREATE OR ALTER PROCEDURE SP_Department_UpdateStatus
(
    @DepartmentId INT,
    @IsActive BIT,
    @UpdatedBy INT
)
AS
BEGIN
    UPDATE Department
    SET IsActive = @IsActive,
        UpdateAt = GETDATE(),
        UpdatedBy = @UpdatedBy
    WHERE DepartmentId = @DepartmentId;
    IF (@@ROWCOUNT > 0)
    BEGIN
        SELECT 1 AS Code, CONCAT('Department status updated successfully by User ID: ', @UpdatedBy) AS [Message];
    END
    ELSE 
    BEGIN
        SELECT 0 AS Code, 'Department status update failed' AS [Message];
    END
END

GO

--export department data
CREATE OR ALTER PROCEDURE SP_Department_Export
    @DepartmentIds dbo.IdListType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        DepartmentId,
        DepartmentName,
        CreatedAt,
        UpdateAt,
        CASE WHEN Department.IsActive = 1 THEN 'Yes' ELSE 'No' END AS IsActive,
        CASE WHEN Department.IsDeleted = 1 THEN 'Yes' ELSE 'No' END AS IsDeleted
    FROM Department WHERE NOT EXISTS (SELECT 1 FROM @DepartmentIds)
        OR DepartmentId IN (SELECT Id FROM @DepartmentIds)
    ORDER BY DepartmentId;
END

GO