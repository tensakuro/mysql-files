show databases;

create database chain;

use chain;

-- structure of table

desc supply;

select * from supply_chain_inventory_dirty;

-- renaming table supply_chain_inventory_dirty

rename table supply_chain_inventory_dirty to supply;

-- view table

select * from supply; 

-- count records

select count(*) as no_of_rows from supply;

-- find duplicate product id values


select * from 
( select *,count(*) over (partition by product_id ) as cnt
from supply 
) t 
where cnt > 1;


select product_id ,count(*)
from supply
group by product_id 
having count(*) > 1;

select database();

-- counting number of nulls in each column

select sum(product_id is null or trim(product_id)='')  as null_product_id,
sum(product_name is null or trim(product_name)='')  as null_product_name,
sum(category is null or trim(category)='')  as null_category,
sum(supplier_name is null or trim(supplier_name)='')  as null_supplier_name,
sum(supplier_contact is null or trim(supplier_contact)='')  as null_supplier_contact,
sum(warehouse_location is null or trim(warehouse_location)='')  as null_warehouse_location,
sum(quantity_in_stock is null or trim(quantity_in_stock)='')  as null_quantity_in_stock,
sum(reorder_level is null or trim(reorder_level)='')  as null_reorder_level,
sum(unit_price is null or trim(unit_price)='')  as null_unit_price,
sum(last_restocked_date is null or trim(last_restocked_date)='')  as null_last_restocked_date,
sum(expiry_date is null or trim(expiry_date)='')  as null_expiry_date,
sum(batch_number is null or trim(batch_number)='')  as null_batch_number,
sum(status is null or trim(status)='')  as null_status

from supply;


-- identify text in  numerical columns

SELECT product_id, product_name, quantity_in_stock, unit_price, reorder_level
FROM supply
WHERE 
    quantity_in_stock NOT REGEXP '^[0-9]+$'
OR
    unit_price NOT REGEXP '^[0-9]+$'
OR
    reorder_level NOT REGEXP '^[0-9]+$';

-- find negative numerical columns

SELECT product_id, quantity_in_stock, reorder_level, unit_price
FROM supply
WHERE 
    TRIM(quantity_in_stock) LIKE '-%'
OR  TRIM(reorder_level) LIKE '-%'
OR  TRIM(unit_price) LIKE '-%';

-- show all distinct status values

select distinct status,count(*) as cnt
from supply
group by status 
order by cnt desc;

-- show all distinct category values

select distinct category,count(*) as cnt
from supply
group by category 
order by cnt desc;

-- Show all distinct WAREHOUSE values 
select distinct warehouse_location,count(*) as cnt
from supply
group by warehouse_location
order by cnt desc;

-- Find invalid supplier contacts

SELECT product_id, supplier_name, supplier_contact
FROM supply
WHERE 
    supplier_contact IS NULL
    OR TRIM(supplier_contact) = ''
    OR NOT TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$';

--  Find expiry date BEFORE restock date

-- Find expiry date BEFORE restock date
SELECT product_id, product_name, last_restocked_date, expiry_date
FROM supply
WHERE 
    DATE_FORMAT(
        CASE
            WHEN expiry_date LIKE '____-__-__' 
                THEN STR_TO_DATE(expiry_date, '%Y-%m-%d')
            WHEN expiry_date LIKE '__-___-__' 
                THEN STR_TO_DATE(expiry_date, '%d-%b-%y')
            WHEN expiry_date LIKE '__/__/____' 
                THEN STR_TO_DATE(expiry_date, '%d/%m/%Y')
        END,
        '%Y-%m-%d'
    )
    <
    DATE_FORMAT(
        CASE
            WHEN last_restocked_date LIKE '____-__-__' 
                THEN STR_TO_DATE(last_restocked_date, '%Y-%m-%d')
            WHEN last_restocked_date LIKE '__-___-__' 
                THEN STR_TO_DATE(last_restocked_date, '%d-%b-%y')
            WHEN last_restocked_date LIKE '__/__/____' 
                THEN STR_TO_DATE(last_restocked_date, '%d/%m/%Y')
        END,
        '%Y-%m-%d'
    );


-- Find zero-stock products marked as Active

SELECT product_id, product_name, quantity_in_stock, status
FROM supply
WHERE TRIM(quantity_in_stock) = '0'
AND LOWER(TRIM(status)) = 'active';


-- --------------

-- data cleaning

-- Remove Fully Invalid / Dummy Rows

DELETE FROM supply
WHERE 
    LOWER(TRIM(product_name)) IN ('testproduct','dummy item','???','na','unknown');

