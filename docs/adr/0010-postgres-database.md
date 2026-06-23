# PostgreSQL for the database

We use PostgreSQL across all environments. This is a deliberate deviation from the Rails 8 default (SQLite): Postgres gives us a production-grade concurrent database for the background generation workload (Solid Queue runs against it), room for richer querying of Plans/Steps/Artworks, and standard cloud-hosting paths — at the cost of a heavier local setup than SQLite. A database swap later is painful, so this is fixed now rather than defaulted-and-migrated.
