-- Import Flat Files (CSV) using SQL Wizard

-- Review Null Values in Imported Tables
SELECT *
FROM SalesOrders
WHERE OrderID IS NULL

SELECT *
FROM SalesOrderLines
WHERE OrderID IS NULL


-- Remove Rows from SalesOrders and SalesOrderLines where OrderID is null
DELETE FROM SalesOrders
WHERE OrderID IS NULL

DELETE FROM SalesOrderLines
WHERE OrderID IS NULL

-- Rename selected columns
EXEC sp_rename 'dbo.SalesOrderLines.Product_Price','LinePriceEach'
EXEC sp_rename 'dbo.SalesOrderLines.TotalPrice','SaleAmount'
EXEC sp_rename 'dbo.dimProduct.Product_Name', 'ProductName'
EXEC sp_rename 'dbo.dimProduct.Product_Description', 'ProductDescription'

-- Rename tables to singluar naming convention
EXEC sp_rename 'dbo.DimSubcategories', 'DimSubcategory'
EXEC sp_rename 'dbo.DimCategories', 'DimCategory'
EXEC sp_rename 'dbo.DimProducts', 'DimProduct'



-- Drop Columns
ALTER TABLE dbo.SalesOrderLines DROP COLUMN Tax
ALTER TABLE dbo.SalesOrderLines DROP COLUMN DiscountEach

-- Change Data Type of columns 
ALTER TABLE SalesOrderLines
ALTER COLUMN Cost DECIMAL(8,2)

ALTER TABLE SalesOrderLines
ALTER COLUMN LinePriceEach DECIMAL(8,2)

ALTER TABLE SalesOrderLines
ALTER COLUMN SaleAmount DECIMAL(8,2)

ALTER TABLE DimProduct
ALTER COLUMN PriceEach DECIMAL(8,2)

ALTER TABLE DimProduct
ALTER COLUMN Cost DECIMAL(8,2)

/* Create Relationships using Table Designer (no code)
PK dimCategory.CategoryID, FK dimSubcategory.CategoryID 
PK dimSubcategory.SubcategoryID, FK dimProduct.SubcategoryID
PK dimProduct.ProductID, FK SalesOrderLines.ProductID
*/

-- Debug Error in creating SalesOrders, SalesOrderLines relationshp

-- Identify if there are OrderIDs in SalesOrderLines that are not in the SalesOrder table
SELECT OrderID
	FROM SalesOrderLines
	WHERE OrderID NOT IN (
		SELECT OrderID
		FROM SalesOrders)

-- Delete OrderID = 44 from SalesOrderLines table, as it does not have a record in SalesOrders
DELETE FROM SalesOrderLines
WHERE OrderID=44

-- Add Foreign Constraint using code
ALTER TABLE SalesOrderLines
	ADD CONSTRAINT FK_SalesOrders_SalesOrderLines
	FOREIGN KEY (OrderID) REFERENCES SalesOrders(OrderID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

-- Confirm Foreign key creation on SalesOrderLines table
SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME='SalesOrderLines'

-- Crate a new column that has the Order Date and Order Time combined
-- Add the new column
ALTER TABLE SalesOrders
ADD OrderDateTime DATETIME2

-- Update the new column with combined date and time
UPDATE SalesOrders
SET OrderDateTime = DATEADD(Second, DATEDIFF(SECOND,0,OrderTime), CAST(OrderDate AS datetime2))

-- Verify the Update
SELECT
	OrderID,
	OrderDate,
	OrderTime,
	OrderDateTime
FROM SalesOrders

-- Make updates to Subcategories
--Create a new subcategory for Hugo Coffee and update the Product
INSERT INTO DimSubcategory (SubcategoryID, Subcategory, CategoryID, CategorySubcategory)
VALUES (81,'Hugo Coffee',8,'Local Love:Hugo Coffee')

UPDATE DimProduct
SET SubcategoryID = 81
WHERE ProductID = 842
*
-- Create a new subcategory for Salsa del Diablo and update the product
INSERT INTO DimSubcategory (SubcategoryID, Subcategory, CategoryID, CategorySubcategory)
VALUES (82,'Salsa',8,'Local Love:Salsa')

UPDATE DimSubcategory
SET Subcategory = 'Salsa del Diablo'
WHERE SubcategoryID =82

UPDATE DimSubcategory
SET CategorySubCategory = 'Local Love: Salsa del Diablo'
WHERE SubcategoryID =82

UPDATE DimProduct
SET SubcategoryID = 82
WHERE ProductID IN (46, 719,720,727,928,978,1073,1107,1173)


-- Update the Category for selected products, classifying them as 'Local Love'
UPDATE DimSubcategory
SET CategoryID = 8
WHERE SubcategoryID IN (30,59)

UPDATE DimSubcategory
SET CategorySubcategory = 'Local Love:Kombucha'
WHERE SubcategoryID IN (30)

UPDATE DimSubcategory
SET CategorySubcategory = 'Local Love:Desserts'
WHERE SubcategoryID IN (59)

-- Create a new subcategory for Polka Bean and update product
INSERT INTO DimSubcategory (SubcategoryID, Subcategory, CategoryID, CategorySubcategory)
VALUES (83,'Polka Bean',8,'Local Love:Polka Bean')

UPDATE DimProduct
SET SubcategoryID = 83
WHERE ProductID IN (454,456,457,487,554,555,601,613,614,654,711)

-- Create new read only user for database using SQL Authentication
CREATE USER groceryuser WITH PASSWORD = '[omitted]'
ALTER ROLE db_datareader ADD MEMBER groceryuser

--Review for null values in SalesOrderLines to resolve
-- 'Null value is eliminated by an aggregate or other SET operation' when running queries
SELECT *
FROM SalesOrderLines
WHERE SaleAmount IS NULL

-- Delete lines from SalesOrderLines with null values in SaleAmount
DELETE FROM SalesOrderLines
WHERE SaleAmount IS NULL

