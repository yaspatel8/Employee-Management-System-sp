CREATE TABLE Employee(
	EmployeeId INT IDENTITY(1,1) PRIMARY KEY,
	UserId INT NOT NULL,
	PhoneNumber NVARCHAR(20) NULL UNIQUE,
	Salary DECIMAL(18,2) NULL,
	DepartmentId INT NULL,
	--RoleId INT NOT NULL,

	CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),
	IsDeleted BIT NOT NULL DEFAULT 0,
	IsActive BIT NOT NULL DEFAULT 1 ,
	UpdatedAt DATETIME NULL,
	ProfileImage NVARCHAR(MAX) NULL,
	UpdatedBy INT NULL,
	CreatedBy INT NULL,
    PositionId INT NULL,
    ManagerId INT NULL,
	CONSTRAINT fk_user FOREIGN KEY(UserId) REFERENCES Users(UserId),
    CONSTRAINT FK_Employee_Position FOREIGN KEY(PositionId) REFERENCES Position(PositionId),
    CONSTRAINT FK_Employee_Manager FOREIGN KEY (ManagerId) REFERENCES Employee(EmployeeId)
)

GO

--ALTER TABLE Employee
--ADD ManagerId INT NULL;

--ALTER TABLE Employee
--ADD CONSTRAINT FK_Employee_Manager
--FOREIGN KEY (ManagerId)
--REFERENCES Employee(EmployeeId);

--CREATE OR ALTER PROCEDURE SP_Employee_Insert
--@EmployeeName NVARCHAR(200),@EmployeeEmail NVARCHAR(250),@PhoneNumber NVARCHAR(20),@Salary DECIMAL(18,2),@DepartmentId INT
--AS
--BEGIN
--	DECLARE @RoleId INT = 0;
--	SET @RoleId=(SELECT RoleId FROM Roles WHERE RoleName=LOWER('employee'))
	
--	INSERT INTO Employee(EmployeeName,EmployeeEmail,PhoneNumber,Salary,DepartmentId,RoleId) 
--	VALUES(LOWER(@EmployeeName),LOWER(@EmployeeEmail),@PhoneNumber,@Salary,@DepartmentId,@RoleId)
--END

--GO

--CREATE OR ALTER PROCEDURE SP_Employee_GetAll
--AS
--BEGIN
--	SELECT * FROM Employee WHERE IsDeleted=0
--END

--GO

CREATE OR ALTER PROCEDURE SP_Employee_Delete
@EmployeeId INT
AS
BEGIN
	UPDATE Employee SET IsDeleted=1 WHERE EmployeeId=@EmployeeId
	IF(@@ROWCOUNT > 0)
		BEGIN
			SELECT 1 AS Code , 'Employee Deleted successfully' AS [Message]
		
		ENd
	ELSE 
		BEGIN
			SELECT 0 AS Code , 'Employee Deleted Failed' AS [Message]
		ENd
END
GO

--CREATE OR ALTER PROCEDURE SP_Employee_Get
--@EmployeeId INT
--AS
--BEGIN
--	SELECT * FROM Employee WHERE EmployeeId=@EmployeeId
--END

--GO

--CREATE OR ALTER PROCEDURE SP_Employee_Update
--@EmployeeId INT,@EmployeeName NVARCHAR(200),@EmployeeEmail NVARCHAR(250),@PhoneNumber NVARCHAR(20),@Salary DECIMAL(18,2)
--AS
--BEGIN
--	UPDATE Employee SET EmployeeName=@EmployeeName,EmployeeEmail=@EmployeeEmail,PhoneNumber=@PhoneNumber,Salary=@Salary,UpdateAt=GETUTCDATE()
--	WHERE EmployeeId=@EmployeeId
--END

--GO

CREATE OR ALTER PROCEDURE SP_Employee_EmployeeWithDepartment
AS
BEGIN

    SELECT
        E.EmployeeId,
        U.FullName,
        U.Email,
        E.PhoneNumber,
        E.Salary,
        D.DepartmentName,
        U.IsActive,
        P.PositionName
    FROM Employee E
    RIGHT JOIN Users U
        ON E.UserId = U.UserId
    LEFT JOIN Department D
        ON E.DepartmentId = D.DepartmentId
    LEFT JOIN Position P
        ON E.PositionId = P.PositionId
    WHERE E.IsDeleted = 0;

