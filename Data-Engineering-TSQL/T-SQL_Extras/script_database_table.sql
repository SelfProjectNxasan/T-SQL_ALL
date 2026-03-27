
WITH TABLE_DEFINATIONS AS
(
	SELECT
	  DISTINCT 
		   t.TABLE_NAME
		  ,col.TABLE_SCHEMA
		  ,col.COLUMN_NAME
		  ,col.DATA_TYPE
		  ,col.CHARACTER_MAXIMUM_LENGTH
		  ,col.COLUMN_DEFAULT 
		  ,col.IS_NULLABLE 
		  ,computed_columns_def.definition[computed_columns]
		  ,CASE WHEN partitioned_table.partition_scheme IS NULL THEN 'NO'  ELSE 'YES' END AS 'partioned'
	FROM INFORMATION_SCHEMA.TABLES t WITH(NOLOCK)
	LEFT JOIN INFORMATION_SCHEMA.COLUMNS col WITH(NOLOCK) ON col.TABLE_NAME = t.TABLE_NAME 
		 AND col.TABLE_CATALOG = t.TABLE_CATALOG 
		 AND col.TABLE_SCHEMA = t.TABLE_SCHEMA
	LEFT JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tbl_con WITH(NOLOCK) ON tbl_con.TABLE_NAME = t.TABLE_NAME 
	     AND t.TABLE_SCHEMA = tbl_con.TABLE_SCHEMA
	CROSS APPLY 
	(
		SELECT
		  inner_com.definition
		FROM sys.tables inner_tbl WITH(NOLOCK) 
		LEFT JOIN sys.schemas sc WITH(NOLOCK) ON sc.schema_id = inner_tbl.schema_id
		LEFT JOIN sys.columns inner_col WITH(NOLOCK) ON inner_tbl.object_id = inner_col.column_id
		LEFT JOIN sys.computed_columns inner_com WITH(NOLOCK) ON inner_com.column_id = inner_col.column_id 
			  AND OBJECT_NAME(inner_com.object_id) = t.TABLE_NAME 
		WHERE inner_tbl.name = t.TABLE_NAME AND t.TABLE_SCHEMA = SCHEMA_NAME(sc.schema_id)
	)
	computed_columns_def
	OUTER APPLY
	(
	 SELECT 
		t_.name AS table_name,
		i.name AS index_name,
		ps.name AS partition_scheme,
		fg.name AS filegroup_name,
		df.physical_name
	FROM sys.tables t_
	JOIN sys.indexes i 
		ON t_.object_id = i.object_id
	JOIN sys.partition_schemes ps 
		ON i.data_space_id = ps.data_space_id
	JOIN sys.destination_data_spaces dds 
		ON ps.data_space_id = dds.partition_scheme_id
	JOIN sys.filegroups fg 
		ON dds.data_space_id = fg.data_space_id
	JOIN sys.database_files df 
		ON fg.data_space_id = df.data_space_id
	WHERE t_.name = t.TABLE_NAME 
	)partitioned_table
--WHERE t.TABLE_NAME = 'Txn' 
)
SELECT 
DISTINCT
'CREATE TABLE '+QUOTENAME(t.TABLE_SCHEMA)+'.'+QUOTENAME(t.TABLE_NAME)
+'('+
+STUFF
(
	(
		SELECT 
		' , '+
		t.COLUMN_NAME
		+CASE WHEN LOWER(t.DATA_TYPE) IN('int','bigint','bit','tinyint','smallint','float','money','datetime','date','decimal')
			  THEN ' '+t.DATA_TYPE+' ' + IIF(t.IS_NULLABLE = 'YES',' NULL ',' NOT NULL ')
			  +IIF(t.COLUMN_DEFAULT IS NOT NULL,' DEFAULT '+t.COLUMN_DEFAULT,' ')
			  WHEN LOWER(t.DATA_TYPE) IN('varchar','nvarchar','varbinary','char','nchar','xml')
			  THEN ' '+ t.DATA_TYPE + ' ( '+ CAST(IIF(CAST(t.CHARACTER_MAXIMUM_LENGTH AS BIGINT) > 8000,4000,IIF(t.CHARACTER_MAXIMUM_LENGTH = -1,4000,t.CHARACTER_MAXIMUM_LENGTH)) AS VARCHAR(100))+' ) '
			  +IIF(t.IS_NULLABLE = 'YES',' NULL ',' NOT NULL ')
			  +IIF(t.COLUMN_DEFAULT IS NOT NULL,' DEFAULT '+t.COLUMN_DEFAULT,' ')
			  ELSE t.DATA_TYPE END
		FROM TABLE_DEFINATIONS t 

		FOR XML PATH('')
	)
,1
,1
,''
)+
' ) '
,CASE WHEN t.partioned = 'YES' THEN CLUSTERED_INDEX_CONSTRAINT.INDEX_CONSTRAINT+'[PartitionSchema]' ELSE CLUSTERED_INDEX_CONSTRAINT.INDEX_CONSTRAINT+'[PRIMARY]' END
FROM TABLE_DEFINATIONS t
CROSS APPLY
(
SELECT 
 DISTINCT
 'CONSTRAINT '+QUOTENAME(tbl_con_.CONSTRAINT_NAME)+CHAR(10)+'PRIMARY KEY'+CHAR(10)+'CLUSTERED'+CHAR(10)+'('+
STUFF(
  (
  SELECT 
		', '+QUOTENAME(col_con.COLUMN_NAME)+ CHAR(10) + 'ASC'+CHAR(10)
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tbl_con_inner
INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE col_con ON tbl_con_inner.TABLE_NAME = col_con.TABLE_NAME 
AND 
tbl_con_inner.TABLE_SCHEMA = col_con.TABLE_SCHEMA

WHERE tbl_con_inner.TABLE_NAME = tbl_con_.TABLE_NAME AND tbl_con_inner.CONSTRAINT_TYPE = 'PRIMARY KEY'
FOR XML PATH('')
 ),1,1,'')
 +') WITH ( '+ ' PAD_INDEX = '+CASE WHEN index_outer.is_padded = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+' , '+
  ' STATISTICS_NORECOMPUTE = '+ CASE WHEN index_outer.no_recompute = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+
  'IGNORE_DUP_KEY = '+CASE WHEN index_outer.ignore_dup_key = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+' ALLOW_ROW_LOCKS = '+ CHAR(10)
  +CASE WHEN index_outer.allow_row_locks = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+'ALLOW_PAGE_LOCKS = '+CASE WHEN index_outer.allow_page_locks = 0 THEN 'OFF' ELSE 'ON' END+
  CHAR(10)+', '+'OPTIMIZE_FOR_SEQUENTIAL_KEY = '+CASE WHEN index_outer.optimize_for_sequential_key = 0 THEN 'OFF' ELSE 'ON' END+CHAR(10)+') ON '[INDEX_CONSTRAINT]
 
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tbl_con_
CROSS APPLY
(
 SELECT 
      DISTINCT
	   index_options.allow_page_locks
	  ,index_options.allow_row_locks
	  ,index_options.no_recompute
	  ,index_options.optimize_for_sequential_key
	  ,index_options.is_padded
	  ,index_options.ignore_dup_key
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS t_inner_
INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE col_con ON t_inner_.TABLE_NAME = col_con.TABLE_NAME
CROSS APPLY
( 
	SELECT
	  i.allow_page_locks
	 ,i.allow_row_locks
	 ,s.no_recompute
	 ,i.optimize_for_sequential_key
	 ,i.is_padded
	 ,i.ignore_dup_key
	FROM sys.indexes i WITH(NOLOCK) 
	INNER  JOIN sys.stats s WITH(NOLOCK) ON s.object_id = i.object_id
	WHERE i.object_id = OBJECT_ID(t_inner_.TABLE_SCHEMA+'.'+t_inner_.TABLE_NAME) AND i.is_primary_key = 1
)index_options
WHERE OBJECT_ID(t_inner_.TABLE_SCHEMA+'.'+t_inner_.TABLE_NAME) = OBJECT_ID(tbl_con_.TABLE_SCHEMA+'.'+tbl_con_.TABLE_NAME) 
) index_outer
WHERE  tbl_con_.CONSTRAINT_TYPE = 'PRIMARY KEY' AND OBJECT_ID(tbl_con_.TABLE_SCHEMA+'.'+tbl_con_.TABLE_NAME) = OBJECT_ID(T.TABLE_SCHEMA+'.'+t.TABLE_NAME)
)CLUSTERED_INDEX_CONSTRAINT
