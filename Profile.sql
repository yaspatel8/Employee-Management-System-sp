CREATE OR ALTER PROCEDURE SP_Profile_Get
(
	@UserId INT
)
AS
BEGIN
	SELECT E.UserId,E.EmployeeId,U.FullName,U.Email,E.PhoneNumber,E.Salary,D.DepartmentId,D.DepartmentName ,E.ProfileImage ,E.CreatedAt,E.UpdatedAt
	FROM Employee E RIGHT JOIN Users U ON E.UserId=U.UserId LEFT JOIN Department D ON D.DepartmentId=E.DepartmentId WHERE E.UserId=@UserId
END

GO

CREATE OR ALTER PROCEDURE SP_Profile_Update
(
	@EmployeeId INT,
    @FullName NVARCHAR(100),
    @PhoneNumber NVARCHAR(20)
)
AS
BEGIN
	DECLARE @UserId INT;

	SELECT @UserId = UserId
        FROM Employee
        WHERE EmployeeId = @EmployeeId;

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

        UPDATE Users
        SET
            FullName = LOWER(TRIM(@FullName))
        WHERE UserId = @UserId;

        UPDATE Employee
        SET
            PhoneNumber = @PhoneNumber,
            UpdatedAt = GETDATE()
        WHERE EmployeeId = @EmployeeId;

        IF(@@ROWCOUNT > 0)
			BEGIN
				SELECT 1 AS Code, 'Employee Updated successfully' AS Message;
			END
		ELSE 
			BEGIN
				SELECT 0 AS Code , 'Employee Updated Failed' AS [Message]
			END
END
GO