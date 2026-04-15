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



