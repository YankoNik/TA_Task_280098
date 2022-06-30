
--- [SP_GET_PREFERENCIAL_PLAN_INFO_GET_STANDART_CONTRACT_PREF_CODE]

CREATE   PROCEDURE [dbo].[SP_GET_PREFERENCIAL_PLAN_INFO_GET_STANDART_CONTRACT_PREF_CODE]
(
	@DEAL_TYPE		INT				-- Тип на сделката
	 , @DEAL_NUM		INT				-- Номер на сделката
	 , @TAX_CODE		INT				-- Код на таксата за която търсим преференцията
	 , @OPEN_DATE DATETIME	-- Дата на откриване на сделката
     , @DATE_ACT DATETIME		-- Дата на действието предизвикващо таксуване
	 , @STD_DOG_CODE INT		-- Стандартния договор на сделката която таксуваме
     , @PREF_CODE INT	OUT			-- Това ще е кода на преференцията която ще върнем накрая
     , @PREF_NAME char(50)	OUT -- Името на преференцията която ще върнем
)
AS
	-- Търсим по код на стандартен договор
	SELECT TOP 1
		@PREF_CODE = T.CODE, 
		@PREF_NAME = PREFERENCE_NAME 
	FROM PREFERENCIAL_TAXES T WITH(NOLOCK)
	INNER JOIN PREFERENCIAL_TAXES_TO_STD_DEALS TD WITH(NOLOCK)
		ON	T.CODE = TD.PREFERENCIAL_TAX_CODE
		AND T.PREFERENCE_STATUS = 1							-- Действаща преференция
		OR
			( /* Изтекла преференция, но периода и на действие обхващащ @DATE_ACT -> за нас е активна */
				T.CODE = TD.PREFERENCIAL_TAX_CODE
				AND T.PREFERENCE_STATUS = 2					-- Преференция с изтекъл срок на валидност
				AND @DATE_ACT BETWEEN T.DATE_VALID_FROM AND T.DATE_VALID_TO
			)						
	INNER JOIN PREFERENCIAL_EVENTS_TAXES ET  WITH(NOLOCK)
		ON	T.CODE = ET.PREFERENCE_CODE
	WHERE ET.TAX_CODE = @TAX_CODE
		AND TD.DEAL_TYPE = @DEAL_TYPE
		AND TD.STD_DOG_CODE = @STD_DOG_CODE
		AND CAST( T.DATE_VALID_FROM AS DATE ) <= @DATE_ACT	 -- Провераваме дали действието е извършено в
		AND CAST( T.DATE_VALID_TO   AS DATE ) >= @DATE_ACT	 -- периода на валидност на промоцията
		AND ( @OPEN_DATE <= 0 OR 
				( ( T.DATE_OPEN_FROM <= 0 OR T.DATE_OPEN_FROM <= @OPEN_DATE )
					AND ( T.DATE_OPEN_TO <= 0 OR T.DATE_OPEN_TO >= @OPEN_DATE ) ) )
GO
