--- [SP_GET_PREFERENCIAL_PLAN_INFO]
CREATE   PROCEDURE [dbo].[SP_GET_PREFERENCIAL_PLAN_INFO]
(
	@DEAL_TYPE		INT				-- Тип на сделката
,   @DEAL_NUM		INT				-- Номер на сделката
,	@TAX_CODE		INT				-- Код на таксата за която търсим преференцията
,   @CUR_DATE		NVARCHAR(20)	-- Текуща счетоводна дата
,   @OPEN_DEAL_DATE	NVARCHAR(20)	-- Дата на откриване на сделката
,   @DATE_ACTION	INT	 = 0		-- Дата на действието предизвикващо таксуване
,   @CONTRACT_NUMBER INT = 0		-- Номер на договор
)
AS
	DECLARE @PREF_CODE		INT			-- Това ще е кода на преференцията която ще върнем накрая
	DECLARE @STD_DOG_CODE	INT			-- Стандартния договор на сделката която таксуваме
	DECLARE @PREF_NAME		VARCHAR(50)	-- Името на преференцията която ще върнем
	DECLARE @DATE_ACT		DATETIME	-- Дата на действието предизвикващо таксуване

	SET @PREF_CODE		= 0
	SET @STD_DOG_CODE	= @CONTRACT_NUMBER
	SET @PREF_NAME		= ''
	SET @DATE_ACT		= @CUR_DATE /* Инициализираме датата на действието */

	DECLARE @OPEN_DATE DATETIME = 0
	IF( @OPEN_DEAL_DATE != '0000-00-00' ) 
		SET @OPEN_DATE = @OPEN_DEAL_DATE

	-- Проверка за коректност
	IF @DATE_ACTION BETWEEN 20010101 AND 29991231
		SET @DATE_ACT = STR(@DATE_ACTION, 8, 0 )

	EXEC [SP_GET_PREFERENCIAL_PLAN_INFO_GET_INDIVIDUAL_OR_CLIENT_PREF_CODE] 
	@DEAL_TYPE, @DEAL_NUM, @TAX_CODE, @OPEN_DATE, @DATE_ACT, @STD_DOG_CODE, @PREF_CODE OUT, @PREF_NAME OUT

	-- Ако по сделката няма нито индивидуална нито клиентска търсим по договора
	IF ( @PREF_CODE = 0 )
	BEGIN
		-- Ако не е подаден отвън
		IF( @STD_DOG_CODE <= 0 )
		BEGIN
			EXEC [SP_GET_PREFERENCIAL_PLAN_INFO_GET_STANDART_CONTRACT_CODE] @DEAL_TYPE, @DEAL_NUM, @STD_DOG_CODE OUT
		END
		-- Търсим по код на стандартен договор
		EXEC [SP_GET_PREFERENCIAL_PLAN_INFO_GET_STANDART_CONTRACT_PREF_CODE] 
			@DEAL_TYPE, @DEAL_NUM, @TAX_CODE, @OPEN_DATE, @DATE_ACT, @STD_DOG_CODE, @PREF_CODE OUT, @PREF_NAME OUT
	END
     
	EXEC [SP_GET_PREFERENCIAL_PLAN_INFO_GET_RESULT] @TAX_CODE, @PREF_CODE

GO

