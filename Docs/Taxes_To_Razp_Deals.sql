/* 1. Таблица за събития  */
select * 
from dbo.[EVT_EVENTS] with(nolock)
where EVENT_NAME like '%Вносна%'
go

/* 2. Таблица за събития към тип сделка  */
select top (10) * 
from dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
where EVENT_CODE = 5 
	and DEAL_TYPE = 1
go

select top (10) * 
from dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
where	[DEAL_TYPE]	 = 1	/* 1 - Разплащателна сделка */
	and	[EVENT_CODE] = 5	/* 5 - Документ "Вносна бележка" */
go

/* 3. Таблица за назначените такси към сделка  */
select top (1000) * 
from dbo.[TAXES_TO_DEALS_RAZPL] with(nolock)
where	[DEAL_NUMBER]	= 2471545
	and	[DEAL_TYPE]		= 1	/* 1 - Разплащателна сделка */
go

/* 4. Такси към дадена сделка за конкретно събитие */
drop table if exists dbo.[#Taxes]
go
declare @Date date = getDate()
	,	@DealType int = 1
	,	@DealNum int = 2471545
	,	@EventToDealCode int = 54
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

/* 5. Такси към дадена сделка за конкретно събитие */
select * from dbo.[#Taxes] with(nolock)
go
select * from dbo.[TAXES_DESCRIPTORS] with(nolock)
go
