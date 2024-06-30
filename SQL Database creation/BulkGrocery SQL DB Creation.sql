---- IMPORT TABLES, CREATE FOREIGN KEYS, SET DATA TYPES

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
EXEC sp_rename 'dbo.DimProductss.Product_Name', 'ProductName'
EXEC sp_rename 'dbo.DimProductss.Product_Description', 'ProductDescription'

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

ALTER TABLE DimProducts
ALTER COLUMN PriceEach DECIMAL(8,2)

ALTER TABLE DimProducts
ALTER COLUMN Cost DECIMAL(8,2)

--Create Foreign Keys

ALTER TABLE DimSubcategories
	ADD CONSTRAINT FK_DimCategories_DimSubcategories
	FOREIGN KEY (CategoryID) REFERENCES DimCategories(CategoryID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

ALTER TABLE DimProducts
	ADD CONSTRAINT FK_DimSubcategories_DimProducts
	FOREIGN KEY (SubcategoryID) REFERENCES DimSubcategories(SubcategoryID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

ALTER TABLE SalesOrderLines
	ADD CONSTRAINT FK_DimProducts_SalesOrderLines
	FOREIGN KEY (ProductID) REFERENCES DimProducts(ProductID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

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

-- Drop Columns
ALTER TABLE DimProducts
DROP COLUMN SKU

ALTER TABLE DimSubcategories
DROP COLUMN CategorySubcategory

ALTER TABLE SalesOrders
DROP COLUMN Payment_Type

ALTER TABLE SalesOrders
DROP COLUMN Station

---- MAKE REVISIONS TO SUBCATEGORIES AND PRODUCT ASSIGNMENTS

-- Make updates to Subcategories
--Create a new subcategory for Hugo Coffee and update the Product
INSERT INTO DimSubcategories (SubcategoryID, Subcategory, CategoryID)
VALUES (81,'Hugo Coffee',8)

UPDATE DimProducts
SET SubcategoryID = 81
WHERE ProductID = 842
*
-- Create a new subcategory for Salsa del Diablo and update the product
INSERT INTO DimSubcategories (SubcategoryID, Subcategory, CategoryID)
VALUES (82,'Salsa',8)

UPDATE DimSubcategories
SET Subcategory = 'Salsa del Diablo'
WHERE SubcategoryID =82

UPDATE DimProducts
SET SubcategoryID = 82
WHERE ProductID IN (46, 719,720,727,928,978,1073,1107,1173)

-- Update the Category for selected products, classifying them as 'Local Love'
UPDATE DimSubcategories
SET CategoryID = 8
WHERE SubcategoryID IN (30,59)

-- Create a new subcategory for Polka Bean and update product
INSERT INTO DimSubcategories (SubcategoryID, Subcategory, CategoryID)
VALUES (83,'Polka Bean',8)

UPDATE DimProducts
SET SubcategoryID = 83
WHERE ProductID IN (454,456,457,487,554,555,601,613,614,654,711)

---- ADDRESS NULL VALUES IN SALESORDERLINES

--Review for null values in SalesOrderLines to resolve
-- 'Null value is eliminated by an aggregate or other SET operation' when running queries
SELECT *
FROM SalesOrderLines
WHERE SaleAmount IS NULL

-- Delete lines from SalesOrderLines with null values in SaleAmount
DELETE FROM SalesOrderLines
WHERE SaleAmount IS NULL


---- CREATE A NEW TABLE TO TRACK WHOLESALE AND RETAIL CUSTOMERS

-- First create a new table with a list of unique customerIDs
SELECT DISTINCT CustomerID
INTO DimCustomers
FROM SalesOrders

DELETE FROM DimCustomers
WHERE CustomerID IS NULL

-- Set Customer ID data type to Nvarchar(5) and not null
ALTER TABLE DimCustomers
ALTER COLUMN CustomerID NVARCHAR(50) NOT NULL

-- Change datatype of SalesOrders CustomerID
ALTER TABLE SalesOrders
ALTER COLUMN CustomerID NVARCHAR(50)

-- Set primary key of new table
ALTER TABLE DimCustomers
ADD CONSTRAINT PK_Customers PRIMARY KEY (CustomerID)

-- Add a new column 'Customer Type'
ALTER TABLE DimCustomers
ADD CustomerType NVARCHAR(50) NULL

-- Add Foreign Constraint 
ALTER TABLE SalesOrders
	ADD CONSTRAINT FK_SalesOrders_dimCustomers
	FOREIGN KEY (CustomerID) REFERENCES DimCustomers(CustomerID)
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
        JOIN DimProducts AS p 
        ON l.ProductID = p.ProductID
        JOIN DimSubcategories AS sc
        ON p.SubcategoryID = sc.SubcategoryID
        JOIN DimCategories AS c
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
FROM DimCustomers AS c
	INNER JOIN WholesaleCustomerEval as we
	ON c.CustomerID = we.CustomerID
 
 -- Update remaining CustomerIDs to Retail
UPDATE c
SET c.CustomerType = 'Retail'
FROM DimCustomers AS c
WHERE c.CustomerType IS NULL

 SELECT *
 FROM DimCustomers
 ORDER BY CustomerType DESC

---- UPDATE NULL CUSTOMERID IN SALES ORDER TO IDENTIFY ANONYMOUS CUSTOMERS
INSERT INTO DimCustomers(CustomerID, CustomerType)
VALUES ('Unknown','Retail')

UPDATE SalesOrders
SET CustomerID = 'Unknown'
WHERE CustomerID IS NULL


---- ASSIGN A PRODUCTID OF 2000 TO SALESORDERLINES WITH NO PRODUCTID

 -- Address SalesOrderLines with Null ProductID
 -- Identify Null Lines
SELECT SUM (SaleAmount)
  FROM [dbo].[SalesOrderLines]
  WHERE ProductID IS NULL
  GROUP BY ProductID

-- Create a new product to capture sales without a product ID
INSERT INTO DimProducts (ProductID, ProductName, SubcategoryID, Active)
VALUES (2000,'No Product',26,1)

-- Assign new product 2000 to Sales Order Lines without ProductID
UPDATE SalesOrderLines
SET ProductID = 2000
WHERE ProductID IS NULL


---- DEFINE PRICING TYPE OF PERPOUND VS EACH AND CALCULATE POUNDS SOLD

---- CREATE A NEW FIELD ON PRODUCT DIMENSION TABLE: PRICING TYPE AND ASSIGN VALUES

-- Create a new column on the product table to define Pricing Type (PerPound or Each)
ALTER TABLE DimProducts
Add PricingType VARCHAR(8)

-- Assign Default Value of PerPound to all products
Update DimProducts
SET PricingType = 'PerPound'

--Assign certain categories as 'Each'
UPDATE DimProducts
SET PricingType = 'Each'
FROM DimProducts AS p
	JOIN DimSubcategories AS sc
	ON p.SubcategoryID = sc.SubcategoryID
	JOIN DimCategories AS c
	ON sc.CategoryID = c.CategoryID
WHERE Category IN('Accessories', 'Containers','Events','Gift Card','Grab & Go')


-- Update Pricing Type on specific products based on review and subject matter expertise
UPDATE DimProducts
SET PricingType = 'Each'
WHERE ProductID IN (6,8,10,15,20,23,25,29,31,32,34,43,46,50,53,59,74,116,126,129,160,195,
						449,454,458,459,460,471,482,489,501,536,537,538,575,576,577,578,579,580,627,630,639,649,664,666,667,670,695,696,
						710,722,728,752,764,768,780,781,783,786,790,836,838,845,848,849,881,884,886,888,889,890,891,899,902,917,922,930,947,954,
						967,1017,1024,1036,1041,1046,1049,1063,1065,1066,1067,1085,1102,1103,1108,1020,1021,1022,1023,1121,1124,1126,2000)
					OR ProductID BETWEEN 407 AND 446
					OR ProductID BETWEEN 475 AND 481 
					OR ProductID BETWEEN 655 AND 662
					OR ProductID BETWEEN 736 AND 743 

-- Update Products with 'WHLS' in the name to 'Each'
UPDATE DimProducts
SET PricingType = 'Each'
WHERE ProductName LIKE '%WHLS%'

-- Update Polka Bean Products to Pricing Type of 'each'
UPDATE DimProducts
Set PricingType = 'Each'
WHERE ProductName LIKE '%Polka%'


---- CREATE A NEW FIELD ON SALES ORDER LINES: POUNDS SOLD

-- Create a view to calculate pounds sold
DROP VIEW IF EXISTS PoundsSold

CREATE VIEW PoundsSold AS
SELECT 
	l.SalesOrderLineID,
	l.SaleAmount,
	p.ProductID,
	p.PriceEach,
	round(l.SaleAmount/p.PriceEach,4) AS PoundsSold
FROM SalesOrderLines AS l
	JOIN DimProducts as p
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
	JOIN DimProducts as p
	ON l.ProductID = p.ProductID
	JOIN PoundsSold as s
	ON l.SalesOrderLineID = s.SalesOrderLineID
WHERE p.PricingType = 'PerPound'

-- Add zero pounds sold for products with a type of each
UPDATE SalesOrderLines
SET PoundsSold = 0
FROM SalesOrderLines AS l
	JOIN DimProducts AS p
	ON l.ProductID = p.ProductID
WHERE p.PricingType = 'Each'


-- Review null values
SELECT *
FROM SalesOrderLines
WHERE PoundsSold IS NULL


---- UPDATE THE SUBCATEGORY FOR WHOLESALE PRODUCTS

-- review products with WHLS in name
SELECT
	p.ProductID,
	p.ProductName,
	p.PriceEach,
	p.SubcategoryID,
	sc.Subcategory,
	sc.CategoryID,
	c.Category
FROM DimProducts AS p
	JOIN DimSubcategories AS sc
	ON p.SubcategoryID = sc.SubcategoryID
	JOIN DimCategories As c
	ON sc.CategoryID = c.CategoryID
WHERE p.ProductName LIKE '%WHLS%'
ORDER BY SubcategoryID

-- Create New Subcategories
INSERT INTO DimSubcategories (SubcategoryID, Subcategory, CategoryID)
VALUES
	(90,'Vinegars', 6),
	(91,'Baking', 6),
	(92,'Sweeteners', 6),
	(93,'Flours', 6),
	(94,'Seeds and Grains', 6),
	(95,'Condiments', 6),
	(96,'Canned', 6),
	(97,'Salts', 6),
	(98,'Nuts', 6),
	(99,'Nut Butters', 6),
	(100,'Oils', 6),
	(101,'Herbs and Spices', 6),
	(102,'Dairy', 6)

-- Update the Subcategory assigned to wholesale products
UPDATE DimProducts
SET SubcategoryID = 90
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 8
	
UPDATE DimProducts
SET SubcategoryID = 91
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 11

UPDATE DimProducts
SET SubcategoryID = 92
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 12

UPDATE DimProducts
SET SubcategoryID = 93
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 13

UPDATE DimProducts
SET SubcategoryID = 94
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 17

UPDATE DimProducts
SET SubcategoryID = 95
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 24

UPDATE DimProducts
SET SubcategoryID = 96
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 31

UPDATE DimProducts
SET SubcategoryID = 97
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 33

UPDATE DimProducts
SET SubcategoryID = 98
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 38

UPDATE DimProducts
SET SubcategoryID = 99
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 39

UPDATE DimProducts
SET SubcategoryID = 100
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 40

UPDATE DimProducts
SET SubcategoryID = 101
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 43

UPDATE DimProducts
SET SubcategoryID = 102
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 45

UPDATE DimProducts
SET SubcategoryID = 66
WHERE ProductName LIKE '%WHLS%'
	AND SubcategoryID = 25

--- Reassign Vinegar
UPDATE DimProducts
SET SubcategoryID = 32
WHERE ProductID = 5



---- CREATE A TABLE FOR STORE LOCATION AND ASSIGN ORDERS TO A LOCATION
-- Create the table
CREATE TABLE DimLocation (
	LocationID tinyint NOT NULL,
	LocationName varchar(50),
	Sqft int
	PRIMARY KEY (LocationID)
	)

-- Add values to table for each store location
INSERT INTO DimLocation (LocationID, LocationName, Sqft)
VALUES	(1,'355N 500W',800),
		(2, '1085S 300W',1200)

-- Add a column to the SalesOrders table
ALTER TABLE SalesOrders
ADD LocationID tinyint


-- Add Foreign Key constraint to SalesOrder Table
ALTER TABLE SalesOrders
	ADD CONSTRAINT FK_DimLocation_SalesOrders
	FOREIGN KEY (LocationID) REFERENCES DimLocation(LocationID)
	ON DELETE CASCADE
	ON UPDATE CASCADE

-- Set Location to 1 for orders through 2021-09-19, and to Location 2 for orders after that date
UPDATE SalesOrders
SET LocationID = 1
WHERE OrderDate <= '2021-09-19'

UPDATE SalesOrders
SET LocationID = 2
WHERE OrderDate > '2021-09-19'