END
GO

CREATE OR ALTER PROCEDURE SP_Employee_Save
(
    @EmployeeId INT = NULL,
    @FullName NVARCHAR(100),
    @Email NVARCHAR(100)=NULL,
    @PhoneNumber NVARCHAR(20),
    @Salary DECIMAL(18,2),
    @DepartmentId INT,
	@RoleId INT = NULL,
	@PasswordHash NVARCHAR(MAX),
	@ProfileImage NVARCHAR(MAX) = NULL,
	@OldFileName NVARCHAR(200) OUTPUT,
	@UpdatedBy INT = NULL,
	@CreatedBy INT = NULL,
    @PositionId INT = NULL,
    @ManagerId INT = NULL
  
)
AS
BEGIN

	DECLARE @UserId INT;
	IF ISNULL(@EmployeeId,0) = 0
	BEGIN
		--SELECT @RoleId = RoleId
		--FROM Roles
		--WHERE LOWER(RoleName) = 'employee';

		--ADD Employee	
		    IF EXISTS (
		        SELECT 1
		        FROM Users
		        WHERE Email = LOWER(TRIM(@Email))
		    )
		    BEGIN
		        SELECT -1 AS Code,
		               'Email already exists' AS Message;
		        RETURN;
		    END

		    IF EXISTS (
		        SELECT 1
		        FROM Employee
		        WHERE PhoneNumber = @PhoneNumber
		    )
		    BEGIN
		        SELECT -1 AS Code,
		               'Phone number already exists' AS Message;
		        RETURN;
		    END

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
		        LOWER(TRIM(@FullName)),
		        LOWER(TRIM(@Email)),
		        @PasswordHash,
		        @RoleId,1
		    );

		    SET @UserId = SCOPE_IDENTITY();

		    INSERT INTO Employee
		    (
		        UserId,
		        PhoneNumber,
		        Salary,
		        DepartmentId,
				ProfileImage,
				CreatedBy,
				PositionId,
                ManagerId
		    )
		    VALUES
		    (
		        @UserId,
		        @PhoneNumber,
		        @Salary,
		        @DepartmentId,
				@ProfileImage,
				@CreatedBy,
                @PositionId,
                @ManagerId
              
		    );

			IF(@@ROWCOUNT > 0)
				BEGIN
					SELECT 1 AS Code,  CONCAT('Employee added successfully by User ID: ', @CreatedBy) AS Message;
				END
			ELSE 
				BEGIN
					SELECT 0 AS Code , 'Employee added Failed' AS [Message]
				END
		    
		END

	--UPDATE

    ELSE

    BEGIN
		
		SELECT @UserId = UserId
        FROM Employee
        WHERE EmployeeId = @EmployeeId;

        IF EXISTS (
            SELECT 1
            FROM Users U
            WHERE U.Email = LOWER(TRIM(@Email))
              AND U.UserId <> @UserId
        )
        BEGIN
            SELECT -1 AS Code,
                   'Email already exists' AS Message;
            RETURN;
        END

        IF EXISTS (
            SELECT 1
            FROM Employee
            WHERE PhoneNumber = @PhoneNumber
              AND EmployeeId <> @EmployeeId
        )
        BEGIN
            SELECT -1 AS Code,
                   'Phone number already exists' AS Message;
            RETURN;
        END

		 -- 1. Get old file name
		SELECT @OldFileName = ProfileImage
		FROM Employee
		WHERE EmployeeId = @EmployeeId;

        UPDATE Users
        SET
            FullName = LOWER(TRIM(@FullName)),
            Email = LOWER(TRIM(@Email)),
			RoleId = @RoleId
        WHERE UserId = @UserId;

        UPDATE Employee
        SET
            PhoneNumber = @PhoneNumber,
            Salary = @Salary,
            DepartmentId = @DepartmentId,
			ProfileImage = ISNULL(@ProfileImage, ProfileImage),
            UpdatedAt = GETDATE(),
			UpdatedBy = @UpdatedBy,
            PositionId = @PositionId,
            ManagerId = @ManagerId

        WHERE EmployeeId = @EmployeeId;

        IF(@@ROWCOUNT > 0)
			BEGIN
				SELECT 1 AS Code, CONCAT('Employee Updated successfully by User ID: ', @UpdatedBy) AS Message;
			END
		ELSE 
			BEGIN
				SELECT 0 AS Code , 'Employee Updated Failed' AS [Message]
			END
    END
