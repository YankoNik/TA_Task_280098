
/**********************************************************************************************************/
/* Процедура за актуализация данните в на Таблица dbo.[PREV_COMMON_TA] за титуляра и Proxy-то*/
DROP PROCEDURE IF EXISTS dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO]
GO

CREATE PROCEDURE dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO]
(
	@OnlineSqlServerName	sysname
,	@OnlineSqlDataBaseName	sysname
,	@CurrAccountDate		datetime
,	@TestCaseRowID			nvarchar(16)
,	@WithUpdate				int = 0
)
AS 
begin

	declare @LogTraceInfo int = 1,	@LogBegEndProc int = 1,	@TimeBeg datetime = GetDate();
	;
	declare @Sql1 nvarchar(4000) = N'', @Msg nvarchar(max) = N'', @Ret int = 0, @TA_RowID int = cast(@TestCaseRowID as int)
	;
	/************************************************************************************************************/
	/* Log Begining of Procedure execution */
	if @LogBegEndProc = 1 
    begin
        select @Sql1 = N'dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO] @OnlineSqlServerName ='+@OnlineSqlServerName
                + N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
                + N', @CurrAccountDate = '''+convert(varchar(10),@CurrAccountDate,121)+''''
                + N', @TestCaseRowID = '+@TestCaseRowID
                + N', @WithUpdate = '+str(@WithUpdate,len(@WithUpdate),0)                
            ,  @Msg = N'*** Begin Execute Proc ***: dbo.[SP_LOAD_ONLINE_TAX_CODES_BY_DEAL_NUM]'
		;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
    end

   	/************************************************************************************************************/
	/* 1. Get Event type */
    declare @TAX_CODE               int = -1
        ,   @EVENT_TYPE             int = -1 /* Event type */
        ,   @UI_INOUT_TRANSFER      int = -1 /* 1 - In; 2 - Out; 3 - Inner*/
        ,   @BETWEEN_OWN_ACCOUNTS   int = -1 /* */
        ,   @UI_TYPE_ENTRANCE       int = -1 /* 7 - Тип на вноска; */
        ,   @DB_CLIENT_TYPE         int = -1 /* DT 300 */
        ,	@DEAL_TYPE  			int =  1
        ,	@UI_DEAL_NUM    		int = -1
    ;
    select  @EVENT_TYPE             = IsNull([PREV].[EVENT_TYPE],-1)
        ,   @UI_INOUT_TRANSFER      = IsNull([X].[UI_INOUT_TRANSFER],-1)
        ,   @BETWEEN_OWN_ACCOUNTS   = IsNull([PREV].[BETWEEN_OWN_ACCOUNTS],-1) 
        ,   @UI_TYPE_ENTRANCE       = IsNull([X].[UI_TYPE_ENTRANCE],-1)
        ,   @DB_CLIENT_TYPE         = IsNull([CUST].[DB_CLIENT_TYPE],-1)
        ,   @DEAL_TYPE              = 1 /*IsNull([DEAL].[DEAL_TYPE],-1)*/
        ,   @UI_DEAL_NUM            = IsNull([DEAL].[UI_DEAL_NUM],-1)
    from dbo.[PREV_COMMON_TA] [PREV] with(nolock)
	inner join dbo.[RAZPREG_TA] [DEAL] with(nolock)
		on [PREV].[REF_ID] = [DEAL].[ROW_ID]
	inner join dbo.[DT015_CUSTOMERS_ACTIONS_TA] [CUST] with(nolock)
		on [DEAL].[REF_ID] = [CUST].[ROW_ID]
	cross apply (
		select  case when ISNUMERIC( [UI_INOUT_TRANSFER] ) = 1
				    then cast( FLOOR([UI_INOUT_TRANSFER]) as int)
				    else NULL end as [UI_INOUT_TRANSFER]
            ,   case when ISNUMERIC( [UI_TYPE_ENTRANCE] ) = 1
				    then cast( FLOOR([UI_TYPE_ENTRANCE]) as int)
				    else NULL end as [UI_TYPE_ENTRANCE]
	) [X]
    where [PREV].[ROW_ID] = @TA_RowID
    ;

    if IsNull(@EVENT_TYPE,0) <= 0
    begin
		select @Msg = N'Incorrect Event type : ' + str(@EVENT_TYPE,len(@EVENT_TYPE),0) + N', TA ROW_ID : ' + @TestCaseRowID;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @TestCaseRowID, @Msg
		return -1;
    end

   	/************************************************************************************************************/
	/* 3. Get tax code from OnlineDb */
    create table #TBL_TAX_WITH_DESC
    (
        [TAX_CODE]      int 
    ,   [DESCR_TYPE]    int
    ,   [DESCR_VALUE]   int 
    );

    begin try
        insert into #TBL_TAX_WITH_DESC
        exec @Ret = dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM] @OnlineSqlServerName
            , @OnlineSqlDataBaseName, @CurrAccountDate, @EVENT_TYPE, @DEAL_TYPE, @UI_DEAL_NUM

        if @Ret <> 0
        begin 
            select  @Sql1 = N'exec dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM]'
                ,   @Msg = N'Error exec procedure dbo.[SP_LOAD_ONLINE_TAX_CODES_BY_DEAL_NUM], error code:'+str(@Ret,len(@Ret),0)
            ;
            exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
            return 1;
        end
    end try 
    begin catch
			select  @Msg = dbo.FN_GET_EXCEPTION_INFO() + N', TA ROW_ID : ' + @TestCaseRowID
                ,   @Sql1 = N'exec dbo.[SP_LOAD_ONLINE_TAXES_BY_EVENT_AND_DEAL_NUM]'
            ;
			exec dbo.SP_SYS_LOG_PROC @@PROCID, @Sql1, @Msg
			return 2;
    end catch

   	/************************************************************************************************************/
	/* 4. Get tax context description values */

    /* 5 - Тип на превода (NM329):
        1 - Вътрешнобанков превод; 
        2 - Междубанков получен кредитен превод;
        3 - Междубанков издаден кредитен превод; 
        4 - Превод между сметки на клиента; */
    declare @TypeTransfer int =
    (
         select case when @BETWEEN_OWN_ACCOUNTS = 1         then 4 /* 4 - Превод между сметки на клиента */
                     else case  when @UI_INOUT_TRANSFER = 1 then 2 /* 2 - Междубанков получен кредитен превод; */
                                when @UI_INOUT_TRANSFER = 2 then 3 /* 3 - Междубанков издаден кредитен превод; */
                                when @UI_INOUT_TRANSFER = 3 then 1 /* 1 - Вътрешнобанков превод; */
                           end 
                end                         
    );

    create table #contex_description_values
    (
        [DESCR_TYPE]	int 
    ,	[DESCR_VALUE]	int 
    );

    insert into #contex_description_values ([DESCR_TYPE], [DESCR_VALUE])
    values	( 8, 2 )                    /*  8 - Платежна система:  1 РИНГС; 2 БИСЕРА; 3 СЕБРА; 4 SWIFT; 6 БИСЕРА 7; 7 TARGET2; */
        ,   ( 9, 1 )                    /*  9 - Обслужваща система: 1 Основна система */
	    ,	(10, 2 )                    /* 10 - Контекст: 2 Сделка */
	    ,	(65, 1 )                    /* 65 - Описател на вид вноска: 1 Вноска към собствена сметка */
        ,   ( 5, @TypeTransfer )        /*  5 - Тип на превода (NM329): */
	    ,	( 7, @UI_TYPE_ENTRANCE )    /*  7 - Тип на вноска; */
	    ,	(40, @DB_CLIENT_TYPE )      /* 40 - Тип на клиента; */
    ;

   	/************************************************************************************************************/
	/* 5. Determine tax code */
    ;
    with [TDC] as
    (   /* 1. Групираме по описател */
        select [TAX_CODE], [DESCR_TYPE]
        from #TBL_TAX_WITH_DESC with(nolock)
        group by [TAX_CODE], [DESCR_TYPE]
    )
    , [MV] as
    (   /* 2. Подготвяме съвпаденията */
        select	[d].*
            ,	[c].[DESCR_VALUE] as [MATCH_VALUE]
        FROM #TBL_TAX_WITH_DESC [d] with(nolock)
        left outer join #contex_description_values [c] with(nolock)
            on	[d].[DESCR_TYPE] = [c].[DESCR_TYPE]
            and	[d].[DESCR_VALUE] = [c].[DESCR_VALUE]
        where [c].[DESCR_VALUE] is not null
    )
    , TAX_NOT_S AS
    (   /* 3. Всички такси който не са удоволетворяване */
        select distinct [T].[TAX_CODE]
        from [TDC] [T]
        left outer join [MV]
            on	[T].[TAX_CODE] = [MV].[TAX_CODE]
            and [T].[DESCR_TYPE] = [MV].[DESCR_TYPE]
        where [MV].[MATCH_VALUE] is null
    )
    select top (1) /* 4. Определяме код на таксата */ 
        @TAX_CODE = [T].[TAX_CODE]
    from [TDC] [T]
    where [T].[TAX_CODE] not in
    ( 
        select [TAX_CODE] 
        from [TAX_NOT_S]
    );

    if IsNull(@TAX_CODE,0) <= 0
    begin
		select @Msg = N'Not found Tax code for TA ROW_ID : ' + @TestCaseRowID
                + N', EVENT_TYPE: ' + str(@EVENT_TYPE,len(@EVENT_TYPE),0)
                + N', DEAL_TYPE: ' + str(@DEAL_TYPE,len(@DEAL_TYPE),0)
                + N', DEAL_NUMBER: ' + str(@UI_DEAL_NUM,len(@UI_DEAL_NUM),0)
                + N', DB_CLIENT_TYPE: ' + str(@DB_CLIENT_TYPE,len(@DB_CLIENT_TYPE),0)
                + N', UI_TYPE_ENTRANCE: ' + str(@UI_TYPE_ENTRANCE,len(@UI_TYPE_ENTRANCE),0)
                + N', UI_INOUT_TRANSFER: ' + str(@UI_INOUT_TRANSFER,len(@UI_INOUT_TRANSFER),0)
                + N', BETWEEN_OWN_ACCOUNTS: ' + str(@BETWEEN_OWN_ACCOUNTS,len(@BETWEEN_OWN_ACCOUNTS),0)
        ;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @TestCaseRowID, @Msg
		return 3;
    end

    if @LogTraceInfo = 1
    begin 
        select  @TA_RowID       as [TEST_CASE_ID]
            ,   @TAX_CODE       as [TAX_CODE]
            ,   @EVENT_TYPE     as [EVENT_TYPE]
            ,   @DEAL_TYPE      as [DEAL_TYPE]
            ,   @UI_DEAL_NUM    as [DEAL_NUMBER]
    end

    if @WithUpdate = 1
    begin 
        update [PREV]
        set [TAX_CODE] = @TAX_CODE
/*      ,   [PREF_CODE] */
        from dbo.[PREV_COMMON_TA] [PREV]
        where [PREV].[ROW_ID] = @TA_RowID
    end 

	/************************************************************************************************************/
	/* Log End Of Procedure */
	if @LogBegEndProc = 1
	begin 
		select @Sql1 = N'dbo.[SP_CASH_PAYMENTS_UPDATE_TAXED_INFO] @OnlineSqlServerName ='+@OnlineSqlServerName
                    + N', @OnlineSqlDataBaseName = '+@OnlineSqlDataBaseName
                    + N', @CurrAccountDate = '''+convert(varchar(10),@CurrAccountDate,121)+''''
                    + N', @TestCaseRowID = '+@TestCaseRowID
                    + N', @WithUpdate = '+str(@WithUpdate,len(@WithUpdate),0)
            ,   @Msg = N'Duration: '+ dbo.FN_GET_TIME_DIFF(@TimeBeg, GetDate()) + 
                    + N', TA Row ID: '+@TestCaseRowID
                    + N', @UI_DEAL_NUM: '+str(@UI_DEAL_NUM,len(@UI_DEAL_NUM),0)
                    + N', @DEAL_TYPE: '+str(@DEAL_TYPE,len(@DEAL_TYPE),0)
        ;
		exec dbo.SP_SYS_LOG_PROC @@PROCID, @Msg, @Sql1
	end

	return 0;
end
go
