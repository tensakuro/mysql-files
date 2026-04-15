show databases;

create database chain;

use chain;

select * from supply_chain_inventory_dirty;

-- renaming table supply_chain_inventory_dirty

rename table supply_chain_inventory_dirty to supply;

select * from supply;



