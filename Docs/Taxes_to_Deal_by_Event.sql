--EVENT_TYPE	EVENT_NAME
--1		Документ "Нареждане разписка"
--5		Документ "Вносна бележка"
--6		Документ "Кредитен превод"
--8		Документ "Бюджетно платежно нареждане"
--9		Документ "Преводно нареждане от/към бюджета"
--10	Документ "Преводно нареждане от/към бюджета-мног."
--11	Документ "Директен дебит - плащане"
--12	Документ "Директен дебит - искане"
--13	Документ "Директен дебит - отказ"
--19	Масово плащане
--23	Регистриране на вътрешнобанков валутен превод
--24	Верификация на издаден валутен превод
declare @EventCode	int  = 6
	,	@DealType	int  = 1
	,	@DealNum	int  = 2350917
	,	@Date		date = dbo.get_cur_date()
;
with [E2D] as 
(
	select top (1) * 
	from dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
	where [EVENT_CODE] = @EventCode 
		and [DEAL_TYPE] = @DealType
)
select [T2D].STD_DOG_CODE, [TAX].*
from dbo.[TAXES_TO_DEALS_RAZPL] [T2D] with(nolock)
inner join [E2D] [E2D] with(nolock)
	on	[E2D].[DEAL_TYPE] = [T2D].[DEAL_TYPE]
	and [E2D].[EVENT_CODE] = @EventCode
inner join dbo.[TAXES] [TAX] with(nolock)
	on	[T2D].[DEAL_TYPE]	= @DealType
	and [T2D].[DEAL_NUMBER] = @DealNum
	and [T2D].[TAX_CODE]	= [TAX].[TAX_CODE]
	and [TAX].[EVENT_TO_DEAL_CODE] = [E2D].[CODE]
	and @Date between [TAX].[VALID_FROM] and [TAX].[VALID_TO]
ORDER BY [TAX].TAX_CODE
go



