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
		  ,CASE WHEN EXISTS (SELECT 1 FROM sys.memory_optimized_tables_internal_attributes mt_ WHERE mt_.object_id = OBJECT_ID(t.TABLE_SCHEMA+'.'+t.TABLE_NAME))
		        THEN 'MEMORY_OPTIMIZED' 
		  ELSE 'NOT MEMORY_OPTIMIZED'
		  END AS 'IS_MEMORY_OPTOMIZED'
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
 )
,refined_table_def AS (
SELECT 
DISTINCT
'CREATE TABLE '+QUOTENAME(t.TABLE_SCHEMA)+'.'+QUOTENAME(t.TABLE_NAME)
+'('+
+STUFF
(
	(
		SELECT 
		DISTINCT
		' , '+
		t_inner_concat.COLUMN_NAME
		+CASE WHEN LOWER(t_inner_concat.DATA_TYPE) IN('int','bigint','bit','tinyint','datetime2','smallint','uniqueidentifier','float','money','datetime','date','decimal')
			  THEN ' '+QUOTENAME(t_inner_concat.DATA_TYPE)+' ' + IIF(t_inner_concat.IS_NULLABLE = 'YES',' NULL ',' NOT NULL ')
			  +IIF(t_inner_concat.COLUMN_DEFAULT IS NOT NULL,' DEFAULT '+t_inner_concat.COLUMN_DEFAULT,' ')
			  WHEN LOWER(t_inner_concat.DATA_TYPE) IN('varchar','nvarchar','varbinary','char','nchar','xml')
			  THEN ' '+ QUOTENAME(t_inner_concat.DATA_TYPE) + ' ( '+ CAST(IIF(CAST(t_inner_concat.CHARACTER_MAXIMUM_LENGTH AS BIGINT) >= 8000,4000,IIF(t_inner_concat.CHARACTER_MAXIMUM_LENGTH = -1,4000,t_inner_concat.CHARACTER_MAXIMUM_LENGTH)) AS VARCHAR(100))+' ) '
			  +IIF(t_inner_concat.IS_NULLABLE = 'YES',' NULL ',' NOT NULL ')
			  +IIF(t_inner_concat.COLUMN_DEFAULT IS NOT NULL,' DEFAULT '+t_inner_concat.COLUMN_DEFAULT,' ')
			  ELSE t_inner_concat.DATA_TYPE END
		FROM TABLE_DEFINATIONS t_inner_concat 
		WHERE t.TABLE_NAME = t_inner_concat.TABLE_NAME AND t.TABLE_SCHEMA = t_inner_concat.TABLE_SCHEMA
		FOR XML PATH('')
	)
,1
,2
,''
)+
' ) '[TABLE_SCHEMA]

,CASE 
    WHEN t.partioned = 'YES' 
	    THEN CLUSTERED_INDEX_CONSTRAINT.INDEX_CONSTRAINT
	WHEN t.partioned <> 'YES' AND t.IS_MEMORY_OPTOMIZED = 'MEMORY_OPTIMIZED'  THEN 
	  CLUSTERED_INDEX_CONSTRAINT.INDEX_CONSTRAINT 
	ELSE CLUSTERED_INDEX_CONSTRAINT.INDEX_CONSTRAINT  + '[PRIMARY]'END AS[CONSTRAINT_CONCAT]
,FOREIGN_KEY_CONSTRAINT.FK_CONSTRAINT[FOREIGNKEYS]
,OBJECT_ID(t.TABLE_SCHEMA+'.'+t.TABLE_NAME)[OBJECT_ID]
,t.IS_MEMORY_OPTOMIZED
,t.partioned
FROM TABLE_DEFINATIONS t
CROSS APPLY
(
SELECT 
 DISTINCT
 CASE WHEN 
   index_outer.type_desc = 'NONCLUSTERED HASH' THEN ' INDEX '
   ELSE ' CONSTRAINT 'END
    +QUOTENAME(index_outer.name)+CHAR(10)
 +
 ISNULL(RTRIM(LTRIM(SUBSTRING(index_outer.Constraints_Details,1,IIF((CHARINDEX(',',index_outer.Constraints_Details)-1) > 0,(CHARINDEX(',',index_outer.Constraints_Details)-1),LEN(index_outer.Constraints_Details))))),'NULL')
 +
CHAR(10)+ISNULL(index_outer.type_desc COLLATE Latin1_General_CI_AS_KS_WS,'NULL')+CHAR(10)+'('+
STUFF(
  (
  SELECT 
		', '+QUOTENAME(col_con.COLUMN_NAME)+ CHAR(10) + 'ASC'+CHAR(10)
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tbl_con_inner
INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE col_con ON tbl_con_inner.TABLE_NAME = col_con.TABLE_NAME 
AND 
tbl_con_inner.TABLE_SCHEMA = col_con.TABLE_SCHEMA

WHERE tbl_con_inner.TABLE_NAME = tbl_con_.TABLE_NAME AND tbl_con_inner.CONSTRAINT_TYPE IN('PRIMARY KEY','UNIQUE')
FOR XML PATH('')
 ),1,1,'')
 + CASE WHEN t.IS_MEMORY_OPTOMIZED = 'NOT MEMORY_OPTIMIZED' THEN 
  +') WITH ( '+ ' PAD_INDEX = '+CASE WHEN index_outer.is_padded = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+' , '+
  ' STATISTICS_NORECOMPUTE = '+ CASE WHEN index_outer.no_recompute = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+
  'IGNORE_DUP_KEY = '+CASE WHEN index_outer.ignore_dup_key = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+' ALLOW_ROW_LOCKS = '+ CHAR(10)
  +CASE WHEN index_outer.allow_row_locks = 0 THEN 'OFF' ELSE 'ON' END +CHAR(10)+', '+'ALLOW_PAGE_LOCKS = '+CASE WHEN index_outer.allow_page_locks = 0 THEN 'OFF' ELSE 'ON' END+
  CHAR(10)+', '+'OPTIMIZE_FOR_SEQUENTIAL_KEY = '+CASE WHEN index_outer.optimize_for_sequential_key = 0 THEN 'OFF' ELSE 'ON' END+CHAR(10)+') ON '
  WHEN index_outer.type_desc = 'NONCLUSTERED HASH' THEN 'WITH ( BUCKET_COUNT = 65536)'
  ELSE  '' END AS[INDEX_CONSTRAINT]
 
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
	  ,index_options.type_desc
	  ,index_options.name
	  ,index_options.Constraints_Details
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
	 ,i.type_desc
	 ,i.name
	 ,CASE 
	    WHEN i.type = 1 OR i.is_primary_key = 1 
	         THEN 'PRIMARY KEY'+','+CAST(i.type_desc AS VARCHAR(100)) 
	    WHEN i.type = 2 AND i.is_unique_constraint = 1
	         THEN 'UNIQUE'+','+CAST(i.type AS VARCHAR(100)) 
	    ELSE 'NULL' 
	     
	 END AS 'Constraints_Details'
	FROM sys.indexes i WITH(NOLOCK) 
	INNER  JOIN sys.stats s WITH(NOLOCK) ON s.object_id = i.object_id
	WHERE i.object_id = OBJECT_ID(t_inner_.TABLE_SCHEMA+'.'+t_inner_.TABLE_NAME) AND (i.is_primary_key = 1 OR i.is_unique = 1)
	)index_options
WHERE OBJECT_ID(t_inner_.TABLE_SCHEMA+'.'+t_inner_.TABLE_NAME) = OBJECT_ID(tbl_con_.TABLE_SCHEMA+'.'+tbl_con_.TABLE_NAME) 
) index_outer
WHERE  tbl_con_.CONSTRAINT_TYPE IN('PRIMARY KEY','UNIQUE') AND OBJECT_ID(tbl_con_.TABLE_SCHEMA+'.'+tbl_con_.TABLE_NAME) = OBJECT_ID(T.TABLE_SCHEMA+'.'+t.TABLE_NAME)
)CLUSTERED_INDEX_CONSTRAINT
CROSS APPLY (
SELECT 
   STUFF(
   (SELECT
  
  ','+'CONSTRAINT '+ISNULL(OBJECT_NAME(fk.object_id),'NULL')+' FOREIGN KEY ('+(SELECT c.name FROM sys.all_columns c WHERE c.column_id = fkc.referenced_column_id AND c.object_id = fkc.referenced_object_id)+')
   REFERENCES '+QUOTENAME((SELECT so.name FROM sys.all_objects o INNER JOIN sys.tables to_ ON to_.object_id = o.object_id INNER JOIN sys.schemas so ON so.schema_id = to_.schema_id WHERE o.object_id = fk.referenced_object_id))+'.'+QUOTENAME(OBJECT_NAME(fk.referenced_object_id))+'
   ('+(SELECT c.name FROM sys.all_columns c WHERE c.column_id = fkc.referenced_column_id AND c.object_id = fkc.referenced_object_id)+')
   
   ON DELETE '+(fk.delete_referential_action_desc COLLATE Latin1_General_CI_AS_KS_WS)+', ON UPDATE '+(fk.update_referential_action_desc COLLATE Latin1_General_CI_AS_KS_WS)+''
FROM sys.foreign_keys fk 
INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
where fk.parent_object_id = OBJECT_ID(t.TABLE_SCHEMA+'.'+t.TABLE_NAME)
FOR XML PATH('')
   )
,1,1,'')[FK_CONSTRAINT]

)FOREIGN_KEY_CONSTRAINT
)
SELECT 
  t.TABLE_SCHEMA
 ,t.CONSTRAINT_CONCAT
 ,t.OBJECT_ID
 ,t.FOREIGNKEYS
 ,t.IS_MEMORY_OPTOMIZED
 ,t.partioned
 ,OBJECT_NAME(t.OBJECT_ID)
