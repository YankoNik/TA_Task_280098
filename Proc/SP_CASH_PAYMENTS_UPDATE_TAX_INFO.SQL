
/********************************************************************************************************/
/* Процедура за актуализация информацията за такси по ID на тестови случай */
DROP PROCEDURE IF EXISTS dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO]
GO

CREATE PROCEDURE dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO]
(
	@TestCaseRowID	int
,	@UpdateMode		int = 0
)
AS 
begin
	declare @LogTraceInfo int = 0, @LogResultTable int = 0
		,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate()
	;

	declare @Msg nvarchar(max) = N'', @Rows int = 0, @Err int = 0, @Ret int = 0, @Sql nvarchar(4000) = N''
		,	@RowIdStr nvarchar(8) = STR(@TestCaseRowID,LEN(@TestCaseRowID),0)
	;

	/************************************************************************************************************/
	/* Log Begining of Procedure execution */
	if @LogBegEndProc = 1 exec dbo.SP_SYS_LOG_PROC @@PROCID, @RowIdStr, '*** Begin Execute Proc ***: dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO]'
	;

	/************************************************************************************************************/
	/* 1. Find TA Conditions: */
	select @Rows = @@ROWCOUNT, @Err = @@ERROR
	if not exists (select * from dbo.[VIEW_CASH_PAYMENTS_CONDITIONS] with(nolock) where [ROW_ID] = IsNull(@TestCaseRowID, -1))
	begin 
		select  @Msg = N'Error not found condition with [ROW_ID] :' + @RowIdStr
			,	@Sql = N'select * from dbo.[VIEW_CASH_PAYMENTS_CONDITIONS] with(nolock) where [ROW_ID] = IsNull('+@RowIdStr+', -1)'
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg;
		return -1;
	end
	
	declare @DB_TYPE sysname = N'AIR', @DEALS_CORR_TA_RowID int = 0
		,	@TYPE_ACTION varchar(128) = '',  @RUNNING_ORDER int = 0
	;

	select	@DB_TYPE = [TA_TYPE], @DEALS_CORR_TA_RowID = [CORS_ROW_ID]
		,	@TYPE_ACTION = [TYPE_ACTION], @RUNNING_ORDER = IsNull([RUNNING_ORDER],1)
	from dbo.[VIEW_CASH_PAYMENTS_CONDITIONS] with(nolock) where [ROW_ID] = IsNull(@TestCaseRowID, -1)
	;

	--if /* @TYPE_ACTION = 'CashPayment' and */ @RUNNING_ORDER > 1
	--begin 
	--	select  @Msg = N'Update cash payment with [ROW_ID] ' + @RowIdStr+' and  [RUNNING_ORDER] <> 1 not allowed.'
	--		,	@Sql = @TestCaseRowID
	--	;
	--	exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg;
	--	return 0;
	--end

	select @DB_TYPE = [DB_TYPE] from dbo.[TEST_AUTOMATION_TA_TYPE] with(nolock)
	where  [TA_TYPE] IN ( @DB_TYPE )
	;
	/************************************************************************************************************/
	/* 2.1. Get Datasources: */
	declare @OnlineSqlServerName sysname = N'',	@OnlineSqlDataBaseName sysname = N'', @DB_ALIAS sysname = N'VCS_OnlineDB'
	;

	exec @Ret = dbo.[SP_CASH_PAYMENTS_GET_DATASOURCE] @DB_TYPE, @DB_ALIAS, @OnlineSqlServerName out, @OnlineSqlDataBaseName out
	if @Ret <> 0
	begin
		select  @Msg = N'Error execute proc, Error code: '+str(@Ret,len(@Ret),0)
					+' ; Result: @OnlineSqlServerName = "'+@OnlineSqlServerName+'", @OnlineSqlDataBaseName = "'+@OnlineSqlDataBaseName+'"'
			,	@Sql = N'exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB] @DB_TYPE = '
					+ @DB_TYPE  +N', @DB_ALIAS = '+ @DB_ALIAS +N', @OnlineSqlServerName OUT, @OnlineSqlDataBaseName OUT'
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		return -2;
	end

	if @LogTraceInfo = 1 
	begin 
		select  @Msg = N'After: exec dbo.[SP_CASH_PAYMENTS_GET_DATASOURCE], @OnlineSqlServerName: ' +@OnlineSqlServerName+', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName+' '
			,	@Sql = N'exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB] @DB_TYPE = '
					+ @DB_TYPE  +N', @DB_ALIAS = '+ @DB_ALIAS +N', @OnlineSqlServerName OUT, @OnlineSqlDataBaseName OUT'
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	end
	
	/*********************************************************************************************************/
	/* 2.2. Get Account Date */
	declare @CurrAccDate datetime = 0,	@AccountDate sysname = N''
	;

	begin try
		exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB] @OnlineSqlServerName, @OnlineSqlDataBaseName, @CurrAccDate OUT
	end try
	begin catch 
		select  @Msg = dbo.FN_GET_EXCEPTION_INFO()
			,	@Sql = N'exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB] '+@OnlineSqlServerName+N', '+@OnlineSqlDataBaseName+N', @CurrAccDate OUT'
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		return -2;
	end catch 

	select @Rows = @@ROWCOUNT, @Err = @@ERROR, @AccountDate = ''''+convert( char(10), @CurrAccDate, 120)+'''';
	if @LogTraceInfo = 1 
	begin 
		select  @Msg = N'After: exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB], Online Accoun Date: ' +@AccountDate
			,	@Sql = N'exec dbo.[SP_SYS_GET_ACCOUNT_DATE_FROM_DB] '+@OnlineSqlServerName+N', '+@OnlineSqlDataBaseName+N', @CurrAccDate OUT'
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
	end

	/******************************************************************************************************/
	/* 3. Updare table dbo.[PREV_COMMON_TA] for Tax and Preferencial codes  */
	declare @WithUpdate int = IsNull(@UpdateMode,-1)
	;

	begin try
			exec dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO] @OnlineSqlServerName, @OnlineSqlDataBaseName, @CurrAccDate
				, @RowIdStr, @WithUpdate
	end try
	begin catch 

		select  @Msg = dbo.FN_GET_EXCEPTION_INFO()
			,	@Sql = N' exec dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO] @OnlineSqlServerName, @OnlineSqlDataBaseName, @CurrAccDate'
					 + N', @RowIdStr, @WithUpdate';

		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg

		return 7;
	end catch

	/************************************************************************************************************/
	/* Log End Of Procedure */
	if @LogBegEndProc = 1
	begin 
		select @Msg = 'Duration: '+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate()) + 
			 + ', TA Row ID: ' + @RowIdStr
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Msg, '*** End Execute Proc ***: dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO]'
	end
	
	return 0;		

end
go