-- replace null / empty

desc supply;

UPDATE supply
SET
    product_name = CASE WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 'Unknown Product' ELSE product_name END,
    category = CASE WHEN category IS NULL OR TRIM(category) = '' THEN 'Unknown' ELSE category END,
    supplier_name = CASE WHEN supplier_name IS NULL OR TRIM(supplier_name) = '' THEN 'Unknown Supplier' ELSE supplier_name END,
    warehouse_location = CASE WHEN warehouse_location IS NULL OR TRIM(warehouse_location) = '' THEN 'Warehouse A' ELSE warehouse_location END,
    batch_number = CASE WHEN batch_number IS NULL OR TRIM(batch_number) = '' THEN 'Not Available' ELSE batch_number END,
    status = CASE WHEN status IS NULL OR TRIM(status) = '' THEN 'Active' ELSE status END;


select * from supply;

-- Remove Duplicate product_id Records

ALTER TABLE supply 
ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;

DELETE t1
FROM supply t1
JOIN supply t2
ON t1.product_id = t2.product_id
AND t1.row_id > t2.row_id;


select * from supply;

-- Remove Rows with Text in Numeric Columns

DELETE FROM supply
WHERE 
    TRIM(quantity_in_stock) NOT REGEXP '^-?[0-9]+$'
OR  TRIM(unit_price) NOT REGEXP '^-?[0-9]+$'
OR  TRIM(reorder_level) NOT REGEXP '^-?[0-9]+$';


-- Remove Rows with Negative Values

DELETE FROM supply
WHERE 
    TRIM(quantity_in_stock) LIKE '-%'
OR  TRIM(reorder_level) LIKE '-%'
OR  TRIM(unit_price) LIKE '-%';

select count(*) from supply;

-- Fix Zero-Stock Products Marked as Active

UPDATE supply
SET status = 'Inactive'
WHERE TRIM(quantity_in_stock) = '0'
AND LOWER(TRIM(status)) = 'active';

-- Standardize STATUS Column

UPDATE supply
SET status = CONCAT(
UPPER(LEFT(LOWER(TRIM(status)), 1)),
LOWER(SUBSTR(TRIM(status), 2)));


-- Step 2: Remove rows with invalid status
DELETE FROM supply
WHERE status NOT IN ('Active','Inactive','Pending');

-- Standardize CATEGORY Column
UPDATE supply
SET category = CASE
WHEN LOWER(REPLACE(TRIM(category),'-',' ')) LIKE '%dry fruit%' THEN 'Dry Fruits'
WHEN LOWER(TRIM(category)) IN ('cereals','cereal') THEN 'Cereals'
WHEN LOWER(TRIM(category)) IN ('grains','grain') THEN 'Grains'
WHEN LOWER(TRIM(category)) IN ('oils','oil') THEN 'Oils'
WHEN LOWER(TRIM(category)) IN ('spices','spice') THEN 'Spices'
WHEN LOWER(TRIM(category)) IN ('pulses','pulse') THEN 'Pulses'
WHEN LOWER(TRIM(category)) IN ('grocery','groceries') THEN 'Grocery'
ELSE CONCAT(UPPER(LEFT(LOWER(TRIM(category)),1)),
LOWER(SUBSTR(TRIM(category),2)))
END;


-- Standardize WAREHOUSE LOCATION

UPDATE supply
SET warehouse_location = CASE
WHEN LOWER(REPLACE(REPLACE(TRIM(warehouse_location),' ',''),'-',''))
LIKE '%a' THEN 'Warehouse A'
WHEN LOWER(REPLACE(REPLACE(TRIM(warehouse_location),' ',''),'-',''))
LIKE '%b' THEN 'Warehouse B'
WHEN LOWER(REPLACE(REPLACE(TRIM(warehouse_location),' ',''),'-',''))
LIKE '%c' THEN 'Warehouse C'
ELSE NULL
END;

DELETE FROM supply WHERE warehouse_location IS NULL;

select count(*) from supply;

-- Remove Special Characters from Names

UPDATE supply SET
product_name = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(product_name,
'@',''),'#',''),'!',''),'$',''),'%',''),
'^',''),'&',''),'*',''),'?',''),'~','')),
supplier_name = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(supplier_name,
'@',''),'#',''),'!',''),'$',''),'%',''),
'^',''),'&',''),'*',''),'?',''),'~',''));

select * from supply;

-- - Remove rows whose name still starts with a digit
DELETE FROM supply
WHERE LEFT(TRIM(product_name), 1) BETWEEN '0' AND '9';

--  Fix Invalid Supplier Contacts

