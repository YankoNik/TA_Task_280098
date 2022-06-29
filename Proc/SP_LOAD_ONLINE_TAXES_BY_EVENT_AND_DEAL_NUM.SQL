
/********************************************************************************************************/
/* Процедура за зареждане на Данни за Кореспонденция от OnLineDB по сделка по номер и кореспондираща партида */
DROP PROCEDURE IF EXISTS dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM]
GO

CREATE PROCEDURE dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM]
(
	@OnlineSqlServerName	sysname
,	@OnlineSqlDataBaseName	sysname
,   @ACCOUNT_DATE           datetime
,   @EVENT_TYPE             int
,	@DEAL_TYPE				int = 1
,	@DEAL_NUM			    int
)
as
begin

	declare @LogTraceInfo int = 0,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate();
	;
	declare @Msg nvarchar(max) = N'', @Rows int = 0, @Err int = 0, @Ret int = 0, @Sql1 nvarchar(4000) = N''
	;
	/************************************************************************************************************/
	/* 1.Log Begining of Procedure execution */
	if @LogBegEndProc = 1 
	begin	
		select @Sql1 = N'dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM] @OnlineSqlServerName ='+@OnlineSqlServerName
					+ N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
					+ N', @ACCOUNT_DATE = '''+convert(varchar(10),@ACCOUNT_DATE,121)+''''
                   	+ N', @EVENT_TYPE = '+str(@EVENT_TYPE,len(@EVENT_TYPE),0)
					+ N', @DEAL_TYPE = '+str(@DEAL_TYPE,len(@DEAL_TYPE),0)
                   	+ N', @DEAL_NUM = '+str(@DEAL_NUM,len(@DEAL_NUM),0)
			,  @Msg = N'*** Begin Execute Proc ***: dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM]'
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

	/************************************************************************************************************/
	/* 3. Load Tax coddes by EventType and DealNum from OlineDB */
    declare @AccDate varchar(32);

    if @ACCOUNT_DATE is null 
        set @ACCOUNT_DATE = GetDate();

    set @AccDate = convert(varchar(10),@ACCOUNT_DATE,121);

	select @Sql1 = N'declare @ACC_DATE datetime	= '''+convert(varchar(10),@AccDate,121)+'''
        ,	@EVENT_CODE int		= '+str(@EVENT_TYPE,len(@EVENT_TYPE),0)+'
        ,	@DEAL_TYPE int		= '+str(@DEAL_TYPE,len(@DEAL_TYPE),0)+'
        ,	@DEAL_NUM int		= '+str(@DEAL_NUM,len(@DEAL_NUM),0)+'
    ;
    with [E2D] as 
    (
        select top (1) * 
        from '+@SqlFullDBName+'.dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
        where [EVENT_CODE]	= @EVENT_CODE
            and [DEAL_TYPE] = @DEAL_TYPE
    )
    select	[TAX].[TAX_CODE]
        ,	[D].[TYPE]
        ,	[D].[VALUE]
    from '+@SqlFullDBName+'.dbo.[TAXES_TO_DEALS_RAZPL] [T2D] with(nolock)
    inner join [E2D] [E2D] with(nolock)
        on	[E2D].[DEAL_TYPE] = [T2D].[DEAL_TYPE]
        and [E2D].[EVENT_CODE] = @EVENT_CODE
    inner join '+@SqlFullDBName+'.dbo.[TAXES] [TAX] with(nolock)
        on	[T2D].[DEAL_TYPE]	= @DEAL_TYPE
        and [T2D].[DEAL_NUMBER] = @DEAL_NUM
        and [T2D].[TAX_CODE]	= [TAX].[TAX_CODE]
        and [TAX].[EVENT_TO_DEAL_CODE] = [E2D].[CODE]
        and @ACC_DATE between [TAX].[VALID_FROM] and [TAX].[VALID_TO]
    left outer join '+@SqlFullDBName+'.dbo.[TAXES_DESCRIPTORS] [D] with(nolock)
        on [TAX].[TAX_CODE] = [d].TAX_CODE
    order by [TAX].TAX_CODE, [D].[TYPE], [D].[VALUE]
    ';

	begin try
		exec @Ret = sp_executeSql @Sql1
	end try
	begin catch
		select  @Msg = dbo.FN_GET_EXCEPTION_INFO()
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
		return 2;
	end catch

	if @LogTraceInfo = 1 select @Sql1 as [LOAD_TAX_CODES_BY_DEAL_NUM];

	if @LogTraceInfo = 1 
	begin
		select  @Msg = N'After: Load Tax coddes by EventType and DealNum from OlineDB'
	 	exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
	end

	/************************************************************************************************************/
	/* Log End Of Procedure */
	if @LogBegEndProc = 1
	begin 
		select @Sql1 = N'dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM] @OnlineSqlServerName ='+@OnlineSqlServerName
					+ N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
					+ N', @ACCOUNT_DATE = '''+convert(varchar(10),@ACCOUNT_DATE,121)+''''
                   	+ N', @EVENT_TYPE = '+str(@EVENT_TYPE,len(@EVENT_TYPE),0)
					+ N', @DEAL_TYPE = '+str(@DEAL_TYPE,len(@DEAL_TYPE),0)
                   	+ N', @DEAL_NUM = '+str(@DEAL_NUM,len(@DEAL_NUM),0)
			,	@Msg = N'*** End Execute Proc ***: dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM], Duration: '
					+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate()) 
					+ N', @DEAL_TYPE: ' + +str(@DEAL_TYPE,len(@DEAL_TYPE),0)
					+ N', @DEAL_NUM: ' + +str(@DEAL_NUM,len(@DEAL_NUM),0)
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
	end

	return 0;
end 
go
