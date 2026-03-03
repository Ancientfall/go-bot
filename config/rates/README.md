# Contract Rate CSVs

Place vendor contract rate CSVs here. One file per vendor:

- `pmi.csv`
- `arcwood.csv`
- `rcs.csv`
- `c-logistics.csv`
- `danos.csv`

## Required CSV Format

Header row required. Minimum columns: `description` and `rate`.

```csv
description,catalog_number,unit,rate,category
"Forklift Rental - Daily",FK-100,DAY,450.00,Equipment
"Labor - General Helper",,HR,35.50,Labor
```

Column detection is flexible — the loader looks for keywords:
- **description**: `description`, `desc`, `item`
- **rate**: `rate`, `price`, `cost`
- **catalog**: `catalog`, `part`, `sku`, `item_number`
- **unit**: `unit`, `uom`
- **category**: `category`, `cat`, `type`

Dollar signs and commas in rate values are stripped automatically.
