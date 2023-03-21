# AwsRdsSqlAgentBackupScript
Create a database repository to store versions of your SQL Agent Jobs hosted on an AWS RDS instance. PowerShell not required.



From blog https://www.lovethesql.com

RDS SQL Agent Job Backup and Scripting

(Originally created September 9, 2020)

Help! My boss just told me we're moving our database to AWS RDS. What do I do with my PowerShell script that I use to back up the SQL Server Agent jobs?

I quickly found out (years ago) that RDS does not support a lot of my "borrowed" code, especially code that wants to do things using the msdb database. AWS has put some restrictions in place on the database. What do I do now?

Since I use RDS in a Multi-AZ enviornment, I've already run the command to synchronize my Agnet jobs between nodes. There are some instances where this AWS synchronization won't work (I have one server where this is the case.) So I've included version numbering in my code, so upon a failover, I can check and see what Agent Jobs are out of sync. I was going to automate this "checking on failover" with an alert job, but haven't had time to prioritize that part yet.

For my situation, I came up with a solution that scripts out the stored porocedures nightly and stores a copy in my MAINTENANCE database. I'd still like a text file version I can store for recovery purposes, so I also created a PowerShell script (that I can run on any server, with access) that will create a text file version.

A nice bonus with this project is that I also have a daily historic record of all my Agent Jobs, almost like a versioning thing. I've used this solution on SQL 2016, 2017 and 2019.

My solution includes 
1. A table to store the scripted versions.
2. Three stored procedures variations to script them out.
3. A PowerShell script to create text file versions.

Let's get started! First, I will create an AgentJobSnapshot table in my Maintenance (or any) database on my RDS Server to store the scripted items.

Next, I will write the Stored Procedure called Agent_Job_Script_Create_History.

The procedure does the following:
--Uses msdn..sysjobs_view to load a list of Job_Ids. (Limits to category 0,3,7,8)
--Loops through the list first grabbing the job header info, category, and description.
--Gets all the steps assocaited with the job in a sub-loop.
--Grabs the job schedule (yes it gets all of them.)
--Adds the Job footer.
--Bundles the above together and outputs a script for each job into a seperate row in the table created above. 

Lastly, I will create a PowerShell job called, AgentJobSCripterFromDB that will grab my most recent batch of jobs from the RDS server and output each one into a text file.

This assumes that you have the AWS CLI and SSqlps modules installed and configured on the server instance where this runs. I also setup a task to launch my script on a regular basis.


I have two other variations of the Stored Procedure that will simply output a single job or all of them, without writing to the snapshot table.

All of this code can be found at my git repository.











