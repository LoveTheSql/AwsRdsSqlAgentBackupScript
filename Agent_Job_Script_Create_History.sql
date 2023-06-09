USE [Maintenance]
GO
/****** Object:  StoredProcedure [dbo].[Agent_Job_Script_Create_History]  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David Speight
-- Create date: 20200909	Version 1.0
-- Description:	This will script out a ALL SQL Agent jobs within categories 0,3,7,8.
-- =============================================
ALTER  PROCEDURE [dbo].[Agent_Job_Script_Create_History]
AS
BEGIN

SET NOCOUNT ON;

DECLARE @ajCount int = 0;
DECLARE @ajLoopMax int;
DECLARE @aJobID uniqueidentifier;
-- Get list of jobs
DECLARE @ajList AS TABLE (	ID							int identity(1,1),
							Job_Id						uniqueidentifier
							);
INSERT INTO @ajList
(Job_Id)
select Job_Id
from  [msdb].[dbo].[sysjobs_view]
where category_id in (0,3,7,8)
ORDER BY name;

DECLARE @ajTable AS TABLE (	Job_Id						uniqueidentifier, 							
							Job_Name					nvarchar(128),
							enabled						tinyint,
							date_created				datetime,
							date_modified				datetime,
							date_scripted				datetime,							
							version_number				int,
							Job_Script					nvarchar(max)
							);

SELECT @ajLoopMax = MAX(ID) FROM @ajList;

DECLARE @sqlJobHeader				nvarchar(500);
DECLARE @sqlJobCategory				nvarchar(750);
DECLARE @sqlJobDescription			nvarchar(2000);
DECLARE @sqlJobStep					nvarchar(max);
DECLARE @sqlJobStartStep			nvarchar(100);
DECLARE @sqlJobSchedule				nvarchar(750);
DECLARE @sqlJobFooter				nvarchar(350);
DECLARE @sqlJobComplete				nvarchar(max);

DECLARE @enabled					tinyint;
DECLARE @description				nvarchar(512);
DECLARE @start_step_id				int;
DECLARE @category_id				int;
DECLARE @owner_sid					varbinary(85);
DECLARE @notify_level_eventlog		int;
DECLARE @notify_level_email			int;
DECLARE @notify_level_netsend		int;
DECLARE @notify_level_page			int;
DECLARE @notify_email_operator_id	int;
DECLARE @notify_netsend_operator_id	int;
DECLARE @notify_page_operator_id	int;
DECLARE @delete_level				int;
DECLARE @date_created				datetime;
DECLARE @date_modified				datetime;
DECLARE @version_number				int;
DECLARE @JobCategoryName			nvarchar(128);	-- This script only allows 0,3,7, or 8
DECLARE @owner_login_name			nvarchar(128);
DECLARE @job_id						uniqueidentifier;
DECLARE @name						nvarchar(128);

WHILE @ajCount < @ajLoopMax
BEGIN
	SELECT @ajCount = @ajCount + 1;
	SELECT @aJobID = job_id FROM @ajList WHERE ID = @ajCount;


					SELECT
							@job_id						=		job_id,
							@name						=		name,
							@enabled					=		enabled,
							@description				=		description,	
							@start_step_id				=		start_step_id,
							@category_id				=		category_id,
							@owner_sid					=		owner_sid,
							@notify_level_eventlog		=		notify_level_eventlog,
							@notify_level_email			=		notify_level_email,
							@notify_level_netsend		=		notify_level_netsend,
							@notify_level_page			=		notify_level_page,
							@notify_email_operator_id	=		notify_email_operator_id,
							@notify_netsend_operator_id	=		notify_netsend_operator_id,
							@notify_page_operator_id	=		notify_page_operator_id,
							@delete_level				=		delete_level,
							@date_created				=		date_created,
							@date_modified				=		date_modified,
							@version_number				=		version_number
					from  [msdb].[dbo].[sysjobs_view] where job_id = @aJobID;

					IF @job_id is null or @name is null
					BEGIN
						PRINT 'ERROR: Invalid parameter(s), job not found';
						RETURN;
					END;

					If @category_id NOT IN (0,3,7,8)
					BEGIN
						PRINT CONCAT('The category id ', CONVERT(varchar(12),@category_id), ' is not allowed in this script, so the job ', @name, ' has been ignored. ')
						RETURN;
					END
					ELSE
					BEGIN
						SELECT	@JobCategoryName		=		name
						FROM	[msdb]. [dbo].[syscategories]
						WHERE	category_id = @category_id;
					END;

					/****** Object:  Job HEADER ******/
					SELECT	@sqlJobHeader				=	CONCAT(
					'USE [msdb]
					GO

					/****** Object:  Job [',@name,']    Script Date: ',FORMAT (getdate(), 'M/d/yyyy h:mm:ss tt'),' ******/
					BEGIN TRANSACTION
					DECLARE @ReturnCode INT
					SELECT @ReturnCode = 0

					');


					/****** Object:  Job CATEGORY ******/
					SELECT	@sqlJobCategory			=	CONCAT(
					'
					/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: ',FORMAT (getdate(), 'M/d/yyyy h:mm:ss tt'),' ******/
					IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N''',@JobCategoryName,''' AND category_class=1)
					BEGIN
						EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N''JOB'', @type=N''LOCAL'', @name=N''',@JobCategoryName,'''
						IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					END'

					);


					/****** Object:  Job DESCRIPTION ******/
					SELECT @owner_login_name		=	name
					FROM [msdb].[sys].[syslogins]
					WHERE sid = @owner_sid;

					SELECT	@sqlJobDescription		=	CONCAT(
					'

					DECLARE @jobId BINARY(16)
					EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N''',@name,''', 
							@enabled=''',CONVERT(varchar(8),@enabled),''', 
							@notify_level_eventlog=''',CONVERT(varchar(8),@notify_level_eventlog),''', 
							@notify_level_email=''',CONVERT(varchar(8),@notify_level_email),''', 
							@notify_level_netsend=''',CONVERT(varchar(8),@notify_level_netsend),''', 
							@notify_level_page=''',CONVERT(varchar(8),@notify_level_page),''', 
							@delete_level=''',CONVERT(varchar(8),@delete_level),''', 
							@description=N''',@description,''', 
							@category_name=N''',@JobCategoryName,''', 
							@owner_login_name=N''',@owner_login_name,''', @job_id = @jobId OUTPUT
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					');



					/****** Object:  Job STEPS.   Multiple steps are possible.  ******/
					DECLARE @jCount int = 0;
					DECLARE @jLoopMax int;
					DECLARE @jTable AS TABLE (	ID							int identity(1,1),
												step_id						int, 							
												step_name					nvarchar(128),
												subsystem					nvarchar(40),
												command						nvarchar(max),
												flags						int,
												cmdexec_success_code		int,
												on_success_action			tinyint,
												on_success_step_id			int,
												on_fail_action				tinyint,
												on_fail_step_id				int,
												server						nvarchar(128),
												database_name				nvarchar(128),
												database_user_name			nvarchar(128),
												retry_attempts				int,
												retry_interval				int,
												os_run_priority				int,
												output_file_name			nvarchar(200),
												last_run_outcome			int,
												last_run_duration			int,
												last_run_retries			int,
												last_run_date				int,
												last_run_time				int,
												proxy_id					int
												);
					INSERT INTO @jTable		(	step_id, step_name, subsystem, command, flags, cmdexec_success_code, on_success_action, on_success_step_id, on_fail_action, on_fail_step_id, 
												server, database_name, database_user_name, retry_attempts, retry_interval, os_run_priority, 
												output_file_name, last_run_outcome,last_run_duration, last_run_retries, last_run_date, last_run_time, proxy_id)
					EXEC [msdb].[dbo].[sp_agent_get_jobstep] @job_id=@job_id, @is_system=0;

					UPDATE @jTable
					SET command = REPLACE(command, '''', '''''');

					SELECT	@jLoopMax			= 		MAX(ID),
							@jCount				=		(MIN(ID)-1)
					FROM @jTable;

					SELECT @sqlJobStep = '';

					WHILE @jCount < @jLoopMax
					BEGIN
						SELECT @jCount = @jCount + 1
						SELECT @sqlJobStep				=	@sqlJobStep + CONCAT(
					'
					/****** Object:  Step [',step_name,']    Script Date: ',FORMAT (getdate(), 'M/d/yyyy h:mm:ss tt'),' ******/
					EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N''',step_name,''', 
							@step_id=',step_id,', 
							@cmdexec_success_code=',cmdexec_success_code,', 
							@on_success_action=',on_success_action,', 
							@on_success_step_id=',on_success_step_id,', 
							@on_fail_action=',on_fail_action,', 
							@on_fail_step_id=',on_fail_step_id,', 
							@retry_attempts=',retry_attempts,', 
							@retry_interval=',retry_interval,', 
							@os_run_priority=',os_run_priority,', @subsystem=N''',subsystem,''', 
							@command=N''',command,''', 
							@database_name=N''',database_name,''', 
							@flags=',flags,'
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					')
						FROM	@jTable
						WHERE	ID = @jCount;

					END;


					/****** Object:  Job START STEP ******/
					SELECT @sqlJobStartStep			=	CONCAT(
					'
					EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = ',@start_step_id,'
					');


					/****** Object:  Job SCHEDULE. Multiple schedules are possible. ******/
					DECLARE @sLoopMax int;
					DECLARE @sCount int;
					DECLARE @sTable AS TABLE (	ID						int identity(1,1),
												schedule_id				int, 							
												schedule_name			nvarchar(128),
												enabled					int,
												freq_type				int,
												freq_interval			int,
												freq_subday_type		int,
												freq_subday_interval	int,
												freq_relative_interval	int,
												freq_recurrence_factor	int,
												active_start_date		int,
												active_end_date			int,
												active_start_time		int,
												active_end_time			int,
												date_created			datetime,
												schedule_description	nvarchar(128),
												next_run_date			int,
												next_run_time			int,
												schedule_uid			uniqueidentifier, 
												job_count				int
												)
					INSERT INTO @sTable		(	schedule_id, schedule_name,enabled,
												freq_type,freq_interval,freq_subday_type,freq_subday_interval,freq_relative_interval,freq_recurrence_factor,
												active_start_date,active_end_date,active_start_time,active_end_time,
												date_created,schedule_description,next_run_date,next_run_time,schedule_uid,job_count)
					EXEC msdb.dbo.sp_help_jobschedule @job_id = @job_id;

					SELECT	@sLoopMax				= 		MAX(ID),
							@sCount					=		(MIN(ID)-1)
					FROM @sTable;

					SELECT @sqlJobSchedule = '';

					WHILE @sCount < @sLoopMax
					BEGIN
						SELECT @sCount = @sCount + 1
						SELECT @sqlJobSchedule			=	@sqlJobSchedule + CONCAT(
					'
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N''',Schedule_name,''', 
							@enabled=',enabled,', 
							@freq_type=',freq_type,', 
							@freq_interval=',freq_interval,',
							@freq_subday_type=',freq_subday_type,', 
							@freq_subday_interval=',freq_subday_interval,', 
							@freq_relative_interval=',freq_relative_interval,', 
							@freq_recurrence_factor=',freq_recurrence_factor,', 
							@active_start_date=',active_start_date,',
							@active_end_date=',active_end_date,', 
							@active_start_time=',active_start_time,', 
							@active_end_time=',active_end_time,', 
							@schedule_uid=N''',Schedule_uid,'''
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					')
						FROM	@sTable
						WHERE	ID = @sCount;

					END;


					/****** Object:  Job FOOTER ******/
					SELECT @sqlJobFooter		=
					'
					EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)''
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
					COMMIT TRANSACTION
					GOTO EndSave
					QuitWithRollback:
						IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
					EndSave:
					GO
					';

					/****** OUTPUT: Job Script ******/
					SELECT	@sqlJobComplete		=		CONCAT(@sqlJobHeader, @sqlJobCategory,@sqlJobDescription,@sqlJobStep,@sqlJobStartStep,@sqlJobSchedule,@sqlJobFooter);

			INSERT INTO @ajTable
			(Job_Id, Job_Name, enabled, date_created, date_modified, date_scripted, version_number, Job_Script)
			SELECT @job_id, @name, @enabled, @date_created, @date_modified, getdate(), @version_number, @sqlJobComplete;

			SELECT	@sqlJobComplete='', @sqlJobHeader='', @sqlJobCategory='', @sqlJobDescription='', @sqlJobStep='', @sqlJobStartStep='', 
					@sqlJobSchedule='', @sqlJobFooter='', @job_id=null, @name=null, @date_created=null, @date_modified=null,
					@jCount=0, @jLoopMax=0, @sCount=0, @sLoopMax=0;

			DELETE FROM @jTable;
			DELETE FROM @sTable;
	END;

	INSERT INTO [dbo].[AgentJobSnapshot]
	([server_name], [job_id], [job_name], [enabled], [date_created], [date_modified], [date_scripted], [version_number], [Job_Script])
	SELECT
	@@Servername AS ServerName, [job_id], [job_name], [enabled], [date_created], [date_modified], [date_scripted], [version_number], [Job_Script]
	FROM @ajTable;

	SELECT @@Servername AS ServerName, [job_id], [job_name], [enabled], [date_created], [date_modified], [date_scripted], [version_number], [Job_Script]
	FROM @ajTable;


END

