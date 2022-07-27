
DROP PROC IF EXISTS dbo.[SP_TA_LOAD_TAXES_INFO]
GO

CREATE PROCEDURE dbo.[SP_TA_LOAD_TAXES_INFO]
(
	@TestAutomationType		sysname = N'%AIR%'
,   @TopRecords             int = 1000
,   @UpdateMode             int = 1
,	@LogTraceInfo			int = 0
)
AS
BEGIN
    DECLARE @Ret int = 0
    ;

    DECLARE CUR_TEST_CASES CURSOR LOCAL READ_ONLY  FOR 
    SELECT top (@TopRecords) [ROW_ID]
    FROM DBO.[VIEW_CASH_PAYMENTS_CONDITIONS] [V] WITH(NOLOCK)
    WHERE  [V].[TA_TYPE] LIKE @TestAutomationType
	;

	OPEN CUR_TEST_CASES;

	DECLARE @TestCaseID int = -1;
	FETCH NEXT FROM CUR_TEST_CASES INTO @TestCaseID;

	DECLARE @Msg nvarchar(max) = N'', @Sql nvarchar(max) = N''
	;

	WHILE @@FETCH_STATUS = 0
	BEGIN 
		BEGIN TRY

			EXEC @Ret = dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO] @TestCaseID, @UpdateMode

            IF @Ret <> 0
            BEGIN 
            	SELECT	@Msg = N'Error '+str(@UpdateMode,len(@UpdateMode),0)+ ' when execute Sql'          
                    ,	@Sql = N'Sql dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO] @TestCaseID = '+str(@TestCaseID,len(@TestCaseID),0)
							+ N', @UpdateMode = '+str(@UpdateMode,len(@UpdateMode),0)
                ;                
                EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
            END 

		END TRY
		BEGIN CATCH
			SELECT	@Msg = N'Exeption into: '+dbo.FN_GET_EXCEPTION_INFO()
				,	@Sql = N'Sql dbo.[SP_CASH_PAYMENTS_UPDATE_TAX_INFO] @TestCaseID = '+str(@TestCaseID,len(@TestCaseID),0)
							+ N', @UpdateMode = '+str(@UpdateMode,len(@UpdateMode),0)
			;
			EXEC dbo.SP_SYS_LOG_PROC @@PROCID, @Sql, @Msg
		END CATCH

		FETCH NEXT FROM CUR_TEST_CASES INTO @TestCaseID
	END

	CLOSE CUR_TEST_CASES
	DEALLOCATE CUR_TEST_CASES    

    RETURN @Ret
END
GO
