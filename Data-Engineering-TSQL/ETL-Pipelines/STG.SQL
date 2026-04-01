
-- =========================================
-- 1. Department Table (Parent)
-- =========================================
CREATE TABLE dbo.Department
(
    DepartmentID INT IDENTITY(1,1) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL,
    Budget DECIMAL(12,2) NOT NULL,

    CONSTRAINT CK_Department_Budget CHECK (Budget >= 0)
);


-- =========================================
-- 2. Employee Table (Child of Department)
-- =========================================
CREATE TABLE dbo.Employee
(
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Salary DECIMAL(10,2) NOT NULL,
    DepartmentID INT NULL,
    HireDate DATE NOT NULL,

    -- Foreign Key (SET NULL on delete)
    CONSTRAINT FK_Employee_Department
        FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Department(DepartmentID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    -- Check Constraints
    CONSTRAINT CK_Employee_Salary CHECK (Salary > 0),
    CONSTRAINT CK_Employee_HireDate CHECK (HireDate <= GETDATE())
) ;


-- =========================================
-- 3. Project Table (Child of BOTH Employee & Department)
-- =========================================
CREATE TABLE dbo.Project
(
    ProjectID INT IDENTITY(1,1) PRIMARY KEY,
    ProjectName NVARCHAR(100) NOT NULL,
    Budget DECIMAL(12,2) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    EmployeeID INT NOT NULL,
    DepartmentID INT NOT NULL,

    -- FK 1 (CASCADE delete)
    CONSTRAINT FK_Project_Employee
        FOREIGN KEY (EmployeeID)
        REFERENCES dbo.Employee(EmployeeID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- FK 2 (NO ACTION / Restrict)
    CONSTRAINT FK_Project_Department
        FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Department(DepartmentID)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,

    -- Check Constraints
    CONSTRAINT CK_Project_Budget CHECK (Budget >= 1000),
    CONSTRAINT CK_Project_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
);
