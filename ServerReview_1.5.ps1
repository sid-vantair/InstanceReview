<#
 
.NAME
ServerReview.ps1
 
.SYNOPSIS
This is a Powershell script that performs a MSSQL DB server review to verify configuration settings according to Microsoft best practices
 
.DESCRIPTION
This has been tested to work on instances with SQL 2012 or greater. This may or may not work on instance with SQL 2008 or 2008 R2.
 
 
.PARAMETERS
The script requires two parameters SQL server InstanceName, Type of authentication: Windows or SQL Authentication
 
.EXAMPLE
./ServerReview.ps1
 
.VERSION
1.4
 
.NOTES
Author: Sid Vantair
 
This script is offered "as is" with no warranty. While this script is tested and working in my environment, it is recommended that you test these scripts in a test environment before using in your production environment.
#>
 
param
(
 [string]$instanceName = "$(Read-Host 'Enter the SQL server Instance')",
 [string]$choice = "$(Read-Host 'W--Windows authentication S--SQL authentication')"
  
)
 
#requires -version 3
 
 
function ServerReview
{
 
$managedComputer = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' $env:computername
 
 try
 {
 
"`n"
 
  
Write-Host "-----------------------Server Level Settings-------------------------" -Background Red
 
"`n"
 
Write-Host Server Hostname : $env:computername
 
"`n"
 
Write-Host Operating System ":" (Get-WmiObject win32_operatingsystem).caption
 
"`n"
 
Get-WmiObject –class Win32_processor | select-object -property DeviceID,NumberOfCores,NumberOfLogicalProcessors, status | format-table -autosize
 
"`n"
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

try

{
 
Get-WmiObject -NameSpace root\cimv2\power -Class win32_PowerPlan | Select-Object -Property @{N='PowerPlans';E={$_.ElementName}}, @{N='Setting';E={$_.isActive}} | Format-Table -AutoSize
 
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }
"`n"
 
try
{
Get-WmiObject Win32_Volume -ComputerName $env:computername | Format-Table Name, ` @{Name="Size(GB)";Expression={"{0:0,0.00}" -f($_.Capacity/1gb)}}, ` @{Name="Free Space(GB)";Expression={"{0:0,0.00}" -f($_.FreeSpace/1gb)}}, ` @{Name="Free (%)";Expression={"{0,6:P0}" -f(($_.FreeSpace/1gb) / ($_.Capacity/1gb))}}, ` @{Name="Block Size";Expression={"{0,6}" -f($_.BlockSize/1kb)+"k"}} -AutoSize
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"
 
 try
 {

 $volumes = Get-WmiObject -ComputerName $env:COMPUTERNAME -Class win32_volume | Where-Object { $_.drivetype -eq 3 -and $_.driveletter -ne $null }
  
 foreach ($volume in $volumes)
 {
  
 $analysis = $volume.DefragAnalysis().DefragAnalysis
 $name = $volume.name
 $fragmentation = $volume.DefragAnalysis().DefragAnalysis.FilePercentFragmentation
 $recommendation =$volume.DefragAnalysis().DefragRecommended
 Write-Host "DriveLetter:  " $name
 Write-Host "Fragmentation:"$fragmentation %
 Write-Host "DefragNeeded: "$recommendation
 "`n"
 }

 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }
  
"`n"
  
try{

$ManagedComputer.services | Select-object -property @{N='ServiceName';E={$_.Displayname}}, Servicestate, startmode, serviceaccount | Format-Table -AutoSize
 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"
 
 try 
 {

 If($server.IsClustered -eq 'true')
{
 Write-Host "This is a Windows failover clustered instance"
 Get-ClusterGroup | Format-Table -AutoSize
 Get-ClusterResource | Where-Object {$_.OwnerGroup -like "SQL Server*"} | Sort-Object -Property OwnerGroup | Format-Table -AutoSize
 }
 
 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

 try
 {

 If($server.IsHadrEnabled -eq "true")
 
 {
 Write-Host "This instance is enabled for Availability Groups"
 
 $SQLQuery = " SELECT AG.name AS [AvailabilityGroupName],
 ISNULL(agstates.primary_replica, '') AS [PrimaryReplicaServerName],
 arstates.role_desc,
 dbcs.database_name AS [DatabaseName],
 dbrs.synchronization_state_desc,
 ISNULL(dbrs.is_suspended, 0) AS [IsSuspended]
 FROM master.sys.availability_groups AS AG
 LEFT OUTER JOIN master.sys.dm_hadr_availability_group_states as agstates
 ON AG.group_id = agstates.group_id
 INNER JOIN master.sys.availability_replicas AS AR
 ON AG.group_id = AR.group_id
 INNER JOIN master.sys.dm_hadr_availability_replica_states AS arstates
 ON AR.replica_id = arstates.replica_id AND arstates.is_local = 1
 INNER JOIN master.sys.dm_hadr_database_replica_cluster_states AS dbcs
 ON arstates.replica_id = dbcs.replica_id
 LEFT OUTER JOIN master.sys.dm_hadr_database_replica_states AS dbrs
 ON dbcs.replica_id = dbrs.replica_id AND dbcs.group_database_id = dbrs.group_database_id
 ORDER BY AG.name ASC, dbcs.database_name "
 
 if ($choice -eq 'W')
 
 { Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server | Format-Table -AutoSize }
 
 if ($choice -eq 'S')
 
 { Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server -Username $Username -Password $password | Format-Table -AutoSize }
 
"`n"
 
 }
 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

 try
 {

If($server.IsClustered -eq 'true')
{


if ($env:computername -eq (Get-WmiObject -Class Win32_computersystem -ComputerName $instanceName | Select-Object -ExpandProperty Name))

 {
   Write-Host  "This is active node of the cluster"
   "`n"

   Set-Location C:\
$proc = Get-CimInstance Win32_Process -Filter “name = 'sqlservr.exe'”
 
$CimMethod = Invoke-CimMethod -InputObject $proc -MethodName GetOwner
 
  
$objUser = New-Object System.Security.Principal.NTAccount($CimMethod.Domain, $CimMethod.User)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$NTName = $strSID.Value
 
 
$ManageVolumePriv = 0
$LockPagesPriv = 0
  
secedit /export /areas USER_RIGHTS /cfg UserRights.inf /quiet
  
$FileResults = Get-Content UserRights.inf
  
 Remove-Item UserRights.inf
  
 foreach ($line in $FileResults)
{
if($line -like "SeManageVolumePrivilege*" -and $line -like "*$NTName*" )
{
$ManageVolumePriv = 1
}
  
if($line -like "SeLockMemoryPrivilege*" -and $line -like "*$NTName*")
{
$LockPagesPriv = 1
}
}
 
  
Write-Host "Lock Pages In Memory:" $LockPagesPriv

"`n"

Write-Host "Instant File Initialization:" $ManageVolumePriv

"`n"

} 


else { Write-Host "This is the inactive node of the cluster"

"`n"

}

}


else 

{

Set-Location C:\
$proc = Get-CimInstance Win32_Process -Filter “name = 'sqlservr.exe'”
 
$CimMethod = Invoke-CimMethod -InputObject $proc -MethodName GetOwner
 
  
$objUser = New-Object System.Security.Principal.NTAccount($CimMethod.Domain, $CimMethod.User)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$NTName = $strSID.Value
 
 
$ManageVolumePriv = 0
$LockPagesPriv = 0
  
secedit /export /areas USER_RIGHTS /cfg UserRights.inf /quiet
  
$FileResults = Get-Content UserRights.inf
  
 Remove-Item UserRights.inf
  
 foreach ($line in $FileResults)
{
if($line -like "SeManageVolumePrivilege*" -and $line -like "*$NTName*" )
{
$ManageVolumePriv = 1
}
  
if($line -like "SeLockMemoryPrivilege*" -and $line -like "*$NTName*")
{
$LockPagesPriv = 1
}
}
 
  
Write-Host " Lock Pages In Memory:" $LockPagesPriv

"`n"

Write-Host " Instant File Initialization:" $ManageVolumePriv

"`n"

}
 
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

Write-Host "------------------SQL Server Instance Level Settings ------------" -BackgroundColor Red
 
"`n"
 
try
{

Write-Host "InstanceName :" $Server.DomainInstanceName
 
"`n"
 
Write-Host "Edition : " $server.Product $server.Edition
 
"`n"
 
if ($server.VersionMajor -eq '13')
{$version = 'SQL 2016'}
 
if ($server.VersionMajor -eq '12')
{$version = 'SQL 2014'}
 
if ($server.VersionMajor -eq '11')
{$version = 'SQL 2012'}
 
if ($server.VersionMajor -eq '10' -and $server.VersionMinor -eq '50')
{$version = 'SQL 2008 R2'}
 
if ($server.VersionMajor -eq '10' -and $server.VersionMinor -eq '0')
{$version = 'SQL 2008'}
 
 
Write-Host "Version : " $Version
 
"`n"
 
Write-Host "ServicePack : " $server.ProductLevel
 
"`n"
 
Write-Host "Physical Memory installed on the server (MB) : " $server.PhysicalMemory
 
"`n"
 
Write-Host $server.Configuration.MinServerMemory.DisplayName ":" $server.Configuration.MinServerMemory.RunValue
 
 
"`n"
 
Write-Host $server.Configuration.MaxServerMemory.DisplayName ":" $server.Configuration.MaxServerMemory.RunValue
 
 
"`n"
 
 
Write-Host Backup compression ":" $server.Configuration.DefaultBackupCompression.RunValue
 
 
"`n"
 
write-host $server.Configuration.MaxDegreeOfParallelism.DisplayName ":" $server.Configuration.MaxDegreeOfParallelism.RunValue
 
 
"`n"
 
write-host $server.Configuration.CostThresholdForParallelism.DisplayName ":" $server.Configuration.CostThresholdForParallelism.RunValue
 
"`n"
 
write-host Server Collation ":" $server.Collation
 
 
"`n"
 
write-Host $server.Configuration.OptimizeAdhocWorkloads.DisplayName ":" $server.Configuration.OptimizeAdhocWorkloads.RunValue
 
 
"`n"
 
write-host $server.configuration.IsSqlClrEnabled.DisplayName ":" $server.Configuration.IsSqlClrEnabled.RunValue
 
"`n"
 
Write-Host $server.Configuration.PriorityBoost.DisplayName ":" $server.Configuration.PriorityBoost.RunValue
 
"`n"
 
Write-Host $server.Configuration.FullTextCrawlRangeMax.DisplayName ":" $server.Configuration.FullTextCrawlRangeMax.RunValue
 
"`n"
 
Write-Host $server.Configuration.DatabaseMailEnabled.DisplayName ":" $server.Configuration.DatabaseMailEnabled.RunValue
 
"`n"
 
Write-Host $server.Configuration.AgentXPsEnabled.DisplayName ":" $server.Configuration.AgentXPsEnabled.RunValue
 
"`n"
 
Write-Host "ErrorLogPath: " $server.ErrorLogPath
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"
 

try
{

$SQLQuery = "WITH [Waits] AS
 (SELECT
 [wait_type],
 [wait_time_ms] / 1000.0 AS [WaitS],
 ([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
 [signal_wait_time_ms] / 1000.0 AS [SignalS],
 [waiting_tasks_count] AS [WaitCount],
 100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
 ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
 FROM sys.dm_os_wait_stats
 WHERE [wait_type] NOT IN (
 N'BROKER_EVENTHANDLER', N'BROKER_RECEIVE_WAITFOR',
 N'BROKER_TASK_STOP', N'BROKER_TO_FLUSH',
 N'BROKER_TRANSMITTER', N'CHECKPOINT_QUEUE',
 N'CHKPT', N'CLR_AUTO_EVENT',
 N'CLR_MANUAL_EVENT', N'CLR_SEMAPHORE',
 N'DBMIRROR_DBM_EVENT', N'DBMIRROR_EVENTS_QUEUE',
 N'DBMIRROR_WORKER_QUEUE', N'DBMIRRORING_CMD',
 N'DIRTY_PAGE_POLL', N'DISPATCHER_QUEUE_SEMAPHORE',
 N'EXECSYNC', N'FSAGENT',
 N'FT_IFTS_SCHEDULER_IDLE_WAIT', N'FT_IFTSHC_MUTEX',
 N'HADR_CLUSAPI_CALL', N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
 N'HADR_LOGCAPTURE_WAIT', N'HADR_NOTIFICATION_DEQUEUE',
 N'HADR_TIMER_TASK', N'HADR_WORK_QUEUE',
 N'KSOURCE_WAKEUP', N'LAZYWRITER_SLEEP',
 N'LOGMGR_QUEUE', N'ONDEMAND_TASK_QUEUE',
 N'PWAIT_ALL_COMPONENTS_INITIALIZED',
 N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
 N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
 N'REQUEST_FOR_DEADLOCK_SEARCH', N'RESOURCE_QUEUE',
 N'SERVER_IDLE_CHECK', N'SLEEP_BPOOL_FLUSH',
 N'SLEEP_DBSTARTUP', N'SLEEP_DCOMSTARTUP',
 N'SLEEP_MASTERDBREADY', N'SLEEP_MASTERMDREADY',
 N'SLEEP_MASTERUPGRADED', N'SLEEP_MSDBSTARTUP',
 N'SLEEP_SYSTEMTASK', N'SLEEP_TASK',
 N'SLEEP_TEMPDBSTARTUP', N'SNI_HTTP_ACCEPT',
 N'SP_SERVER_DIAGNOSTICS_SLEEP', N'SQLTRACE_BUFFER_FLUSH',
 N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
 N'SQLTRACE_WAIT_ENTRIES', N'WAIT_FOR_RESULTS',
 N'WAITFOR', N'WAITFOR_TASKSHUTDOWN',
 N'WAIT_XTP_HOST_WAIT', N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
 N'WAIT_XTP_CKPT_CLOSE', N'XE_DISPATCHER_JOIN',
 N'XE_DISPATCHER_WAIT', N'XE_TIMER_EVENT')
 AND [waiting_tasks_count] > 0
 )
SELECT TOP 5
 MAX ([W1].[wait_type]) AS [WaitType],
 CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
 CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
 CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
 MAX ([W1].[WaitCount]) AS [WaitCount],
 CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage]
FROM [Waits] AS [W1]
INNER JOIN [Waits] AS [W2]
 ON [W2].[RowNum] <= [W1].[RowNum]
GROUP BY [W1].[RowNum]
HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95; -- percentage threshold
GO
"
 
 
 if ($choice -eq 'W')
 
 { Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server | Format-Table -AutoSize }
 
 if ($choice -eq 'S')
 
 { Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server -Username $Username -Password $password | Format-Table -AutoSize }
 
 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"


try
{
 
$SQLQuery = "SELECT distinct olm.[name], olm.[file_version]
 
 FROM sys.dm_os_virtual_address_dump ova
 
 INNER JOIN sys.dm_os_loaded_modules olm
 
 ON olm.base_address = ova.region_allocation_base_address
 
 where name like '%SOPHO%'
 
 ORDER BY name
"
 
 
 if ($choice -eq 'W')
 
 { $output = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server | Format-Table -AutoSize }
 
 if ($choice -eq 'S')
 
 { $output = Invoke-Sqlcmd -Query $SQLQuery -ServerInstance $server -Username $Username -Password $password }
 
if ($output.length -eq 0)
{Write-Host "No Sophos DLL's loaded into SQL server address space" }
else
{ $output}
 
 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"
 
 try
 {

 $Server.EnumActiveGlobalTraceFlags()
 
 "`n"
 
 $server.JobServer.Jobs | Select Name, ownerloginname, IsEnabled, LastRunOutcome, LastRunDate | Format-Table -AutoSize

 }

 catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }
 
 "`n"
  
 
Write-Host "-----------------------------------Database Level Settings --------------------------" -BackgroundColor Red
 
"`n"

 
$Dbcount = $server.Databases.Count
$Dbcount = $Dbcount - 4
 
Write-Host "Number of User Databases :" $Dbcount
 
"`n"
 
try
{

$result = @()

foreach($db in $server.Databases)
{
   
  $item = $null
 
  
  foreach ($dbfile in $db.FileGroups.files)
 {

 $dbfilesize=[math]::floor($dbfile.Size/1024) #Convert to MB

 if ($dbfile.growthtype -eq "KB")
 {
 $dbfilegrowth=[math]::floor($dbfile.growth/1024) #Convert to MB if the type is KB and not Percent
 $dbgrowthtype = "MB"
 }
 else
 {
 $dbfilegrowth = $dbfile.growth
 $dbgrowthtype = "Percent"
 }
 
 

  $hash = @{

  "DBname" = $db.name

  "FileName" = $dbfile.filename

  "SizeinMB"  = $dbfilesize 

  "AutoGrowth" = $dbfilegrowth, $dbgrowthtype -join " "

 }
 
 $item = New-Object PSObject -Property $hash
  
  $result += $item 

 }

 foreach ($dblogfile in $db.logfiles)
 {
 
  
 $dblogfilesize = [math]::floor($dblogfile.size/1024) #Convert to MB
 
 if ($dblogfile.growthtype -eq "KB")
 {
 $dblogfilegrowth=[math]::floor($dblogfile.growth/1024) #Convert to MB if the type is KB and not Percent
 $dbgrowthtype = "MB"
 }
 else
  
 {
 $dblogfilegrowth=$dblogfile.growth
 $dbgrowthtype = "Percent"
 }
 
 
 
  $hash = @{

  "DBname" = $db.name

  "FileName" = $dblogfile.filename

  "SizeinMB"  = $dblogfilesize 

 "AutoGrowth" = $dblogfilegrowth, $dbgrowthtype -join " "

 }
 
 $item = New-Object PSObject -Property $hash
  
  $result += $item
 
 }

 }

 $result | select DBname, FileName, SizeinMB, AutoGrowth | Format-Table -AutoSize
 
"`n"

}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }


try 
{
 
$result = @()
foreach($db in $server.Databases | Where-Object {$_.id -gt 4})
{
 $item = $null
  
 $hash = @{
 "DBName" = $db.Name
 "Owner" = $db.Owner
 "PageVerify" = $db.PageVerify
 "CompatibilityLevel" = $db.CompatibilityLevel
 "AutoClose" = $db.AutoClose
 "AutoShrink" = $db.AutoShrink
  
 }
$item = New-Object PSObject -Property $hash
$result += $item
 
}
 
$result | select DBName, Owner, PageVerify, CompatibilityLevel, AutoClose, AutoShrink | Format-Table -AutoSize
 
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

try
{
 
$result = @()
foreach($db in $server.Databases | Where-Object {$_.id -gt 4})
{
 $item = $null
  
 $hash = @{
 "name" = $db.Name
 "DBStatus" = $db.Status
 "MirroringEnabled" = $db.IsMirroringEnabled
 "ReplicationEnabled" = $db.ReplicationOptions
 "EncryptionEnabled" = $db.EncryptionEnabled
 
 
 }
$item = New-Object PSObject -Property $hash
$result += $item
 
}
 
$result | Select name, DBStatus, MirroringEnabled, ReplicationEnabled, EncryptionEnabled | Format-Table -AutoSize

}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }
 
try
{ 
 
$result = @()
foreach($db in $server.Databases)
{
 $item = $null
  
 $hash = @{
 "name" = $db.name
 "lastfullbackup"= $db.LastBackupDate
 #"lastdiffbackup"= $db.LastDifferentialBackupDate
 "lastlogbackup" = $db.LastLogBackupDate
 "RecoveryModel" = $db.RecoveryModel
 "LogReuseWaitStatus" = $db.LogReuseWaitStatus
 "VLFCount" = $db.ExecuteWithResults("DBCC LOGINFO").Tables[0].rows.count
 
 }
$item = New-Object PSObject -Property $hash
$result += $item
 
}
 
$result | Select name, RecoveryModel, LogReuseWaitstatus, lastfullbackup,lastlogbackup, VLFcount | Format-Table -AutoSize
 
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }
 
"`n"
 

try 
{
 

$result = @()
foreach($db in $server.Databases)
{
 $item = $null
  
 $lastDBCC_CHECKDB=$db.ExecuteWithResults("DBCC DBINFO () WITH TABLERESULTS").Tables[0] | where {$_.Field.ToString() -eq "dbi_dbccLastKnownGood"} | Select $db.Name, Value

 $hash = @{

 "Name" =  $db.Name
 "LastIntegrityCheck" = $lastDBCC_CHECKDB.Value

 }
$item = New-Object PSObject -Property $hash
$result += $item
 
}
 
$result | Select name, LastIntegrityCheck | Format-Table -AutoSize
}

catch [Exception] {
 Write-Error $Error[0]
 $err = $_.Exception
 while ( $err.InnerException ) {
 $err = $err.InnerException
 Write-Output $err.Message
 }
 }

"`n"
 
 
}
 
 
#Windows Authentication
if($choice -eq 'W')
{
 #import SQL Server module
 #Import-Module SQLPS -DisableNameChecking -WarningAction SilentlyContinue
 #[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
 
 Try{Import-Module SQLPS -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop}
 
 Catch
 {
 
 Write-Host "Error SQL PS not found"
 Write-Host "Loading SMO Assemblies"
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
  Add-PSSnapin SqlServerCmdletSnapin100
  Add-PSSnapin SqlServerProviderSnapin100
 }
  
 $servername = $env:COMPUTERNAME
 $server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $instanceName
 "`n"
 "`n"
 "`n"
 Write-Host -Object "
   _____                            _____            _              
  / ____|                          |  __ \          (_)             
 | (___   ___ _ ____   _____ _ __  | |__) |_____   ___  _____      __
  \___ \ / _ \ '__\ \ / / _ \ '__| |  _  // _ \ \ / / |/ _ \ \ /\ / /
  ____) |  __/ |   \ V /  __/ |    | | \ \  __/\ V /| |  __/\ V  V /
 |_____/ \___|_|    \_/ \___|_|    |_|  \_\___| \_/ |_|\___| \_/\_/ 
  
                               " -ForegroundColor Magenta
 $starttime = Get-Date
 write-host "Script Start Time: "$starttime -ForegroundColor Red
 "`n"
 Write-Host "Attempting to connect to SQL Server Instance.." -ForegroundColor Green
 Write-Host "Logged in as $($server.ConnectionContext.TrueLogin)"-ForegroundColor Green
 
 try { $server.ConnectionContext.Connect() } catch { throw "Can't connect to $servername or access denied. Quitting." }
 Write-Host "Connection succeeded." -ForegroundColor Green
 ServerReview
 "`n"
 $Stoptime = Get-Date
 Write-host "Script Stop Time: "$Stoptime -ForegroundColor Red
 "`n"
 $server.ConnectionContext.Disconnect()
 
 
}
 
 
##SQL authentication
 
if ($choice -eq 'S')
{
 
 #import SQL Server module
 #Import-Module SQLPS -DisableNameChecking -WarningAction SilentlyContinue
 #[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
 
 Try{Import-Module SQLPS -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop}
 
 Catch
 {
 
 Write-Host "Error SQL PS not found"
 Write-Host "Loading SMO Assemblies"
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
 Add-PSSnapin SqlServerCmdletSnapin100
  Add-PSSnapin SqlServerProviderSnapin100
 }
  
 $servername = $env:COMPUTERNAME
 $server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $instanceName
 "`n"
 "`n"
 "`n"
 Write-Host -Object "
   _____                            _____            _              
  / ____|                          |  __ \          (_)             
 | (___   ___ _ ____   _____ _ __  | |__) |_____   ___  _____      __
  \___ \ / _ \ '__\ \ / / _ \ '__| |  _  // _ \ \ / / |/ _ \ \ /\ / /
  ____) |  __/ |   \ V /  __/ |    | | \ \  __/\ V /| |  __/\ V  V /
 |_____/ \___|_|    \_/ \___|_|    |_|  \_\___| \_/ |_|\___| \_/\_/ 
                                                                   
                                                                   " -ForegroundColor Magenta
                                                                    
 $starttime = Get-Date
 write-host "Script Start Time: "$starttime -ForegroundColor Red
 "`n"
 Write-Host "Attempting to connect to SQL Server Instance.." -ForegroundColor Green
  
  
 $message = "Enter the SQL Login credentials for the SQL Server, $($servername.ToUpper())";
 $server.ConnectionContext.LoginSecure = $false
 $sqllogin = Get-Credential -Message $message
 $Username = $sqllogin.username
 $server.ConnectionContext.set_Login($sqllogin.username)
 $password = $sqllogin.GetNetworkCredential().Password
 $server.ConnectionContext.set_SecurePassword($sqllogin.Password)
 Write-Host "Logged in as $($server.ConnectionContext.TrueLogin)" -ForegroundColor Green
 
 try { $server.ConnectionContext.Connect() } catch { throw "Can't connect to $servername or access denied. Quitting." }
 Write-Host "Connection succeeded." -ForegroundColor Green
 ServerReview
 "`n"
 $Stoptime = Get-Date
 Write-host "Script Stop Time: "$Stoptime -ForegroundColor Red
 "`n"
 $server.ConnectionContext.Disconnect()
 
}