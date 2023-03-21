
# AgentJobScripterFromDB
# Version 1.2 - 20210913
# By David Speight
# This will pull the job script stored in the database and create a single sql text file for each one.


[CmdletBinding()]
param(
	[string]$srv='MySqlRdsServer01.MyDomainName.com',
	[string]$destdb='Maintenance',
    [string]$basePath='D:\RECOVERY\MySqlRdsServer01\jobs',
    [string]$User='MyUserNAme',
    [string]$Pwd='MyPassword'

	)

[string]$oJobName=''
[string]$oJobScript=''
[string]$oJobPath=''

Import-Module sqlps
$SQLquery='select A.job_name, A.Job_Script
from [dbo].[AgentJobSnapshot] A
inner join (
			select job_name, MAX(date_scripted) AS date_scripted
			from [dbo].[AgentJobSnapshot] 
			GROUP BY job_name) as V 
			on A. job_name = v.Job_Name
where a.date_scripted = V.date_scripted
order by 1;'
$result=invoke-sqlcmd -query $SQLquery -serverinstance $srv -database $destdb -MaxCharLength 40000  -Username $User -Password $Pwd

forEach ($element in $result)
{
    $oJobName=$element.job_name.Replace(':','--')
    $oJobPath=$basePath + '\{0}.sql' -f $oJobName

    New-Item $oJobPath -Force
    Set-Content $oJobPath $element.Job_Script

    $element.job_name
}