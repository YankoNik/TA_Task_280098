DECLARE @DEAL_TYPE		INT = 1
	,	@DEAL_NUM		INT = 1
	,	@TAX_CODE		INT = 1
	,	@STD_DOG_CODE	INT = 1
	,	@OPEN_DATE		DATETIME  = 0
	,	@PREF_CODE		INT = 0 /* Result */
;

DECLARE @DATE_ACT				 DATETIME = GETDATE() /* Дата на действието предизвикващо таксуване */
	,	@STS_BIT_PREF_INDIVIDUAL INT = dbo.setbit( cast(0 as binary(4)), 12, 1)
	,	@STS_BIT_PREF_CUSTOMER	 INT = dbo.setbit( cast(0 as binary(4)), 13, 1)
;

/* Първо търсим индивидуални преференции */
/* След което търсим и клиентски преференции */
SELECT top (1) @PREF_CODE = [PT].[CODE]
FROM [BPB_VCSBank_Online].dbo.[PREFERENCIAL_TAXES] [PT] WITH(NOLOCK)
INNER JOIN [BPB_VCSBank_Online].dbo.[PREFERENCIAL_EVENTS_TAXES] [ET] WITH(NOLOCK)
	ON	[PT].[CODE] = [ET].[PREFERENCE_CODE]
INNER JOIN [BPB_VCSBank_Online].dbo.[PREFERENCIAL_TAXES_TO_DEALS] [TD] WITH(NOLOCK)
	ON	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
	AND [PT].[PREFERENCE_STATUS] = 1 /* Действаща преференция */
	OR
	(	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
		AND [PT].[PREFERENCE_STATUS] = 2 /* Преференция с изтекъл срок на валидност */
		AND @DATE_ACT BETWEEN [PT].[DATE_VALID_FROM] AND [PT].[DATE_VALID_TO]
	)
WHERE
	(	([PT].[STATUS] & @STS_BIT_PREF_INDIVIDUAL) = @STS_BIT_PREF_INDIVIDUAL	/* Индивидуална преференция */
		OR ([PT].[STATUS] & @STS_BIT_PREF_CUSTOMER) = @STS_BIT_PREF_CUSTOMER	/* Клиентска преференция */
	)
	AND [ET].[TAX_CODE]	 = @TAX_CODE
	AND [TD].[DEAL_TYPE] = @DEAL_TYPE
	AND [TD].[DEAL_NUM]  = @DEAL_NUM
	AND CAST( [PT].[DATE_VALID_FROM] AS DATE ) <= @DATE_ACT /* Провераваме дали действието е извършено в */
	AND CAST( [PT].[DATE_VALID_TO]   AS DATE ) >= @DATE_ACT /* периода на валидност на промоцията */
	AND
	(	@OPEN_DATE <= 0
		OR
		(	( [PT].[DATE_OPEN_FROM] <= 0 OR [PT].[DATE_OPEN_FROM] <= @OPEN_DATE )
		AND ( [PT].[DATE_OPEN_TO]   <= 0 OR [PT].[DATE_OPEN_TO]   >= @OPEN_DATE )
		)
	)
ORDER BY
	(	CASE WHEN ([PT].[STATUS] & @STS_BIT_PREF_INDIVIDUAL) = @STS_BIT_PREF_INDIVIDUAL
				THEN 1
			WHEN  ([PT].[STATUS] & @STS_BIT_PREF_CUSTOMER)   = @STS_BIT_PREF_CUSTOMER
				THEN 2
			ELSE 3 END
	)
;
/* Когато не намерим индивидуална и клиентска преференция, ще търсим стандартна, т.е. такава закачена към кода на стандартния договор */
IF @PREF_CODE <= 0 AND @STD_DOG_CODE > 0
BEGIN
	/* Търсим по код на стандартен договор */
	SELECT TOP (1)
		@PREF_CODE = [PT].[CODE]
	FROM [BPB_VCSBank_Online].dbo.[PREFERENCIAL_TAXES] [PT] WITH(NOLOCK)
	INNER JOIN [BPB_VCSBank_Online].dbo.[PREFERENCIAL_EVENTS_TAXES] [ET] WITH(NOLOCK)
		ON	[PT].[CODE] = [ET].[PREFERENCE_CODE]
	INNER JOIN [BPB_VCSBank_Online].dbo.[PREFERENCIAL_TAXES_TO_STD_DEALS] [TD] WITH(NOLOCK)
		ON	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
		AND [PT].[PREFERENCE_STATUS] = 1						/* Действаща преференция */
		OR 
		(	[PT].[CODE] = [TD].[PREFERENCIAL_TAX_CODE]
			AND [PT].[PREFERENCE_STATUS] = 2					/* Преференция с изтекъл срок на валидност */
			AND @DATE_ACT BETWEEN [PT].[DATE_VALID_FROM] AND [PT].[DATE_VALID_TO]
		)
	WHERE	[ET].[TAX_CODE]			= @TAX_CODE
		AND [TD].[DEAL_TYPE]		= @DEAL_TYPE
		AND [TD].[STD_DOG_CODE]		= @STD_DOG_CODE
		AND CAST( [PT].[DATE_VALID_FROM] AS DATE ) <= @DATE_ACT	 /* Провераваме дали действието е извършено в */
		AND CAST( [PT].[DATE_VALID_TO]   AS DATE ) >= @DATE_ACT	 /* периода на валидност на промоцията */
		AND ( @OPEN_DATE <= 0
			OR  (		([PT].[DATE_OPEN_FROM]	<= 0 OR [PT].[DATE_OPEN_FROM] <= @OPEN_DATE )
					AND ([PT].[DATE_OPEN_TO]	<= 0 OR [PT].[DATE_OPEN_TO]	  >= @OPEN_DATE )
				)
			)
END

SELECT @PREF_CODE as [PREFERENCE_CODE]
GO
