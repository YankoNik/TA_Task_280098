/* 1. Таблица за събития  */
select * 
from dbo.[EVT_EVENTS] with(nolock)
where EVENT_NAME like '%Вносна%'
go

/* 2. Таблица за събития към тип сделка  */
declare @EventType int = 6
;
select top (10) * 
from dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
where	[DEAL_TYPE]	 = 1	/* 1 - Разплащателна сделка */
	and	[EVENT_CODE] = @EventType	/* 5 - Документ "Вносна бележка"; 6 - Кредитен превод */
go

/* 3. Таблица за назначените такси към сделка  */
select top (1000) * 
from dbo.[TAXES_TO_DEALS_RAZPL] with(nolock)
where	[DEAL_NUMBER]	= 2471545
	and	[DEAL_TYPE]		= 1	/* 1 - Разплащателна сделка */
go

select * 
from dbo.[NM327] with(nolock)
where code in ( 9, 10, 40, 64, 65 )
go

select * from TOP_NOMS
where name like '%описате%'
go


/* 4. Такси към дадена сделка за конкретно събитие */
drop table if exists dbo.[#Taxes]
go
declare @Date date = getDate()
	,	@DealType int = 1
	,	@DealNum  int = 2471545
	,	@EventToDealCode int = 7 -- 54
;

select top (1000) [T].* 
into dbo.[#Taxes]
from dbo.[TAXES_TO_DEALS_RAZPL] [D] with(nolock)
inner join  dbo.[TAXES] [T] with(nolock)
	on	[D].[DEAL_TYPE] = 1
	and [D].[DEAL_NUMBER]	= @DealNum
	and [D].[TAX_CODE]	= [T].[TAX_CODE]
	and [T].EVENT_TO_DEAL_CODE = @EventToDealCode
	and @Date between [T].[VALID_FROM] and [t].[VALID_TO]
--	and [T].[CODE_SOURCE_TAX] > 0
go

/* 5. Описателите към таксите към дадена сделка за конкретно събитие */
select [d].*, [NV].VALUE_NAME, [n].[NAME] as [DESCT_NAME], [DT].[DET_NOM_ID], [DT].DET_OR_NOM, [DT].IS_SYSTEM
from dbo.[#Taxes] [t] with(nolock)
inner join dbo.[TAXES_DESCRIPTORS] [d] with(nolock)
	on [t].[TAX_CODE] = [d].TAX_CODE
inner join dbo.[NOMS] [n] with(nolock)
	on	[N].[NOMID] = 327
	and	[N].[CODE] = [d].[TYPE]
inner join dbo.[NM327] [DT] with(nolock)
	on	[DT].[NOMID] = [N].[NOMID]
	and	[DT].[CODE]	 = [N].[CODE]
left outer join dbo.dets [vd] with(nolock)
	on	[DT].[DET_OR_NOM] = 1
	and [vd].[DETID] = [DT].[DET_NOM_ID]
	and [vd].[CODE]	= [d].[VALUE]
left outer join dbo.NOMS [vn] with(nolock)
	on	[DT].[DET_OR_NOM] = 2
	and [vn].[NOMID] = [DT].[DET_NOM_ID]
	and [vn].[CODE]	= [d].[VALUE]
cross apply (
	select COALESCE(vd.[NAME], vN.[NAME], '') AS [VALUE_NAME]
) [NV]
order by [t].[TAX_CODE], [d].[TYPE], [d].[VALUE]
go
