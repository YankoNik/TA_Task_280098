DROP PROCEDURE IF EXISTS DBO.[SP_CASH_PAYMENTS_INIT_TAXES]
GO

CREATE PROCEDURE DBO.[SP_CASH_PAYMENTS_INIT_TAXES]
(
	@DB_TYPE sysname
)
AS 
BEGIN

	DECLARE @LogTraceInfo int = 1,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate()
	;
	DECLARE @Msg nvarchar(max) = N'', @Sql nvarchar(4000) = N'', @Rows int = 0, @Err int = 0, @Ret int = 0 	
	;

	/************************************************************************************************************/
	/* 1. Log Begining of Procedure execution */
	IF @LogBegEndProc = 1 
    BEGIN
        SELECT  @MSG = N'*** Begin Execute Proc ***: dbo.[SP_CASH_PAYMENTS_INIT_TAXES]'
            ,   @Sql = N'dbo.[SP_CASH_PAYMENTS_INIT_TAXES] @DB_TYPE = '''+@DB_TYPE+''''
		;
       	EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
    END

	/************************************************************************************************************/
	/* 2. Prepare Sql Server full database name */
	DECLARE @OnlineSqlServerName sysname = N'',	@OnlineSqlDataBaseName	sysname = N''
    ;
    select  @OnlineSqlServerName    = [SERVER_INSTANCE_NAME]
        ,   @OnlineSqlDataBaseName  = [DATABASE_NAME]
    from dbo.[TEST_AUTOMATION_DATASOURCES] WITH(NOLOCK)
    WHERE [UNIQUE_ALIAS] = N'VCS_OnlineDB' AND [DB_TYPE] = @DB_TYPE
    ;

    IF Len(IsNull(@OnlineSqlServerName, '')) <= 1 OR Len(IsNull(@OnlineSqlDataBaseName, '')) <= 1
    BEGIN
        SELECT @Msg = 'Incorrect Online Sql server parameters, @OnlineSqlServerName: = '+@OnlineSqlServerName
            + ', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
        ;

        EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
        RETURN -1;
    END

	IF LEN(@OnlineSqlServerName) > 1 AND LEFT(RTRIM(@OnlineSqlServerName),1) <> N'['
		SELECT @OnlineSqlServerName = QUOTENAME(@OnlineSqlServerName)

	IF LEN(@OnlineSqlDataBaseName) > 1 AND LEFT(RTRIM(@OnlineSqlDataBaseName),1) <> N'['
		SELECT @OnlineSqlDataBaseName = QUOTENAME(@OnlineSqlDataBaseName)	

	DECLARE @SqlFullDBName sysname = @OnlineSqlServerName +'.'+@OnlineSqlDataBaseName
	;

	/*******************************************************************************************************/
	/* SQL 1 - Prepare */
	DROP TABLE IF EXISTS dbo.[#TAXES_INFO_TA]
	;

	SELECT TOP (0) * 
	INTO dbo.[#TAXES_INFO_TA]
	FROM dbo.[TAXES_INFO_TA]   WITH(NOLOCK)
	;

	/*******************************************************************************************************/
	/* SQL 1.1 */
    SELECT @Sql = N'
    INSERT INTO dbo.[#TAXES_INFO_TA] 
		( [TA_TABLE], [CODE], [TYPE], [NAME], [EVENT], [DEAL_TYPE], [ACUMULATIVE_TAX], [DDC]
		, [CURRENCY_FOR_CHARGING], [PREF_PERSENTAGE_BASE], [PREF_PLAN_BASE_ON_DAILY_TURNOVER] )
	SELECT	N''PREV_COMMON_TA''		AS [TA_TABLE]
		,	[TAX].[TAX_CODE]		AS [CODE]
		,	N''Tax''				AS [TYPE]
		,	[TAX].[TAX_NAME]		AS [NAME]
		,	[EVT].[EVENT_NAME]		AS [EVENT]
		,	[EVT2D].[DEAL_TYPE]		AS [DEAL_TYPE]
		,	[X].[ACUMULATIVE_TAX]	AS [ACUMULATIVE_TAX]
		,	[TAX].[DDS_TAX]			AS [DDC]
		,	2						AS [CURRENCY_FOR_CHARGING]
		,	NULL					AS [PREF_PERSENTAGE_BASE]
		,	NULL					AS [PREF_PLAN_BASE_ON_DAILY_TURNOVER]
	
	FROM '+@SqlFullDBName+'.dbo.TAXES [TAX] WITH (NOLOCK)
	INNER JOIN '+@SqlFullDBName+'.dbo.TAX_EVENTS_TO_DEALS AS [EVT2D] WITH (NOLOCK)
		ON [TAX].[EVENT_TO_DEAL_CODE] = [EVT2D].[CODE]
	INNER JOIN '+@SqlFullDBName+'.dbo.EVT_EVENTS AS [EVT] WITH (NOLOCK) 
		ON [EVT2D].[EVENT_CODE] = [EVT].[EVENT_TYPE]
	CROSS APPLY (
		SELECT 	CASE WHEN [EVT].[EVENT_TYPE] IN (1,5,201,366,367,368,369)
						THEN (DBO.CHECKBIT([TAX].[STATUS], 16) + 1) % 2
					ELSE 0
				END AS [ACUMULATIVE_TAX]
	) [X]
	WHERE [EVT2D].[DEAL_TYPE] = 1'
    ;

    BEGIN TRY
        EXEC @Ret = sp_executeSql @Sql
    END TRY
    BEGIN CATCH 
		SELECT  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		RETURN 1;
    END CATCH  

    IF @LogTraceInfo = 1 OR @Ret <> 0
	BEGIN
		SELECT  @Msg = N'After: Load Tax codes From OnLineDB (SQL 1), return code: ' + str(@Ret,len(@Ret),0)
            + ', inserted rows into #TAXES_INFO_TA : '+ str((select count(*) from dbo.[#TAXES_INFO_TA] with(nolock)),7,0)
	 	EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	END

	/*******************************************************************************************************/
	/* SQL 1.2 */
	INSERT INTO dbo.[TAXES_INFO_TA]
	( [TA_TABLE], [CODE], [TYPE], [NAME], [EVENT], [DEAL_TYPE], [ACUMULATIVE_TAX], [DDC]
	, [CURRENCY_FOR_CHARGING], [PREF_PERSENTAGE_BASE], [PREF_PLAN_BASE_ON_DAILY_TURNOVER] )
	SELECT	[S].[TA_TABLE]
		,	[S].[CODE]
		,	[S].[TYPE]
		,	[S].[NAME]
		,	[S].[EVENT]
		,	[S].[DEAL_TYPE]
		,	[S].[ACUMULATIVE_TAX]
		,	[S].[DDC]
		,	[S].[CURRENCY_FOR_CHARGING]
		,	[S].[PREF_PERSENTAGE_BASE]
		,	[S].[PREF_PLAN_BASE_ON_DAILY_TURNOVER] 
	FROM dbo.[#TAXES_INFO_TA] [S] WITH(NOLOCK)
	WHERE NOT EXISTS (
		SELECT * FROM dbo.[TAXES_INFO_TA] [D] WITH(NOLOCK)
		WHERE   [S].[CODE]      = [D].[CODE]
            AND [S].[TA_TABLE]  = [D].[TA_TABLE]
            AND [S].[TYPE]      = [D].[TYPE]
	);

	/*******************************************************************************************************/
	/* SQL 2 - Prepare */
	DROP TABLE IF EXISTS dbo.[#TAXES_INFO_COMMISSION_TA]
	;

	SELECT TOP (0) *
	INTO dbo.[#TAXES_INFO_COMMISSION_TA]
	FROM dbo.[TAXES_INFO_COMMISSION_TA]  WITH(NOLOCK)
	;

	/*******************************************************************************************************/
	/* SQL 2.1. */
    SELECT @Sql = N'
	INSERT INTO dbo.[#TAXES_INFO_COMMISSION_TA]
		( [TAX_CODE], [COMMISSION_CODE], [TYPE], [COMMISSION_ORDER], [CONSTANT_SUM], [PERCENTAGE], [IS_DEFAULT_CURRENCY], [CURRENCY]
		, [FROM_SUM], [UNTIL_SUM], [MIN_SUM], [MAX_SUM], [TAX_OVER_SUM], [INCLUDE_TAX_IN_MIN_MAX], [PREF_WITHOUT_DAILY_TURNOVER] )
	SELECT	DISTINCT 
			[REG].[CODE]					AS [TAX_CODE]
		,	[COMM].[COMMISSION_CODE]		AS [COMMISSION_CODE]
		,	N''Tax''						AS [TYPE]
		,	ROW_NUMBER() OVER(PARTITION BY [REG].[CODE], [CURR].[INI] ORDER BY [REG].[CODE], [CURR].[INI] )
											AS [COMMISSION_ORDER]
		,   [COMM].[CONSTTAX_SUM]			AS [CONSTANT_SUM]
		,	[COMM].[COMMISSION_PERCENT]		AS [PERCENTAGE]
		,   [ITEMS].[TYPE_COMMISSION]		AS [IS_DEFAULT_CURRENCY]
		,   [CURR].[INI]					AS [CURRENCY]

		,   CASE LAG([COMM].[COMMISSION_CODE], 1, 0) OVER (ORDER BY [REG].[CODE], [CURR].[INI], [COMM].[COMMISSION_CODE], [COMM].[UP_TO_SUM])
				WHEN [COMM].[COMMISSION_CODE]
				THEN 0.01 + LAG([COMM].[UP_TO_SUM], 1, 0) OVER (ORDER BY [REG].[CODE], [CURR].[INI], [COMM].[COMMISSION_CODE], [COMM].[UP_TO_SUM])
				ELSE 0 END 
											AS [FROM_SUM]
		,   [COMM].[UP_TO_SUM]				AS [UNTIL_SUM]
		,   [COMM].[MINIMUM_SUM]			AS [MIN_SUM]
		,   [COMM].[MAXIMUM_SUM]			AS [MAX_SUM]
		,   [COMM].[COMMISSION_FLAGS] & 1	AS [TAX_OVER_SUM]
		,   [COMM].[COMMISSION_FLAGS] & 4	AS [INCLUDE_TAX_IN_MIN_MAX]
		,   NULL							AS [PREF_WITHOUT_DAILY_TURNOVER]
	
	FROM (
		SELECT [TAX].[TAX_CODE] AS [CODE]
		FROM '+@SqlFullDBName+'.dbo.TAXES [TAX] WITH (NOLOCK)
		INNER JOIN '+@SqlFullDBName+'.dbo.TAX_EVENTS_TO_DEALS AS [EVT2D] WITH (NOLOCK)
			ON [TAX].[EVENT_TO_DEAL_CODE] = [EVT2D].[CODE]
		INNER JOIN '+@SqlFullDBName+'.dbo.EVT_EVENTS AS [EVT] WITH (NOLOCK) 
			ON [EVT2D].[EVENT_CODE] = [EVT].[EVENT_TYPE]
		WHERE [EVT2D].[DEAL_TYPE] = 1
	) AS [REG] 
	INNER JOIN    
	(    SELECT [TAX_CODE], MAX([DATE]) AS [DATE]
		FROM '+@SqlFullDBName+'.DBO.[TAX_PLAN_COMMISSIONS] WITH(NOLOCK)
		GROUP BY [TAX_CODE]
	) AS [PLN_DATE]
		ON [REG].[CODE] = [PLN_DATE].[TAX_CODE]
	INNER JOIN '+@SqlFullDBName+'.DBO.[TAX_PLAN_COMMISSIONS] AS [PLN] WITH(NOLOCK)
		ON	[PLN_DATE].[TAX_CODE] = [PLN].[TAX_CODE]
		AND [PLN_DATE].[DATE] = [PLN].[DATE]
	INNER JOIN '+@SqlFullDBName+'.DBO.[TAX_PLAN_COMMISSIONS_ITEMS] AS [ITEMS] WITH(NOLOCK)
		ON [PLN].[ID] = [ITEMS].[ID_PLAN]
	INNER JOIN '+@SqlFullDBName+'.DBO.[NM137] AS [COMM] WITH(NOLOCK)
		ON [ITEMS].[COMMISSION_GROUP_CODE] = [COMM].[COMMISSION_CODE]
	INNER JOIN '+@SqlFullDBName+'.DBO.[DT008] AS [CURR] WITH(NOLOCK)
		ON	[COMM].[CURRENCY] = [CURR].[CODE]
    ';

    BEGIN TRY
        EXEC @Ret = sp_executeSql @Sql
    END TRY
    BEGIN CATCH 
		SELECT  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		RETURN 2;
    END CATCH  

	IF @LogTraceInfo = 1 OR @Ret <> 0
	BEGIN
		SELECT  @Msg = N'After: Load Tax codes From OnLineDB (SQL 2), return code: ' + str(@Ret,len(@Ret),0)
            + ', inserted rows into #TAXES_INFO_COMMISSION_TA : '+ str((select count(*) from dbo.[#TAXES_INFO_COMMISSION_TA] with(nolock)),7,0)
	 	EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	END    

	/*******************************************************************************************************/
	/* SQL 2.2. */
	INSERT INTO dbo.[TAXES_INFO_COMMISSION_TA]
		( [TAX_CODE], [COMMISSION_CODE], [TYPE], [COMMISSION_ORDER], [CONSTANT_SUM], [PERCENTAGE], [IS_DEFAULT_CURRENCY], [CURRENCY]
		, [FROM_SUM], [UNTIL_SUM], [MIN_SUM], [MAX_SUM], [TAX_OVER_SUM], [INCLUDE_TAX_IN_MIN_MAX], [PREF_WITHOUT_DAILY_TURNOVER] )	
	SELECT	[S].[TAX_CODE]
		,	[S].[COMMISSION_CODE]
		,	[S].[TYPE]
		,	[S].[COMMISSION_ORDER]
		,	[S].[CONSTANT_SUM]
		,	[S].[PERCENTAGE]
		,	[S].[IS_DEFAULT_CURRENCY]
		,	[S].[CURRENCY]
		,	[S].[FROM_SUM]
		,	[S].[UNTIL_SUM]
		,	[S].[MIN_SUM]
		,	[S].[MAX_SUM]
		,	[S].[TAX_OVER_SUM]
		,	[S].[INCLUDE_TAX_IN_MIN_MAX]
		,	[S].[PREF_WITHOUT_DAILY_TURNOVER] 
	FROM dbo.[#TAXES_INFO_COMMISSION_TA] [S] WITH(NOLOCK)
	WHERE NOT EXISTS (
		SELECT * FROM dbo.[TAXES_INFO_COMMISSION_TA] [D] WITH(NOLOCK)
		WHERE	[S].[TAX_CODE]          = [D].[TAX_CODE]
            AND [S].[TYPE]              = [D].[TYPE]
			AND [S].[COMMISSION_CODE]   = [D].[COMMISSION_ORDER]
			AND [S].[COMMISSION_ORDER]  = [D].[COMMISSION_ORDER]
	);

	/*******************************************************************************************************/
	/* SQL 3 - Prepare */
	TRUNCATE TABLE dbo.[#TAXES_INFO_TA]
	;
	/*******************************************************************************************************/
	/* SQL 3.1 */
    SELECT @Sql = N'
	INSERT INTO dbo.[#TAXES_INFO_TA]
		( [TA_TABLE], [CODE], [TYPE], [NAME], [EVENT], [DEAL_TYPE], [ACUMULATIVE_TAX], [DDC]
		, [CURRENCY_FOR_CHARGING], [PREF_PERSENTAGE_BASE], [PREF_PLAN_BASE_ON_DAILY_TURNOVER] )
	SELECT DISTINCT N''PREV_COMMON_TA''		AS [TA_TABLE]
		,   [PREF].[CODE]					AS [CODE]
		,   N''Pref''						AS [TYPE]
		,   [PREF].[PREFERENCE_NAME]		AS [NAME]
		,   [EVT].[EVENT_NAME]				AS [EVENT]
		,   [PREF].[DEAL_TYPE]				AS [DEAL_TYPE]
		,   0								AS [ACUMULATIVE_TAX]
		,   0								AS [DDC]
		,	2								AS [CURRENCY_FOR_CHARGING]
		,	DBO.CHECKBIT(HDR.STATUS, 15)	AS [PREF_PERSENTAGE_BASE]
		,	DBO.CHECKBIT(HDR.STATUS, 16)	AS [PREF_PLAN_BASE_ON_DAILY_TURNOVER]
	FROM '+@SqlFullDBName+'.DBO.[PREFERENCIAL_TAXES] AS [PREF] WITH(NOLOCK)
	INNER JOIN '+@SqlFullDBName+'.DBO.[PREFERENCIAL_EVENTS_TAXES] AS [PREF_EVT] WITH(NOLOCK)
		ON [PREF].[CODE] = [PREF_EVT].[PREFERENCE_CODE]
	INNER JOIN '+@SqlFullDBName+'.DBO.[EVT_EVENTS] AS [EVT] WITH(NOLOCK)
		ON [PREF_EVT].[EVENT_CODE] = [EVT].[EVENT_TYPE]
	INNER JOIN '+@SqlFullDBName+'.DBO.[PREFERENCIAL_PLANS_HDR] AS [HDR] WITH(NOLOCK)
		ON [PREF_EVT].[PREF_PLAN_CODE] = [HDR].[CODE]
	WHERE	[PREF].[PREFERENCE_STATUS]	= 1
		AND [PREF].[DEAL_TYPE]			= 1
		AND [PREF].[DATE_VALID_TO]		>= GETDATE()
    ';

    BEGIN TRY
        EXEC @Ret = sp_executeSql @Sql
    END TRY
    BEGIN CATCH 
		SELECT  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		RETURN 3;
    END CATCH  

	IF @LogTraceInfo = 1 OR @Ret <> 0
	BEGIN
		SELECT  @Msg = N'After: Load Tax codes From OnLineDB (SQL 3), return code: ' + str(@Ret,len(@Ret),0)
            + ', inserted rows into #TAXES_INFO_TA : '+ str((select count(*) from dbo.[#TAXES_INFO_TA] with(nolock)),7,0)
	 	EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	END

	/*******************************************************************************************************/
	/* SQL 3.2 */
	INSERT INTO dbo.[TAXES_INFO_TA]
	( [TA_TABLE], [CODE], [TYPE], [NAME], [EVENT], [DEAL_TYPE], [ACUMULATIVE_TAX], [DDC]
	, [CURRENCY_FOR_CHARGING], [PREF_PERSENTAGE_BASE], [PREF_PLAN_BASE_ON_DAILY_TURNOVER] )
	SELECT	[S].[TA_TABLE]
		,	[S].[CODE]
		,	[S].[TYPE]
		,	[S].[NAME]
		,	[S].[EVENT]
		,	[S].[DEAL_TYPE]
		,	[S].[ACUMULATIVE_TAX]
		,	[S].[DDC]
		,	[S].[CURRENCY_FOR_CHARGING]
		,	[S].[PREF_PERSENTAGE_BASE]
		,	[S].[PREF_PLAN_BASE_ON_DAILY_TURNOVER] 
	FROM dbo.[#TAXES_INFO_TA] [S] WITH(NOLOCK)
	WHERE NOT EXISTS (
		SELECT * FROM dbo.[TAXES_INFO_TA] [D] WITH(NOLOCK)
		WHERE   [S].[CODE]      = [D].[CODE]
            AND [S].[TA_TABLE]  = [D].[TA_TABLE]
            AND [S].[TYPE]      = [D].[TYPE]
	);

	/**************************************************************************************************************/
	--SQL_4	- Prepare
	TRUNCATE TABLE dbo.[#TAXES_INFO_COMMISSION_TA]
	;

	/**************************************************************************************************************/
	--SQL_4.1.	- OK
    SELECT @Sql = N'
	INSERT INTO dbo.[#TAXES_INFO_COMMISSION_TA]
		( [TAX_CODE], [COMMISSION_CODE], [TYPE], [COMMISSION_ORDER], [CONSTANT_SUM], [PERCENTAGE], [IS_DEFAULT_CURRENCY], [CURRENCY]
		, [FROM_SUM], [UNTIL_SUM], [MIN_SUM], [MAX_SUM], [TAX_OVER_SUM], [INCLUDE_TAX_IN_MIN_MAX], [PREF_WITHOUT_DAILY_TURNOVER] )
	SELECT	[PREF_EVT].[PREFERENCE_CODE]
									AS [TAX_CODE]
		,	[DTL].[CODE]			AS [COMMISSION_CODE]
		,    N''Pref''				AS [TYPE]
		,   ROW_NUMBER() OVER(PARTITION BY [PREF_EVT].[PREFERENCE_CODE] ORDER BY [PREF_EVT].[PREFERENCE_CODE])
									AS [COMMISSION_ORDER]
		,   CASE [DTL].[PREFERENCE_TYPE] WHEN 1 THEN [DTL].[SUM_SOLID] ELSE -1 END
									AS [CONSTANT_SUM]
		,   CASE [DTL].[PREFERENCE_TYPE] WHEN 0 THEN [DTL].[PERCENT] ELSE -1 END
									AS [PERCENTAGE]
		,   1						AS [IS_DEFAULT_CURRENCY]
		,   ''X''					AS [CURRENCY]
		,   ([DTL].[SUM_FOR_TAX_OVER] + 0.01)
									AS [FROM_SUM]
		,   CASE LEAD([DTL].[PREFERENCE_CODE], 1, 0)
				OVER (ORDER BY [PREF_EVT].[PREFERENCE_CODE], [DTL].[CODE], [DTL].[SUM_FOR_TAX_OVER]) WHEN [DTL].[PREFERENCE_CODE] THEN LEAD([DTL].[SUM_FOR_TAX_OVER], 1, 0) 
					OVER (ORDER BY [PREF_EVT].[PREFERENCE_CODE], [DTL].[CODE], [DTL].[SUM_FOR_TAX_OVER]) ELSE 99999999999 END 
									AS [UNTIL_SUM]
		,   [DTL].[MIN_SUM]			AS [MIN_SUM]
		,   [DTL].[MAX_SUM]			AS [MAX_SUM]
		,   0						AS [TAX_OVER_SUM]
		,   0						AS [INCLUDE_TAX_IN_MIN_MAX]
		,   DBO.CHECKBIT([DTL].[STATUS], 16) AS [PREF_WITHOUT_DAILY_TURNOVER]
	FROM '+@SqlFullDBName+'.DBO.[PREFERENCIAL_TAXES] AS [PREF] WITH(NOLOCK)
	INNER JOIN '+@SqlFullDBName+'.DBO.[PREFERENCIAL_EVENTS_TAXES] AS [PREF_EVT] WITH(NOLOCK)
		ON [PREF].[CODE] = [PREF_EVT].[PREFERENCE_CODE]
	INNER JOIN '+@SqlFullDBName+'.DBO.PREFERENCIAL_PLANS_HDR AS [HDR] WITH(NOLOCK)
		ON [PREF_EVT].[PREF_PLAN_CODE] = [HDR].[CODE]
	INNER JOIN '+@SqlFullDBName+'.DBO.PREFERENCIAL_PLANS AS [DTL] WITH(NOLOCK)
		ON HDR.CODE = DTL.CODE_PREF_PLAN_HRD
	WHERE	[PREF_EVT].[TAX_CODE]		> 0
		AND [PREF].[PREFERENCE_STATUS]	= 1 
		AND [PREF].[DEAL_TYPE]			= 1
		AND [PREF].[DATE_VALID_TO]		>= GETDATE()
    ';

    BEGIN TRY
        exec @Ret = sp_executeSql @Sql
    END TRY
    BEGIN CATCH 
		SELECT  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		RETURN 4;
    END CATCH  

	IF @LogTraceInfo = 1 OR @Ret <> 0
	BEGIN
		SELECT  @Msg = N'After: Load Tax codes From OnLineDB (SQL 4), return code: ' + str(@Ret,len(@Ret),0)
            + ', inserted rows into #TAXES_INFO_COMMISSION_TA : '+ str((select count(*) from dbo.[#TAXES_INFO_COMMISSION_TA] with(nolock)),7,0)
	 	EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	END    

	/**************************************************************************************************************/
	--SQL_4.2.	- OK
	INSERT INTO dbo.[TAXES_INFO_COMMISSION_TA]
		( [TAX_CODE], [COMMISSION_CODE], [TYPE], [COMMISSION_ORDER], [CONSTANT_SUM], [PERCENTAGE], [IS_DEFAULT_CURRENCY], [CURRENCY]
		, [FROM_SUM], [UNTIL_SUM], [MIN_SUM], [MAX_SUM], [TAX_OVER_SUM], [INCLUDE_TAX_IN_MIN_MAX], [PREF_WITHOUT_DAILY_TURNOVER] )
	SELECT	[S].[TAX_CODE]
		,	[S].[COMMISSION_CODE]
		,	[S].[TYPE]
		,	[S].[COMMISSION_ORDER]
		,	[S].[CONSTANT_SUM]
		,	[S].[PERCENTAGE]
		,	[S].[IS_DEFAULT_CURRENCY]
		,	[S].[CURRENCY]
		,	[S].[FROM_SUM]
		,	[S].[UNTIL_SUM]
		,	[S].[MIN_SUM]
		,	[S].[MAX_SUM]
		,	[S].[TAX_OVER_SUM]
		,	[S].[INCLUDE_TAX_IN_MIN_MAX]
		,	[S].[PREF_WITHOUT_DAILY_TURNOVER] 
	FROM dbo.[#TAXES_INFO_COMMISSION_TA] [S] WITH(NOLOCK)
	WHERE NOT EXISTS (
		SELECT * FROM dbo.[TAXES_INFO_COMMISSION_TA] [D] WITH(NOLOCK)
		WHERE	[S].[TAX_CODE]          = [D].[TAX_CODE]
            AND [S].[TYPE]              = [D].[TYPE]
			AND [S].[COMMISSION_CODE]   = [D].[COMMISSION_ORDER]
			AND [S].[COMMISSION_ORDER]  = [D].[COMMISSION_ORDER]
	);

    /************************************************************************************************************/
	/* Log End Of Procedure */
	IF @LogBegEndProc = 1
	BEGIN
		SELECT	@Sql = N'dbo.[SP_CASH_PAYMENTS_INIT_TAXES] @DB_TYPE = '''+@DB_TYPE+''''
			,	@Msg = '*** End Execute Proc ***: dbo.[SP_CASH_PAYMENTS_INIT_TAXES], Duration: '+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate())
		;
		EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	END

    RETURN @Ret;
END
GO