USE [DW_HollywoodBets]

GO

SELECT
    bs.database_name[DatabaseName]
	, CASE type 
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Differential'
        WHEN 'L' THEN 'Transaction Log'
        WHEN 'F' THEN 'File'
        WHEN 'G' THEN 'Differential File'
        WHEN 'P' THEN 'Partial'
        WHEN 'Q' THEN 'Differential Partial'
     ELSE 'Unknown'
    END AS BackupType
   ,MAX(bs.backup_finish_date)[Last_Full_Back]
   ,IIF(DATEDIFF(DAY,MAX(bs.backup_finish_date),GETDATE()) = 0,1,DATEDIFF(DAY,MAX(bs.backup_finish_date),GETDATE()))[HowManyDays]
   ,max_back_size.Back_Size[Back_SizeTB]
   --,location_bak.logical_device_name
FROM msdb.dbo.BackupSet bs WITH(NOLOCK)
CROSS APPLY 
(
  SELECT 
     CAST(MAX(bs_inner.backup_size / 1024.0 /1024 / 1024 /1024) AS DECIMAL(10,2))[Back_Size]
  FROM msdb.dbo.backupset bs_inner WITH(NOLOCK)
  WHERE bs_inner.database_name = bs.database_name AND bs.type = bs_inner.type
)max_back_size
 
WHERE bs.database_name = 'DW_hollywoodbets'
GROUP BY 
    bs.database_name
   ,bs.type
   ,max_back_size.Back_Size
   --,location_bak.logical_device_name
HAVING DATEDIFF(DAY,MAX(bs.backup_finish_date),GETDATE()) >= 1 AND bs.type IN('D','I')