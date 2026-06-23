*----------------------------------------------------------------------*
* Project     : GR Acceptance
* RICEFW ID   :
* Description : Custom entity for serial number lookup and GR posting
* Program Name: ZMM_I_GRACCEPTANCE
* Created By  : TRUSADI
* Create Date : 23-06-2026
* TR No.      :
*----------------------------------------------------------------------*
* Modification History
*----------------------------------------------------------------------*
* Defect/CR No.  Name          Date          Request No.  Description
*----------------------------------------------------------------------*
* CRxxx          XXXXXXX       DD-MMM-YYYY   xxxxx        XXXX
*----------------------------------------------------------------------*
@EndUserText.label: 'GR Acceptance - Serial Lookup'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_QRY_GRACPT'
define root custom entity ZMM_I_GRACCEPTANCE
{
  key SerialNumber    : abap.char( 30 );
      WarehouseNumber : abap.char( 4 );
      Material        : abap.char( 40 );
      MaterialDesc    : abap.char( 40 );
      Uii             : abap.char( 72 );
      Success         : abap_boolean;
      MaterialDocument: abap.char( 10 );
      MaterialDocYear : abap.numc( 4 );
      Message         : abap.string( 0 );
}
