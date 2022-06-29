/* 1. Междубанкиви преводи */
SELECT * FROM dbo.[PREV_COMMON_TA]
WHERE [DB_TYPE] = 'BETA'
	and [TYPE_ACTION] = 'CT'
	and [UI_INOUT_TRANSFER] <> 3
	and IsNull([BETWEEN_OWN_ACCOUNTS],0) = 0
GO

/* 3. Вътрешно банкови преводи */
SELECT * FROM dbo.[PREV_COMMON_TA]
WHERE [DB_TYPE] = 'BETA'
	and [TYPE_ACTION] = 'CT'
	and [UI_INOUT_TRANSFER] = 3
	and IsNull([BETWEEN_OWN_ACCOUNTS],0) = 0
GO

/* 3. Вътрешно банкови преводи - между собствени сметки: */
SELECT * FROM dbo.[PREV_COMMON_TA]
WHERE [DB_TYPE] = 'BETA'
	and [TYPE_ACTION] = 'CT'
	and [UI_INOUT_TRANSFER] = 3
	and IsNull([BETWEEN_OWN_ACCOUNTS],0) = 1
GO

/* Промер: */
-- PREV_COMMON_TA.ROW_ID = 401001 =>
select * from dbo.[RAZPREG_TA]
where ROW_ID = 201001 /* PREV_COMMON_TA.REF_ID */
go

select * from dbo.[RAZPREG_TA]
where ROW_ID = 201405 /* PREV_COMMON_TA.FOREIGN_GROUP_ID */
go



/*************************************/
-- Other 1
SELECT * FROM PREV_COMMON_TA
where TA_TYPE like '%beta%'
go

SELECT * FROM PREV_COMMON_TA
where TA_TYPE like '%beta%'
	and TYPE_ACTION in ( 'CashPayment', 'CT' )
go


SELECT * FROM PREV_COMMON_TA
where DB_TYPE = 'BETA'
go

/*************************************/
-- Other 2
SELECT * FROM  [VIEW_CASH_PAYMENTS_CONDITIONS]
go

SELECT * FROM  [VIEW_CASH_PAYMENTS_CONDITIONS_V2]
WHERE ROW_ID NOT IN (SELECT ROW_ID FROM  [VIEW_CASH_PAYMENTS_CONDITIONS])
ORDER BY [ROW_ID]
go


/*************************************/
-- Other 3
SELECT distinct([TYPE_ACTION])
FROM [BPB_Next_VCSBank_TestAutomation_Cases].[dbo].[PREV_COMMON_TA]
order by [TYPE_ACTION]
go

select * from [BPB_Next_VCSBank_TestAutomation_Cases].[dbo].[PREV_COMMON_TA]
where [TYPE_ACTION] in ('CashPayment')
order by [TYPE_ACTION]
go


/*************************************/
-- Other 4
select DB_TYPE, COUNT(*) AS CNT from PREV_COMMON_TA
GROUP BY DB_TYPE
ORDER BY DB_TYPE
GO

select TA_TYPE, COUNT(*) AS CNT from PREV_COMMON_TA
GROUP BY TA_TYPE
ORDER BY TA_TYPE
GO

select TYPE_ACTION, COUNT(*) AS CNT from PREV_COMMON_TA
GROUP BY TYPE_ACTION
ORDER BY TYPE_ACTION
GO

select TYPE_DEAL_BEN, COUNT(*) AS CNT from PREV_COMMON_TA
GROUP BY TYPE_DEAL_BEN
ORDER BY TYPE_DEAL_BEN
GO


select * from TAXES_ON_DEAL_PREFERENCE_COUNTERS
go

select * from TAX_EVENT_TO_DEAL_DESCRIPTORS
order by EVENT_TO_DEAL_TYPE_CODE
go

select * from TAX_SUM_TYPES_TO_DEALS
go

select top 10 * from TAXED_INFO
go
select top 10 * from TAXES
go
select top 10 * from TAXES_DESCRIPTORS
go
select top 10 * from PREFERENCIAL_TAXES
go
-- За определяне кода на преференцията трянва да разпиша подобна процедура, която да връща само кода и ежентуално наименование:
-- exec dbo.[SP_GET_PREFERENCIAL_PLAN_INFO]