UPDATE supply
SET supplier_contact = NULL
WHERE 
    supplier_contact IS NULL
    OR TRIM(supplier_contact) = ''
    OR NOT TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$';


select * from supply;

update supply
set supplier_contact ='9848786858'
where supplier_contact is null;

select * from supply;


-- Standardize Date Formats to YYYY-MM-DD

-- Convert DD-Mon-YY format (e.g. 03-Jan-24)
UPDATE supply
SET last_restocked_date =
DATE_FORMAT(STR_TO_DATE(last_restocked_date,'%d-%b-%y'),'%Y-%m-%d')
WHERE last_restocked_date LIKE '__-___-__';

-- Convert DD/MM/YYYY format (e.g. 15/02/2024)
UPDATE supply
SET last_restocked_date =
DATE_FORMAT(STR_TO_DATE(last_restocked_date,'%d/%m/%Y'),'%Y-%m-%d')
WHERE last_restocked_date LIKE '__/__/____';

-- NULL out invalid placeholder values
UPDATE supply
SET last_restocked_date = NULL
WHERE last_restocked_date IN ('future_date','99-99-2024','00-00-0000','NA','???')
OR last_restocked_date LIKE '99%';

-- --   -- -- -- -- -- 

-- Convert DD/MM/YYYY format (e.g. 15/02/2024)
UPDATE supply
SET expiry_date=
DATE_FORMAT(STR_TO_DATE(expiry_date,'%d/%m/%Y'),'%Y-%m-%d')
WHERE expiry_date LIKE '__/__/____';

-- NULL out invalid placeholder values
UPDATE supply
SET expiry_date = NULL
WHERE expiry_date IN ('future_date','99-99-2024','00-00-0000','NA','???')
OR expiry_date LIKE '99%';



-- Convert DD-Mon-YY format (e.g. 03-Jan-24)
UPDATE supply
SET expiry_date =
DATE_FORMAT(STR_TO_DATE(expiry_date,'%d-%b-%y'),'%Y-%m-%d')
WHERE expiry_date LIKE '__-___-__';


select expiry_date,last_restocked_date from supply;

delete from supply
where expiry_date is null;

delete from supply
where last_restocked_date  is null;

-- Delete Rows Where Expiry Date < Restock Date

DELETE FROM supply
WHERE 
    (
        CASE
            WHEN expiry_date LIKE '____-__-__' 
                THEN STR_TO_DATE(expiry_date, '%Y-%m-%d')
            WHEN expiry_date LIKE '__-___-__' 
                THEN STR_TO_DATE(expiry_date, '%d-%b-%y')
            WHEN expiry_date LIKE '__/__/____' 
                THEN STR_TO_DATE(expiry_date, '%d/%m/%Y')
        END
    )
    <
    (
        CASE
            WHEN last_restocked_date LIKE '____-__-__' 
                THEN STR_TO_DATE(last_restocked_date, '%Y-%m-%d')
            WHEN last_restocked_date LIKE '__-___-__' 
                THEN STR_TO_DATE(last_restocked_date, '%d-%b-%y')
            WHEN last_restocked_date LIKE '__/__/____' 
                THEN STR_TO_DATE(last_restocked_date, '%d/%m/%Y')
        END
    );


select * from supply;

-- update Rows with NULL Batch Number

update supply
set batch_number = 'Not available'
WHERE batch_number IS NULL
OR TRIM(batch_number) = '';


--  Create Clean Table

-- Create the clean table with constraints
CREATE TABLE clean_inventory (
product_id VARCHAR(10) PRIMARY KEY,
product_name VARCHAR(100) NOT NULL,
category VARCHAR(50) NOT NULL,
supplier_name VARCHAR(100) NOT NULL,
supplier_contact int,
warehouse_location VARCHAR(20) NOT NULL,
quantity_in_stock INT NOT NULL,
reorder_level INT NOT NULL,
unit_price int NOT NULL,
last_restocked_date DATE NOT NULL,
expiry_date DATE NOT NULL,
batch_number VARCHAR(20) NOT NULL,
status VARCHAR(20) NOT NULL
);

select supplier_contact from supply;

-- Insert only clean, validated rows
INSERT INTO clean_inventory
SELECT
    product_id,
    TRIM(product_name),
    category,
    TRIM(supplier_name),
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
FROM supply
WHERE 
    product_name IS NOT NULL
    AND TRIM(product_name) != ''
    AND category IS NOT NULL
    AND supplier_name IS NOT NULL
    AND warehouse_location IN ('Warehouse A','Warehouse B','Warehouse C')
    AND batch_number IS NOT NULL
    AND TRIM(batch_number) != ''
    AND status IN ('Active','Inactive','Pending');


