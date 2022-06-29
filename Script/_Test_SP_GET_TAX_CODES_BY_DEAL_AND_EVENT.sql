--EVENT_TYPE	EVENT_NAME
--1		�������� "��������� ��������"
--5		�������� "������ �������"
--6		�������� "�������� ������"
--8		�������� "�������� �������� ���������"
--9		�������� "�������� ��������� ��/��� �������"
--10	�������� "�������� ��������� ��/��� �������-����."
--11	�������� "�������� ����� - �������"
--12	�������� "�������� ����� - ������"
--13	�������� "�������� ����� - �����"
--19	������ �������
--23	������������ �� �������������� ������� ������
--24	����������� �� ������� ������� ������

declare @TaxCode TABLE ( [TAX_CODE] INT, [TAX_NAME] VARCHAR(60) )
;
declare	@ConextDescValues TABLE ( [DECR_TYPE] INT, [DECR_VAL] INT )
;
insert into @ConextDescValues ([DECR_TYPE], [DECR_VAL])
values	(  7, 1 ) /* 7 - ��� �� ������; 1 - ��������� �������� */
	,	(  9, 1 ) /* 9 - ���������� �������; 1 - ������� �������*/
	,	( 10, 2 ) /* 10 - ��������; 2 - ������ */
	,	( 65, 1 ) /* 65 - �������� �� ��� ������; 1 - ������ ��� ��������� ������*/
;
declare @EventCode	int  = 24
	,	@DealNum	int  = 2350917
	,	@DealType	int  = 1
	,	@Date		date = dbo.get_cur_date()
;
INSERT INTO @TaxCode
EXEC dbo.[SP_TA_GET_TAX_CODES_BY_EVENT_AND_DEAL_NUM] @EventCode, @DealNum, @DealType, @Date
;
SELECT	[T].[TAX_CODE]
	,	[T].[TAX_NAME]
	,	[d].[CODE]		AS [DESCR_ROW_ID]
	,	[d].[TYPE]		AS DESCR_TYPE
	,	[d].[VALUE]		AS DESCR_VALUE
	,	cast( rtrim([NV].[VALUE_NAME]) as varchar(60) )	as [VALUE_NAME]
	,	cast( rtrim([n].[NAME]) as varchar(60) )		as [DESCT_NAME]
	,	[DT].[DET_NOM_ID]
	,	[DT].DET_OR_NOM
	,	[DT].IS_SYSTEM
FROM @TaxCode [T]
left outer join dbo.[TAXES_DESCRIPTORS] [d] with(nolock)
	on [t].[TAX_CODE] = [d].TAX_CODE
left outer join dbo.[NOMS] [n] with(nolock)
	on	[N].[NOMID] = 327
	and	[N].[CODE] = [d].[TYPE]
left outer join dbo.[NM327] [DT] with(nolock)
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

--select * from sys.tables where name like 'tax%' order by name
--go
