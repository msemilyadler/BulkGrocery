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


-- Create a new table to track wholesale vs retail customers

-- First create a new table with a list of unique customerIDs
SELECT DISTINCT CustomerID
INTO dimCustomers
FROM SalesOrders

-- Set Customer ID data type to not null
ALTER TABLE dimCustomers
ALTER COLUMN CustomerID NVARCHAR(50) NOT NULL

-- Set primary key of new table
ALTER TABLE dimCustomers
ADD CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)


-- Add a new column 'Customer Type'
ALTER TABLE dimCustomers
ADD CustomerType NVARCHAR(50) NULL

-- Add Foreign Constraint 
ALTER TABLE SalesOrders
	ADD CONSTRAINT FK_SalesOrders_dimCustomers
	FOREIGN KEY (CustomerID) REFERENCES dimCustomers(CustomerID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

-- Update the new column to Wholesale for customers identified as wholesale 
--    based on the CTE WholesaleCustomerUpdate

-- CTE to return a list of wholesale customers
WITH WholesaleCustomerEval AS (	
    SELECT 
        o.CustomerID
    FROM SalesOrderLines AS l
        JOIN SalesOrders AS o
        ON l.OrderID = o.OrderID
        JOIN DimProduct AS p 
        ON l.ProductID = p.ProductID
        JOIN DimSubcategory AS sc
        ON p.SubcategoryID = sc.SubcategoryID
        JOIN DimCategory AS c
        ON sc.CategoryID = c.CategoryID

    WHERE c.Category IN ('Whls_Grocery','Whls_Selling Supplies') --include customers that purchased whls products
        AND p.ProductID NOT IN (86) 			--exclude ProductID 86, as it is also sold retail
        AND o.CustomerID <> 'Unknown' 			-- Exclude anonymous customers
    GROUP BY o.CustomerID, l.ProductID,p.ProductName
    HAVING SUM(l.SaleAmount) > 75 			-- only include lines where a customer 
							--purchased over $75 of the designated products
)

-- Update the new dimCustomer table, assigning Wholesale to the CustomerIDs returned in the CTE above
UPDATE c
SET c.CustomerType = 'Wholesale'
FROM dimCustomers AS c
	JOIN WholesaleCustomerEval as we
	ON c.CustomerID = we.CustomerID
 
 -- Update remaining CustomerIDs to Retail
UPDATE c
SET c.CustomerType = 'Retail'
FROM dimCustomers AS c
WHERE c.CustomerType IS NULL

 SELECT *
 FROM dimCustomers
 ORDER BY CustomerType DESC

 -- Rename table
 EXEC sp_rename 'dbo.dimCustomers', 'DimCustomers'


 -- Address SalesOrderLines with Null ProductID
 -- Identify Null Lines
SELECT SUM (SaleAmount)
  FROM [dbo].[SalesOrderLines]
  WHERE ProductID IS NULL
  GROUP BY ProductID

-- Create a new product to capture sales without a product ID
INSERT INTO DimProduct (ProductID, ProductName, SubcategoryID, Active, SKU)
VALUES (2000,'No Product',26,1,'NONE')

-- Assign new product 2000 to Sales Order Lines without ProductID
UPDATE SalesOrderLines
SET ProductID = 2000
WHERE ProductID IS NULL

---- CREATE A NEW FIELD ON PRODUCT DIMENSION TABLE: PRICING TYPE
-- Create a new column on the product table to define Pricing Type (PerPound or Each)
ALTER TABLE DimProduct
Add PricingType VARCHAR(8)

-- Assign Default Value of PerPound
Update DimProduct
SET PricingType = 'PerPound'

--Assign certain categories as 'Each'
UPDATE DimProduct
SET PricingType = 'Each'
FROM DimProduct AS p
	JOIN DimSubcategory AS sc
	ON p.SubcategoryID = sc.SubcategoryID
	JOIN DimCategory AS c
	ON sc.CategoryID = c.CategoryID
WHERE Category IN('Accessories', 'Containers','Events','Gift Card','Grab & Go')


-- Update Pricing Type on specific products based on review
UPDATE DimProduct
SET PricingType = 'Each'
WHERE ProductID IN (6,8,10,15,20,23,25,29,31,32,34,43,46,50,53,59,74,116,126,129,160,195,
						449,454,458,459,460,471,482,489,501,536,537,538,575,576,577,578,579,580,627,630,639,649,664,666,667,670,695,696,
						710,722,728,752,764,768,780,781,783,786,790,836,838,845,848,849,881,884,886,888,889,890,891,899,902,917,922,930,947,954,
						967,1017,1024,1036,1041,1046,1049,1063,1065,1066,1067,1085,1102,1103,1108,1020,1021,1022,1023,1121,1124,1126,2000)
					OR ProductID BETWEEN 407 AND 446
					OR ProductID BETWEEN 475 AND 481 
					OR ProductID BETWEEN 655 AND 662
					OR ProductID BETWEEN 736 AND 743 

UPDATE DimProduct
SET PricingType = 'Each'
WHERE ProductName LIKE '%WHLS%'


-- Update Polka Bean Products to Pricing Type of 'each'
UPDATE DimProduct
Set PricingType = 'Each'
WHERE ProductName LIKE '%Polka%'

-- Review product pricing type by category
SELECT 
	p.ProductID,
    c.Category,
	sc.Subcategory,
	p.ProductName,
	p.PricingType,
    SUM(l.SaleAmount) AS TotalSales,
      SUM(l.PoundsSold) AS Pounds
        
FROM SalesOrderLines AS l
    JOIN DimProduct AS p
    ON l.ProductID = p.ProductID
    JOIN DimSubcategory AS sc
    ON p.SubcategoryID = sc.SubcategoryID
    JOIN DimCategory AS c
    ON sc.CategoryID = c.CategoryID

GROUP BY c.Category, sc.Subcategory,p.ProductName,p.PricingType,p.ProductID
ORDER BY c.Category

---- CREATE A NEW FIELD ON SALES ORDER LINES: POUNDS SOLD
-- Create a view to calculate pounds sold
DROP VIEW IF EXISTS PoundsSold;
CREATE VIEW PoundsSold AS
SELECT 
	l.SalesOrderLineID,
	l.SaleAmount,
	p.ProductID,
	p.PriceEach,
	round(l.SaleAmount/p.PriceEach,4) AS PoundsSold
FROM SalesOrderLines AS l
	JOIN DimProduct as p
	ON l.ProductID = p.ProductID
WHERE p.PricingType = 'PerPound'
GO
	

-- Add a column with Pounds Sold to the SalesOrderLines table
ALTER TABLE SalesOrderLines
ADD PoundsSold DECIMAL(10,4)

--Add the computed pounds sold to the SalesOrderLines table in the PoundsSold column for all PerPound product
UPDATE SalesOrderLines
SET PoundsSold = s.PoundsSold
FROM SalesOrderLines AS l
	JOIN DimProduct as p
	ON l.ProductID = p.ProductID
	JOIN PoundsSold as s
	ON l.SalesOrderLineID = s.SalesOrderLineID
WHERE p.PricingType = 'PerPound'

-- Add zero pounds sold for products with a type of each
UPDATE SalesOrderLines
SET PoundsSold = 0
FROM SalesOrderLines AS l
	JOIN DimProduct AS p
	ON l.ProductID = p.ProductID
WHERE p.PricingType = 'Each'


-- Review null values
SELECT *
FROM SalesOrderLines
WHERE PoundsSold IS NULL


---- Make updates to subcategories and categories for Wholesale products

-- review products with WHLS in name
SELECT
	p.ProductID,
	p.ProductName,
	p.PriceEach,
	p.SubcategoryID,
	sc.Subcategory,
	sc.CategoryID,
	c.Category
FROM DimProduct AS p
	JOIN DimSubcategory AS sc
	ON p.SubcategoryID = sc.SubcategoryID
	JOIN DimCategory As c
	ON sc.CategoryID = c.CategoryID
WHERE p.ProductName LIKE '%WHLS%'
ORDER BY SubcategoryID

-- Create New Subcategories
INSERT INTO DimSubcategory (SubcategoryID, Subcategory, CategoryID, CategorySubcategory)
VALUES
	(90,'Vinegars', 6, 'Whls_Grocery: Vinegars'),
	(91,'Baking', 6, 'Whls_Grocery: Baking'),
	(92,'Sweeteners', 6, 'Whls_Grocery: Sweeteners'),
	(93,'Flours', 6, 'Whls_Grocery: Flours'),
	(94,'Seeds and Grains', 6, 'Whls_Grocery: Seeds and Grains'),
	(95,'Condiments', 6, 'Whls_Grocery: Condiments'),
	(96,'Canned', 6, 'Whls_Grocery: Canned'),
	(97,'Salts', 6, 'Whls_Grocery: Salts'),
	(98,'Nuts', 6, 'Whls_Grocery: Nuts'),
	(99,'Nut Butters', 6, 'Whls_Grocery: Nut Butters'),
	(100,'Oils', 6, 'Whls_Grocery: Oils'),
	(101,'Herbs and Spices', 6, 'Whls_Grocery: Herbs and Spices'),
	(102,'Dairy', 6, 'Whls_Grocery: Dairy')

-- Update the Subcategory assigned to wholesale products
UPDATE DimProduct
SET SubcategoryID = 90
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 8
	
UPDATE DimProduct
SET SubcategoryID = 91
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 11

UPDATE DimProduct
SET SubcategoryID = 92
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 12

UPDATE DimProduct
SET SubcategoryID = 93
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 13

UPDATE DimProduct
SET SubcategoryID = 94
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 17

UPDATE DimProduct
SET SubcategoryID = 95
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 24

UPDATE DimProduct
SET SubcategoryID = 96
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 31

UPDATE DimProduct
SET SubcategoryID = 97
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 33

UPDATE DimProduct
SET SubcategoryID = 98
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 38

UPDATE DimProduct
SET SubcategoryID = 99
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 39

UPDATE DimProduct
SET SubcategoryID = 100
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 40

UPDATE DimProduct
SET SubcategoryID = 101
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 43

UPDATE DimProduct
SET SubcategoryID = 102
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 45

UPDATE DimProduct
SET SubcategoryID = 66
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 25

--- Reassign Vinegar
UPDATE DimProduct
SET SubcategoryID = 32
WHERE ProductID = 5

