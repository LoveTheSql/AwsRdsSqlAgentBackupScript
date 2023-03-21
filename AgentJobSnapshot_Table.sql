USE [Maintenance]
GO

/****** Object:  Table [dbo].[AgentJobSnapshot]    Script Date: 3/21/2023 9:45:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[AgentJobSnapshot](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[server_name] [nvarchar](150) NULL,
	[job_id] [uniqueidentifier] NULL,
	[job_name] [nvarchar](128) NULL,
	[enabled] [tinyint] NULL,
	[date_created] [datetime] NULL,
	[date_modified] [datetime] NULL,
	[date_scripted] [datetime] NULL,
	[version_number] [int] NULL,
	[Job_Script] [nvarchar](max) NULL,
 CONSTRAINT [PK_AgentJobSnapshot] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


