
DROP PROC IF EXISTS dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE]
GO

CREATE PROC dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE]
(
		@OnlineSqlServerName	sysname
	,	@OnlineSqlDataBaseName	sysname
	,	@DEAL_TYPE	INT		 = 1
	,	@DEAL_NUM	INT		 = 1
	,	@TAX_CODE	INT		 = 1
	,	@STD_CODE	INT		 = 1
	,	@OPEN_DATE	DATETIME = 0
	,	@PREF_CODE	INT OUT
)
AS 
BEGIN 
	declare @LogTraceInfo int = 1,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate();
	;
	declare @Msg nvarchar(max) = N'', @Rows int = 0, @Err int = 0, @Ret int = 0, @Sql1 nvarchar(4000) = N''
	;

	/************************************************************************************************************/
	/* 1. Log Begining of Procedure execution */
	if @LogBegEndProc = 1 
	begin	
		select @Sql1 = 'dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE] @OnlineSqlServerName ='+@OnlineSqlServerName
					+ N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
					+ N', @DEAL_TYPE = ' + STR(@DEAL_TYPE,LEN(@DEAL_TYPE),0)
					+ N', @DEAL_NUM  = ' + STR(@DEAL_NUM,LEN(@DEAL_NUM),0)
					+ N', @TAX_CODE  = ' + STR(@TAX_CODE,LEN(@TAX_CODE),0)
					+ N', @STD_CODE  = ' + STR(@STD_CODE,LEN(@STD_CODE),0)
					+ N', @OPEN_DATE = ' + CONVERT(VARCHAR(10), @OPEN_DATE, 121)
			,  @Msg =  '*** Begin Execute Proc ***: dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE]'
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
	end

	/************************************************************************************************************/
	/* 2. Prepare Sql Server full database name */
	IF LEN(@OnlineSqlServerName) > 1 AND LEFT(RTRIM(@OnlineSqlServerName),1) <> N'['
		SELECT @OnlineSqlServerName = QUOTENAME(@OnlineSqlServerName)

	IF LEN(@OnlineSqlDataBaseName) > 1 AND LEFT(RTRIM(@OnlineSqlDataBaseName),1) <> N'['
		SELECT @OnlineSqlDataBaseName = QUOTENAME(@OnlineSqlDataBaseName)	

	declare @SqlFullDBName sysname = @OnlineSqlServerName +'.'+@OnlineSqlDataBaseName
	;
	/************************************************************************************************************/
	/* 3. Load Preferencial code from OnlineDB */


	SELECT @Sql1 = N'
	DECLARE	@DEAL_TYPE	INT		 = '+STR(@DEAL_TYPE,LEN(@DEAL_TYPE),0)+'
		,	@DEAL_NUM	INT		 = '+STR(@DEAL_NUM,LEN(@DEAL_NUM),0)+'
		,	@TAX_CODE	INT		 = '+STR(@TAX_CODE,LEN(@TAX_CODE),0)+'
		,	@STD_CODE	INT		 = '+STR(@STD_CODE,LEN(@STD_CODE),0)+'
		,	@OPEN_DATE	DATETIME = '''+CONVERT(VARCHAR(10), @OPEN_DATE, 121)+'''
	;
	DECLARE @DATE_ACT				 DATETIME = GETDATE() /* Дата на действието предизвикващо таксуване */
		,	@PREF_CODE_OUT			 INT = 0
		,	@STS_BIT_PREF_INDIVIDUAL INT = dbo.setbit( cast(0 as binary(4)), 12, 1)
		,	@STS_BIT_PREF_CUSTOMER	 INT = dbo.setbit( cast(0 as binary(4)), 13, 1)
	;
	SELECT TOP (1) @PREF_CODE_OUT = [PT].[CODE]
	FROM '+@SqlFullDBName+'.dbo.[PREFERENCIAL_TAXES] [PT] WITH(NOLOCK)
	INNER JOIN '+@SqlFullDBName+'.dbo.[PREFERENCIAL_EVENTS_TAXES] [ET] WITH(NOLOCK)
		ON	[PT].[CODE] = [ET].[PREFERENCE_CODE]
	INNER JOIN '+@SqlFullDBName+'.dbo.[PREFERENCIAL_TAXES_TO_DEALS] [TD] WITH(NOLOCK)
		ON	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
		AND [PT].[PREFERENCE_STATUS] = 1 /* Действаща преференция */
		OR
		(	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
			AND [PT].[PREFERENCE_STATUS] = 2 /* Преференция с изтекъл срок на валидност */
			AND @DATE_ACT BETWEEN [PT].[DATE_VALID_FROM] AND [PT].[DATE_VALID_TO]
		)
	WHERE
		(	([PT].[STATUS] & @STS_BIT_PREF_INDIVIDUAL) = @STS_BIT_PREF_INDIVIDUAL
			OR ([PT].[STATUS] & @STS_BIT_PREF_CUSTOMER) = @STS_BIT_PREF_CUSTOMER
		)
		AND [ET].[TAX_CODE]	 = @TAX_CODE
		AND [TD].[DEAL_TYPE] = @DEAL_TYPE
		AND [TD].[DEAL_NUM]  = @DEAL_NUM
		AND CAST( [PT].[DATE_VALID_FROM] AS DATE ) <= @DATE_ACT /* Провераваме дали действието е извършено в */
		AND CAST( [PT].[DATE_VALID_TO]   AS DATE ) >= @DATE_ACT /* периода на валидност на промоцията */
		AND
		(	@OPEN_DATE <= 0
			OR
			(	( [PT].[DATE_OPEN_FROM] <= 0 OR [PT].[DATE_OPEN_FROM] <= @OPEN_DATE )
			AND ( [PT].[DATE_OPEN_TO]   <= 0 OR [PT].[DATE_OPEN_TO]   >= @OPEN_DATE )
			)
		)
	ORDER BY
		(	CASE WHEN ([PT].[STATUS] & @STS_BIT_PREF_INDIVIDUAL) = @STS_BIT_PREF_INDIVIDUAL
					THEN 1
				WHEN  ([PT].[STATUS] & @STS_BIT_PREF_CUSTOMER)   = @STS_BIT_PREF_CUSTOMER
					THEN 2
				ELSE 3 END
		)
	;
	IF @PREF_CODE_OUT <= 0 AND @STD_CODE > 0
	BEGIN
		/* Търсим по код на стандартен договор */
		SELECT TOP (1) @PREF_CODE_OUT = [PT].[CODE]
		FROM '+@SqlFullDBName+'.dbo.[PREFERENCIAL_TAXES] [PT] WITH(NOLOCK)
		INNER JOIN '+@SqlFullDBName+'.dbo.[PREFERENCIAL_EVENTS_TAXES] [ET] WITH(NOLOCK)
			ON	[PT].[CODE] = [ET].[PREFERENCE_CODE]
		INNER JOIN '+@SqlFullDBName+'.dbo.[PREFERENCIAL_TAXES_TO_STD_DEALS] [TD] WITH(NOLOCK)
			ON	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
			AND [PT].[PREFERENCE_STATUS] = 1						/* Действаща преференция */
			OR 
			(	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
				AND [PT].[PREFERENCE_STATUS] = 2					/* Преференция с изтекъл срок на валидност */
				AND @DATE_ACT BETWEEN [PT].[DATE_VALID_FROM] AND [PT].[DATE_VALID_TO]
			)
		WHERE	[ET].[TAX_CODE]			= @TAX_CODE
			AND [TD].[DEAL_TYPE]		= @DEAL_TYPE
			AND [TD].[STD_DOG_CODE]		= @STD_CODE
			AND CAST( [PT].[DATE_VALID_FROM] AS DATE ) <= @DATE_ACT	 /* Провераваме дали действието е извършено в */
			AND CAST( [PT].[DATE_VALID_TO]   AS DATE ) >= @DATE_ACT	 /* периода на валидност на промоцията */
			AND ( @OPEN_DATE <= 0
				OR  (		([PT].[DATE_OPEN_FROM]	<= 0 OR [PT].[DATE_OPEN_FROM] <= @OPEN_DATE )
						AND ([PT].[DATE_OPEN_TO]	<= 0 OR [PT].[DATE_OPEN_TO]	  >= @OPEN_DATE )
					)
				)
	END

	SELECT @PREF_CODE_OUT as [PREFERENCE_CODE]
	';

	CREATE TABLE #TBL_PREF_CODE ( [PREF_CODE] INT )
	;

	begin try
		insert into [#TBL_PREF_CODE] ( [PREF_CODE] )
		exec @Ret = sp_executeSql @Sql1
		if @Ret <> 0 
		begin 
			exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, 'Error execute SQL'
			return 1;
		end
	end try
	begin CATCH 
		select  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
		return 2;
	end catch

	SELECT @PREF_CODE = IsNull([PREF_CODE],0) FROM [#TBL_PREF_CODE] WITH(NOLOCK)

	if @LogTraceInfo = 1
	begin
		select  @Msg = N'After: Load Deals Preferencial code rom OnLineDB, @PREF_CODE = '+ str(@PREF_CODE,len(@PREF_CODE),0)
	 	exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
	end

	/************************************************************************************************************/
	/* Log End Of Procedure */
	if @LogBegEndProc = 1
	begin 
		select @Sql1 = N'dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE] @OnlineSqlServerName ='+@OnlineSqlServerName
					+ N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
					+ N', @DEAL_TYPE = ' + STR(@DEAL_TYPE,LEN(@DEAL_TYPE),0)
					+ N', @DEAL_NUM  = ' + STR(@DEAL_NUM,LEN(@DEAL_NUM),0)
					+ N', @TAX_CODE  = ' + STR(@TAX_CODE,LEN(@TAX_CODE),0)
					+ N', @STD_CODE  = ' + STR(@STD_CODE,LEN(@STD_CODE),0)
					+ N', @OPEN_DATE = ' + CONVERT(VARCHAR(10), @OPEN_DATE, 121)
			,	@Msg = N'*** End Execute Proc ***: dbo.[SP_LOAD_ONLINE_PREFERENCIAL_CODE_BY_DEAL_AND_TAX_CODE], Duration: '
					+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate()) + N', DEAL_NUM: ' + str(@DEAL_NUM,len(@DEAL_NUM),0)
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
	end

END
GO
