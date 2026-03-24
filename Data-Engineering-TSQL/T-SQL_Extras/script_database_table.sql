
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
		  ,CASE WHEN 
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
	WHERE t.TABLE_NAME = 'Txn' 
)
SELECT 
DISTINCT
'CREATE TABLE '+QUOTENAME(t.TABLE_SCHEMA)+'.'+QUOTENAME(t.TABLE_NAME)
+'('+
+STUFF
(
(SELECT ' , '+
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

FOR XML PATH(''))
,1
,1
,''
)+
' ) '
FROM TABLE_DEFINATIONS t


/*

CREATE TABLE, Balancedecimal , BetID bigint  NOT NULL   , ExtraInfo varchar ( 2000 )  NULL   , ExtTxnTypeID smallint  NOT NULL   , Odddecimal , Payoutdecimal , ProviderBetRef varchar ( 100 )  NOT NULL   , ProviderTxnRef varchar ( 100 )  NOT NULL   , Stake decimal , TxnDate datetime  NOT NULL   , TxnID bigint  NOT NULL   , TxnTypeID tinyint  NOT NULL  
*/