FROM refined_table_def t
WHERE OBJECT_NAME(t.OBJECT_ID) = 'DimProduct'

DECLARE 
    @RED_SERVER_SRC          VARCHAR(MAX)
   ,@YELLOW_SERVER_SRC       VARCHAR(MAX)
   ,@RED_DATABASE_DEST       VARCHAR(MAX)
   ,@YELLOW_DATABASE_DEST    VARCHAR(MAX)
   ,@RED_DIRECTORY_PATH      NVARCHAR(MAX)
   ,@YELLOW_DIRECTORY_PATH   NVARCHAR(MAX)
   ,@RED_DATABASE_SRC        VARCHAR(MAX)
   ,@YELLOW_DATABASE_SRC     VARCHAR(MAX)
   ,@CreateYellowProcFound   BIT
   ,@create_splits           BIT
   ,@split_range             VARCHAR(3)
   ,@lnk_srv_creeted         BIT 
   ,@sql_command             NVARCHAR(MAX)
   ,@linked_server_prd       VARCHAR(MAX)     =  'SQL Server'
IF NOT EXISTS(SELECT * FROM master.sys.servers)
 BEGIN TRY
        SET @sql_command = 'EXEC master.dbo.sp_addlinkedserver @server = N'''+@RED_DATABASE_SRC+''', @srvproduct = N'''+@linked_server_prd+''''
 END TRY 
 BEGIN CATCH 
        PRINT 'FAILED TO CREATE LINKED SERVER ON THIS INSTANCE : ['+CAST(ERROR_MESSAGE AS VARCHAR(100))+']'  
		RETURN
 END CATCH 

  BEGIN TRY
        SET @sql_command = 'EXEC master.dbo.sp_addlinkedserver @server = N'''+@YELLOW_SERVER_SRC+''', @srvproduct = N'''+@linked_server_prd+''''
 END TRY 
 BEGIN CATCH 
        PRINT 'FAILED TO CREATE LINKED SERVER ON THIS INSTANCE : ['+CAST(ERROR_MESSAGE AS VARCHAR(100))+']'  
		RETURN
 END CATCH 

   BEGIN TRY
        SET @sql_command = 'EXEC master.dbo.sp_addlinkedserver @server = N'''+@YELLOW_SERVER_SRC+''', @srvproduct = N'''+@linked_server_prd+''''
 END TRY 
 BEGIN CATCH 
        PRINT 'FAILED TO CREATE LINKED SERVER ON THIS INSTANCE : ['+CAST(ERROR_MESSAGE AS VARCHAR(100))+']'  
		RETURN
 END CATCH 

