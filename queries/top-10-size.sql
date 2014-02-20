-- file: top-10-size.sql
-- descrition: lists top 10 objects size in database.
-- version: >= 9.0
-- depends: NONE

WITH table_stats AS (
  SELECT
    schemaname,
    tablename,
    pg_relation_size(schemaname || '.'|| tablename) as table_size,
    (pg_total_relation_size(schemaname || '.'|| tablename) - pg_relation_size(schemaname || '.'|| tablename)) as index_size,
    pg_total_relation_size(schemaname || '.'|| tablename) as total_size
  FROM
    pg_tables
)
SELECT
  table_stats.schemaname,
  table_stats.tablename,
  pg_size_pretty(table_stats.table_size) as table_size,
  pg_size_pretty(table_stats.index_size) as index_size,
  pg_size_pretty(table_stats.total_size) as total_size
FROM
  table_stats
 
WHERE
  -- ajuste o filtro conforme sua necessidade!
  table_stats.schemaname = 'public'
ORDER BY
  table_stats.total_size desc,
  table_stats.index_size desc,
  table_stats.table_size desc
LIMIT 10;