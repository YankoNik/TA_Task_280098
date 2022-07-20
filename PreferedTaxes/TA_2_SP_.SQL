declare	@DEAL_TYPE      INT					-- Тип на сделката
    ,   @DEAL_NUM		INT					-- Номер на сделката
    ,   @TAX_CODE		INT					-- Код на таксата за която търсим преференцията
    ,   @OPEN_DATE      DATETIME	 		-- Дата на откриване на сделката
    ,   @DATE_ACT       DATETIME			-- Дата на действието предизвикващо таксуване
    ,   @STD_DOG_CODE   INT					-- Стандартния договор на сделката която таксуваме
    ,   @PREF_CODE      INT /*OUT*/			-- Това ще е кода на преференцията която ще върнем накрая
    ,   @PREF_NAME      varchar(50)/* OUT*/	-- Името на преференцията която ще върнем
;
select	@DEAL_TYPE = 1
	,	@DEAL_NUM = -1
	,	@TAX_CODE = -1
	,	@OPEN_DATE = '2001-01-01'
	,	@DATE_ACT = getdate()
	,	@STD_DOG_CODE = -1
	,	@PREF_CODE = -1
	,	@PREF_NAME = ''
;
-- Първо търсим индивидуални преференции
-- След което търсим и клиентски преференции
declare @StsBit12 INT = (select INT_VAL from BIT_VALUES where BIT_NUM = 12)
	,	@StsBit13 INT = (select INT_VAL from BIT_VALUES where BIT_NUM = 13)
;
drop table if exists #TBL_PREFERENCIAL_CODE
;
SELECT	IDENTITY(INT,1,1)  AS [ROW_ID]
	,	[TD].[PREFERENCIAL_TAX_CODE]
	,	[ET].[TAX_CODE]
	,	[TD].[DEAL_TYPE]
	,	[TD].[DEAL_NUM]
	,	[T].[PREFERENCE_NAME]
INTO #TBL_PREFERENCIAL_CODE
FROM dbo.[PREFERENCIAL_TAXES] [T] WITH(NOLOCK)
INNER JOIN dbo.[PREFERENCIAL_TAXES_TO_DEALS] [TD] WITH(NOLOCK)
	ON	[T].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
	AND [T].[PREFERENCE_STATUS] = 1						-- Действаща преференция
	OR	(	/* Изтекла преференция, но периода и на действие обхващащ @DATE_ACT -> за нас е активна */
			[T].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
			AND [T].[PREFERENCE_STATUS] = 2				-- Преференция с изтекъл срок на валидност
			AND @DATE_ACT BETWEEN [T].[DATE_VALID_FROM] AND [T].[DATE_VALID_TO] )
INNER JOIN dbo.[PREFERENCIAL_EVENTS_TAXES] [ET]  WITH(NOLOCK)
	ON	[T].[CODE] = [ET].[PREFERENCE_CODE]
WHERE	(	([T].[STATUS] & @StsBit12) = @StsBit12 -- Индивидуална преференция
		OR	([T].[STATUS] & @StsBit13) = @StsBit13 -- Клиентска преференция
		)			
/*		AND [ET].[TAX_CODE]  = @TAX_CODE */
		AND [TD].[DEAL_TYPE] = @DEAL_TYPE
/*		AND [TD].[DEAL_NUM]  = @DEAL_NUM */
		AND CAST( [T].[DATE_VALID_FROM] AS DATE ) <= @DATE_ACT -- Провераваме дали действието е извършено в
		AND CAST( [T].[DATE_VALID_TO]   AS DATE ) >= @DATE_ACT -- периода на валидност на промоцията
		AND ( @OPEN_DATE <= 0 
				OR (	([T].[DATE_OPEN_FROM] <= 0 OR [T].[DATE_OPEN_FROM] <= @OPEN_DATE)
					AND ([T].[DATE_OPEN_TO]   <= 0 OR [T].[DATE_OPEN_TO]   >= @OPEN_DATE ) ) 
			)
ORDER BY CASE
		WHEN ([T].[STATUS] & @StsBit12) = @StsBit12 THEN 1
		WHEN ([T].[STATUS] & @StsBit13) = @StsBit13 THEN 3
		ELSE 3 END
GO

select * from #TBL_PREFERENCIAL_CODE
go