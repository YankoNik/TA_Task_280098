DROP PROCEDURE IF EXISTS dbo.[SP_TA_GET_TAX_CODES_BY_EVENT_AND_DEAL_NUM]
go

CREATE PROCEDURE dbo.[SP_TA_GET_TAX_CODES_BY_EVENT_AND_DEAL_NUM]
(
	@EVENT_CODE	INT
,	@DEAL_NUM	INT
,	@DEAL_TYPE	INT = 1
,	@ACC_DATE	DATETIME = NULL
)
AS 
BEGIN

	IF @ACC_DATE IS NULL
		SET @ACC_DATE = DBO.GET_CUR_DATE()

	;
	with [E2D] as 
	(
		select top (1) * 
		from dbo.[TAX_EVENTS_TO_DEALS] with(nolock)
		where [EVENT_CODE]	= @EVENT_CODE
			and [DEAL_TYPE] = @DEAL_TYPE
	)
	select [TAX].[TAX_CODE], [TAX].[TAX_NAME]
	from dbo.[TAXES_TO_DEALS_RAZPL] [T2D] with(nolock)
	inner join [E2D] [E2D] with(nolock)
		on	[E2D].[DEAL_TYPE] = [T2D].[DEAL_TYPE]
		and [E2D].[EVENT_CODE] = @EVENT_CODE
	inner join dbo.[TAXES] [TAX] with(nolock)
		on	[T2D].[DEAL_TYPE]	= @DEAL_TYPE
		and [T2D].[DEAL_NUMBER] = @DEAL_NUM
		and [T2D].[TAX_CODE]	= [TAX].[TAX_CODE]
		and [TAX].[EVENT_TO_DEAL_CODE] = [E2D].[CODE]
		and @ACC_DATE between [TAX].[VALID_FROM] and [TAX].[VALID_TO]
	END
GO
