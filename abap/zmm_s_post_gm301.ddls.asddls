*----------------------------------------------------------------------*
* Project     : GR Acceptance
* RICEFW ID   :
* Description : Action parameter for postGoodsMovement action
* Program Name: ZMM_S_POST_GM301
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
@EndUserText.label: 'Post Goods Movement 301 - Action Parameter'
define abstract entity ZMM_S_POST_GM301
{
  WarehouseNumber : abap.char( 4 );
  ItemsJson       : abap.string( 0 );
}