END
GO

CREATE OR ALTER PROCEDURE SP_Employee_GetAll
(
    @SearchText NVARCHAR(200) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 3,
    @SortColumn NVARCHAR(50) = 'EmployeeId',
    @SortOrder NVARCHAR(4) = 'DESC'
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @SearchText = NULLIF(LTRIM(RTRIM(@SearchText)), '');

    IF @PageNumber < 1
        SET @PageNumber = 1;

    IF @PageSize < 1
        SET @PageSize = 3;

    DECLARE @TotalRecords INT;

    SELECT @TotalRecords = COUNT(*)
    FROM Employee E
    INNER JOIN Users U
        ON E.UserId = U.UserId
    LEFT JOIN Department D
        ON E.DepartmentId = D.DepartmentId
    INNER JOIN Roles R
        ON U.RoleId = R.RoleId
    LEFT JOIN Position P 
        ON E.PositionId = P.PositionId
    WHERE E.IsDeleted = 0
      AND (
            @SearchText IS NULL
         OR LOWER(U.FullName) LIKE '%' + LOWER(@SearchText) + '%'
         OR LOWER(U.Email) LIKE '%' + LOWER(@SearchText) + '%'
         OR E.PhoneNumber LIKE '%' + @SearchText + '%'
         OR CAST(E.Salary AS NVARCHAR(50)) LIKE '%' + @SearchText + '%'
         OR LOWER(D.DepartmentName) LIKE '%' + LOWER(@SearchText) + '%'
         OR LOWER(R.RoleName) LIKE '%' + LOWER(@SearchText) + '%'
         OR LOWER(P.PositionName) LIKE '%' + LOWER(@SearchText) + '%'
         OR E.EmployeeId = TRY_CAST(@SearchText AS INT)
         OR E.DepartmentId = TRY_CAST(@SearchText AS INT)
      );

    -- Validate Sort Column
    IF @SortColumn NOT IN
    (
        'EmployeeId',
        'FullName',
        'Email',
        'PhoneNumber',
        'Salary',
        'DepartmentName',
        'RoleName',
        'CreatedAt',
        'IsActive'
    )
        SET @SortColumn = 'EmployeeId';

    -- Validate Sort Order
    IF UPPER(@SortOrder) NOT IN ('ASC', 'DESC')
        SET @SortOrder = 'DESC';

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    SELECT
        E.EmployeeId,
        U.UserId,
        U.FullName,
        U.Email,
        E.PhoneNumber,
        E.Salary,
        E.DepartmentId,
        D.DepartmentName,
        U.RoleId,
        R.RoleName,
        P.PositionId,
        P.PositionName,
        E.ProfileImage,
      
        U.IsActive,
        E.CreatedAt,
        ' + CAST(@TotalRecords AS NVARCHAR(20)) + ' AS TotalRecords
    FROM Employee E
    INNER JOIN Users U
        ON E.UserId = U.UserId
    LEFT JOIN Department D
        ON E.DepartmentId = D.DepartmentId
    INNER JOIN Roles R
        ON U.RoleId = R.RoleId
    LEFT JOIN Position P
        ON E.PositionId = P.PositionId
    
    WHERE E.IsDeleted = 0
      AND (
            @SearchText IS NULL
         OR LOWER(U.FullName) LIKE ''%'' + LOWER(@SearchText) + ''%''
         OR LOWER(U.Email) LIKE ''%'' + LOWER(@SearchText) + ''%''
         OR E.PhoneNumber LIKE ''%'' + @SearchText + ''%''
         OR CAST(E.Salary AS NVARCHAR(50)) LIKE ''%'' + @SearchText + ''%''
         OR LOWER(D.DepartmentName) LIKE ''%'' + LOWER(@SearchText) + ''%''
         OR LOWER(R.RoleName) LIKE ''%'' + LOWER(@SearchText) + ''%''
         OR LOWER(P.PositionName) LIKE ''%'' + LOWER(@SearchText) + ''%''
         OR E.EmployeeId = TRY_CAST(@SearchText AS INT)
         OR E.DepartmentId = TRY_CAST(@SearchText AS INT)
         OR E.PositionId = TRY_CAST(@SearchText AS INT)
     

      )
    ORDER BY ' + 
    CASE @SortColumn
        WHEN 'EmployeeId' THEN 'E.EmployeeId'
        WHEN 'FullName' THEN 'U.FullName'
        WHEN 'Email' THEN 'U.Email'
        WHEN 'PhoneNumber' THEN 'E.PhoneNumber'
        WHEN 'Salary' THEN 'E.Salary'
        WHEN 'DepartmentName' THEN 'D.DepartmentName'
        WHEN 'RoleName' THEN 'R.RoleName'
        WHEN 'PositionName' THEN 'P.PositionName'
        WHEN 'CreatedAt' THEN 'E.CreatedAt'
     
        WHEN 'IsActive' THEN 'U.IsActive'
    END + ' ' + @SortOrder + '
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY';

    EXEC sp_executesql
        @SQL,
        N'@SearchText NVARCHAR(200), @PageNumber INT, @PageSize INT',
        @SearchText,
        @PageNumber,
        @PageSize;
END
GO

CREATE TYPE dbo.EmployeeType AS TABLE
(
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    PasswordHash NVARCHAR(MAX) NOT NULL,
    Salary DECIMAL(18,2),
    DepartmentId INT
)

GO

CREATE OR ALTER PROCEDURE SP_BulkSaveEmployees
@Employees dbo.EmployeeType READONLY, @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RoleId AS INT;
    DECLARE @InsertedUsers TABLE (
        UserId   INT           ,
        Email    NVARCHAR (100),
        FullName NVARCHAR (100)); -- Check Duplicate Emails
    DECLARE @DuplicateEmails AS NVARCHAR (MAX);
    SELECT @DuplicateEmails = STRING_AGG(E.Email, ', ')
    FROM   @Employees AS E
           INNER JOIN
           Users AS U
           ON E.Email = U.Email; -- Employee Role
    SELECT @RoleId = RoleId
    FROM   Roles
    WHERE  LOWER(RoleName) = 'employee'; -- Insert Users
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO Users (FullName, Email, PasswordHash, RoleId)
        OUTPUT INSERTED.UserId, INSERTED.Email, INSERTED.FullName INTO @InsertedUsers (UserId, Email, FullName)
        SELECT E.FullName,
               E.Email,
               E.PasswordHash,
               @RoleId
        FROM   @Employees AS E
        WHERE  NOT EXISTS (SELECT 1
                           FROM   Users AS U
                           WHERE  U.Email = E.Email); -- Insert Employee
        INSERT INTO Employee (UserId, Salary, DepartmentId, CreatedBy)
        SELECT U.UserId,
               E.Salary,
               E.DepartmentId,
               @CreatedBy
        FROM   @InsertedUsers AS U
               INNER JOIN
               @Employees AS E
               ON U.Email = E.Email; -- Save
        DECLARE @TotalCount AS INT = (SELECT COUNT(*)
                                      FROM   @Employees);
        DECLARE @InsertedCount AS INT = (SELECT COUNT(*)
                                         FROM   @InsertedUsers);
        DECLARE @SkippedCount AS INT = @TotalCount - @InsertedCount;
        IF (@InsertedCount > 0)
            BEGIN
                SELECT 1 AS Code,
                       @InsertedCount AS InsertedCount,
                       @SkippedCount AS SkippedCount,
                       ISNULL(@DuplicateEmails, '') AS DuplicateEmails,
                       CONCAT(@InsertedCount, ' of ', @TotalCount, ' employees added successfully.', CASE WHEN @SkippedCount > 0 THEN ' Skipped ' + CAST (@SkippedCount AS NVARCHAR (10)) + ' duplicate employees: ' + @DuplicateEmails ELSE '' END) AS Message;
            END
        ELSE
            BEGIN
                SELECT -1 AS Code,
                       0 AS InsertedCount,
                       @TotalCount AS SkippedCount,
                       ISNULL(@DuplicateEmails, '') AS DuplicateEmails,
                       'No employees were added. All provided emails already exist.' AS Message;
            END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT -1 AS Code,
               ERROR_MESSAGE() AS Message;
    END CATCH
END

GO

CREATE TYPE dbo.EmployeeDeleteType AS TABLE
(
    EmployeeId INT NOT NULL
)

GO

--delete bulk employee
CREATE OR ALTER PROCEDURE SP_BulkDeleteEmployees
@EmployeeIds dbo.EmployeeDeleteType READONLY, @DeletedBy INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE E
        SET    E.IsDeleted = 1,
               E.IsActive = 0,
               E.UpdatedAt = GETDATE(),
               E.UpdatedBy = @DeletedBy
        FROM   Employee AS E
               INNER JOIN
               @EmployeeIds AS EI
               ON E.EmployeeId = EI.EmployeeId
        WHERE  E.IsDeleted = 0
               AND E.IsActive = 1;

        UPDATE U 
        SET    U.IsActive = 0
               FROM Users AS U
               INNER JOIN
               @EmployeeIds AS EI
               ON U.UserId = (SELECT E.UserId FROM Employee AS E WHERE E.EmployeeId = EI.EmployeeId)
               WHERE  U.IsActive = 1;

        IF @@ROWCOUNT > 0
            BEGIN
                SELECT 1 AS Code,
                       CONCAT('employees deleted successfully by User ID: ', @DeletedBy) AS Message;
            END
        ELSE
            BEGIN
                SELECT 0 AS Code,
                       'No employees were deleted.' AS Message;
            END
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT -1 AS Code,
               ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

--change isactive status of employee
CREATE OR ALTER PROCEDURE SP_ChangeEmployeeStatus
    @EmployeeId INT,
    @IsActive BIT,
    @UpdatedBy INT
AS
BEGIN
    UPDATE E
    SET    E.IsActive = @IsActive,
           E.UpdatedAt = GETDATE(),
           E.UpdatedBy = @UpdatedBy
    FROM   Employee AS E
    WHERE  E.EmployeeId = @EmployeeId

    
    UPDATE U 
    SET    U.IsActive = @IsActive
    FROM Users AS U 
    WHERE U.UserId = (SELECT E.UserId FROM Employee AS E WHERE E.EmployeeId = @EmployeeId);

     
    IF @@ROWCOUNT > 0
        BEGIN
            SELECT 1 AS Code,
                   CONCAT('Employee status changed successfully by User ID: ', @UpdatedBy) AS Message;
        END
    ELSE
        BEGIN
            SELECT 0 AS Code,
                   'No employee status was changed.' AS Message;
        END
END

GO

--Bulk update employee details
CREATE TYPE dbo.EmployeeUpdateType AS TABLE
(
    EmployeeId INT NOT NULL,
    FullName NVARCHAR(100) ,
    Email NVARCHAR(100) ,
    Salary DECIMAL(18,2),
    DepartmentId INT,
    IsActive BIT
)
GO

CREATE OR ALTER PROCEDURE SP_BulkUpdateEmployees
@Employees dbo.EmployeeUpdateType READONLY, @UpdatedBy INT
AS
BEGIN
    --CHECK FOR DUPLICATE EMAILS IN THE PROVIDED DATA
    DECLARE @DuplicateEmails AS NVARCHAR (MAX);
    SELECT @DuplicateEmails = STRING_AGG(E.Email, ', ')
    FROM   @Employees AS E
           INNER JOIN
           Users AS U
           ON E.Email = U.Email
    WHERE  E.EmployeeId <> (SELECT EmployeeId
                            FROM   Employee
                            WHERE  UserId = U.UserId);
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE E
        SET    E.Salary       = COALESCE (EU.Salary, E.Salary),
               E.DepartmentId = EU.DepartmentId,
               E.UpdatedAt    = GETDATE(),
               E.IsActive     = COALESCE (EU.IsActive, E.IsActive),
               E.UpdatedBy    = @UpdatedBy
        FROM   Employee AS E
               INNER JOIN
               @Employees AS EU
               ON E.EmployeeId = EU.EmployeeId;
        UPDATE U
        SET    U.FullName = COALESCE (EU.FullName, U.FullName),
               U.Email    = COALESCE (EU.Email, U.Email),
               U.IsActive = COALESCE (EU.IsActive, U.IsActive)
        FROM   Users AS U
               INNER JOIN
               @Employees AS EU
               ON U.UserId = (SELECT E.UserId
                              FROM   Employee AS E
                              WHERE  E.EmployeeId = EU.EmployeeId);
        DECLARE @TotalCount AS INT = (SELECT COUNT(*)
                                      FROM   @Employees);
        DECLARE @UpdatedCount AS INT = (SELECT COUNT(*)
                                       FROM   Employee AS E
                                              INNER JOIN
                                              @Employees AS EU
                                              ON E.EmployeeId = EU.EmployeeId);
        DECLARE @SkippedCount AS INT = @TotalCount - @UpdatedCount;

        IF (@UpdatedCount > 0)
            BEGIN
                SELECT 1 AS Code,
                       @UpdatedCount AS UpdatedCount,
                       @SkippedCount AS SkippedCount,
                       ISNULL(@DuplicateEmails, '') AS DuplicateEmails,
                       CONCAT(@UpdatedCount, ' of ', @TotalCount, ' employees updated successfully.', CASE WHEN @SkippedCount > 0 THEN ' Skipped ' + CAST (@SkippedCount AS NVARCHAR (10)) + ' duplicate emails: ' + @DuplicateEmails ELSE '' END) AS Message;
            END
        ELSE
            BEGIN
                SELECT -1 AS Code,
                       0 AS UpdatedCount,
                       @TotalCount AS SkippedCount,
                       ISNULL(@DuplicateEmails, '') AS DuplicateEmails,
                       'No employees were updated. All provided emails already exist.' AS Message;
            END;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        SELECT -1 AS Code,
               ERROR_MESSAGE() AS Message;
    END CATCH
END


GO

--export employee data to excel
CREATE TYPE dbo.IdListType AS TABLE
(
     Id INT NOT NULL PRIMARY KEY
);
GO

CREATE OR ALTER PROCEDURE SP_ExportEmployees
(
    @EmployeeIds dbo.IdListType READONLY
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        E.EmployeeId,
        U.FullName,
        U.Email,
        COALESCE(E.Salary, 0) AS Salary,
        COALESCE(E.PhoneNumber, 'Not Available') AS PhoneNumber,
        CoALESCE(D.DepartmentName, '-- Not Assigned --') AS DepartmentName,
        CoALESCE(P.PositionName, '-- Not Assigned --') AS PositionName,
        CASE WHEN E.IsActive = 1 THEN 'Yes' ELSE 'No' END AS IsActive,
        CASE WHEN E.IsDeleted = 1 THEN 'Yes' ELSE 'No' END AS IsDeleted,
        E.CreatedAt AS DateOfJoining,
        E.UpdatedAt
      
    FROM Employee E
    INNER JOIN Users U
        ON E.UserId = U.UserId
    LEFT JOIN Department D
        ON E.DepartmentId = D.DepartmentId
    LEFT JOIN Position P
        ON E.PositionId = P.PositionId
    WHERE
        NOT EXISTS (SELECT 1 FROM @EmployeeIds)
        OR E.EmployeeId IN (SELECT Id FROM @EmployeeIds)
    ORDER BY E.EmployeeId;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT 0 AS Code,
               'No employees found.' AS Message;
    END
    ELSE
    BEGIN
        SELECT 1 AS Code,
               'Employees exported successfully.' AS Message;
    END
END

GO

CREATE OR ALTER PROCEDURE SP_GetManagers 
(
      @DepartmentId INT,
      @PositionId INT
)
AS
BEGIN   

    SET NOCOUNT ON;

    DECLARE @Level INT;

    SELECT
        @Level = Level
    FROM Position
    WHERE PositionId = @PositionId;

    SELECT

        E.EmployeeId,

        U.FullName,

        P.PositionName,
       
        DP.DepartmentName,
         U.Email

    FROM Employee E

    INNER JOIN Users U ON E.UserId = U.UserId
        
    INNER JOIN Position P
        ON E.PositionId = P.PositionId

    LEFT JOIN Department DP
        ON E.DepartmentId = DP.DepartmentId

    INNER JOIN Roles R ON U.RoleId = R.RoleId

    WHERE

       E.IsActive = 1

        -- CEO (Admin) hamesha dropdown me aayega
        AND
        (
            R.RoleName = 'admin'

            OR

            E.DepartmentId = @DepartmentId
        )

        -- Sirf higher designation wale
        AND P.Level < @Level

    ORDER BY
        CASE
            WHEN R.RoleName = 'admin' THEN 0
            ELSE 1
        END,
        p.Level,
        u.FullName;

END
GO  