SELECT supplier_contact
FROM supply
WHERE 
    supplier_contact IS NOT NULL
    AND (
        LENGTH(TRIM(supplier_contact)) > 10
        OR NOT TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$'
    );



INSERT INTO supply
SELECT
    product_id,
    TRIM(product_name),
    category,
    TRIM(supplier_name),
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
FROM supply
WHERE 
    product_name IS NOT NULL
    AND TRIM(product_name) != ''
    AND category IS NOT NULL
    AND supplier_name IS NOT NULL
    AND warehouse_location IN ('Warehouse A','Warehouse B','Warehouse C')
    AND batch_number IS NOT NULL
    AND TRIM(batch_number) != ''
    AND status IN ('Active','Inactive','Pending')
    AND TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$';


DESCRIBE clean_inventory;


INSERT INTO clean_inventory (
    product_id,
    product_name,
    category,
    supplier_name,
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
)
SELECT
    product_id,
    TRIM(product_name),
    category,
    TRIM(supplier_name),
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
FROM supply
WHERE 
    product_name IS NOT NULL
    AND TRIM(product_name) != ''
    AND category IS NOT NULL
    AND supplier_name IS NOT NULL
    AND warehouse_location IN ('Warehouse A','Warehouse B','Warehouse C')
    AND batch_number IS NOT NULL
    AND TRIM(batch_number) != ''
    AND status IN ('Active','Inactive','Pending');


select * from clean_inventory;
SELECT COUNT(*) 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'supply';

DROP TABLE clean_inventory;

CREATE TABLE clean_inventory (
    product_id VARCHAR(10) PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    supplier_name VARCHAR(100),
    supplier_contact BIGINT,
    warehouse_location VARCHAR(50),
    quantity_in_stock INT,
    reorder_level INT,
    unit_price DECIMAL(10,2),
    last_restocked_date DATE,
    expiry_date DATE,
    batch_number VARCHAR(50),
    status VARCHAR(20)
);


SELECT COUNT(*) FROM clean_inventory;

select count(*) from supply;


INSERT INTO clean_inventory (
    product_id,
    product_name,
    category,
    supplier_name,
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
)
SELECT
    product_id,
    TRIM(product_name),
    category,
    TRIM(supplier_name),

    -- safe supplier_contact
    CASE 
        WHEN TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$'
        THEN supplier_contact
        ELSE NULL
    END,

    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status

FROM supply
WHERE 
    product_name IS NOT NULL
    AND TRIM(product_name) != ''
    AND category IS NOT NULL
    AND supplier_name IS NOT NULL
    AND warehouse_location IN ('Warehouse A','Warehouse B','Warehouse C')
    AND batch_number IS NOT NULL
    AND TRIM(batch_number) != ''
    AND status IN ('Active','Inactive','Pending')
    AND quantity_in_stock >= 0
    AND reorder_level > 0
    AND unit_price > 0;




INSERT INTO clean_inventory (
    product_id,
    product_name,
    category,
    supplier_name,
    supplier_contact,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
)
SELECT
    product_id,
    TRIM(product_name),
    category,
    TRIM(supplier_name),
    CASE 
        WHEN TRIM(supplier_contact) REGEXP '^[6-9][0-9]{9}$' 
        THEN supplier_contact 
        ELSE NULL 
    END,
    warehouse_location,
    quantity_in_stock,
    reorder_level,
    unit_price,
    last_restocked_date,
    expiry_date,
    batch_number,
    status
FROM supply
WHERE 
    product_name IS NOT NULL
    AND TRIM(product_name) != ''
    AND category IS NOT NULL
    AND supplier_name IS NOT NULL
    AND warehouse_location IN ('Warehouse A','Warehouse B','Warehouse C')
    AND batch_number IS NOT NULL
    AND TRIM(batch_number) != ''
    AND status IN ('Active','Inactive','Pending')
    AND quantity_in_stock >= 0
    AND reorder_level > 0
    AND unit_price > 0;


UPDATE supply
SET last_restocked_date = NULL
WHERE TRIM(last_restocked_date) = '';

UPDATE supply
SET expiry_date = NULL
WHERE TRIM(expiry_date) = '';

select * from clean_inventory;

desc clean_inventory;

alter table clean_inventory modify column supplier_contact varchar(10);


select * from clean_inventory;


update clean_inventory set last_restocked_date ='2024-04-17'
where last_restocked_date is null;

update clean_inventory set expiry_date ='2026-04-17'
where expiry_date is null;



