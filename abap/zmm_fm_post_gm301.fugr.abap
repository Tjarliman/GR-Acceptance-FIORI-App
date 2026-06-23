*----------------------------------------------------------------------*
* Project     : GR Acceptance
* RICEFW ID   :
* Description : Wrapper FM for BAPI_GOODSMVT_CREATE - MvT 301
* Program Name: ZMM_FM_POST_GM301
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
* Posts a Goods Movement with Movement Type 301 (Transfer Posting)
* using BAPI_GOODSMVT_CREATE.
*
* iv_items_json is a JSON array. Each entry has:
*   Material     - material number
*   SerialNumber - engine serial number
*   Uii          - frame number (UII)
*
* Defaults:
*   From Plant = GM01, From SLOC = IP01
*   To Plant   = GD01, To SLOC   = WF02
*   GOODSMVT_CODE = 04 (Transfer Posting)
*   Move Type = 301
*----------------------------------------------------------------------*
FUNCTION zmm_fm_post_gm301
  IMPORTING
    VALUE(iv_warehouse)  TYPE char4
    VALUE(iv_items_json) TYPE string
  EXPORTING
    VALUE(ev_success) TYPE flag
    VALUE(ev_message) TYPE string
    VALUE(ev_matdoc)  TYPE char10
    VALUE(ev_matyear) TYPE char4.

  TYPES: BEGIN OF ty_item,
           material     TYPE c LENGTH 40,
           serialnumber TYPE c LENGTH 30,
           uii          TYPE c LENGTH 72,
         END OF ty_item,
         ty_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  DATA: ls_header TYPE bapi2017_gm_head_01,
        ls_code   TYPE bapi2017_gm_code,
        ls_item   TYPE bapi2017_gm_item_create,
        ls_serial TYPE bapi2017_gm_serialnumber,
        lt_items  TYPE STANDARD TABLE OF bapi2017_gm_item_create,
        lt_serial TYPE STANDARD TABLE OF bapi2017_gm_serialnumber,
        lt_return TYPE STANDARD TABLE OF bapiret2,
        lt_parsed TYPE ty_items,
        lv_matdoc TYPE bapi2017_gm_head_ret-mat_doc,
        lv_matyear TYPE bapi2017_gm_head_ret-doc_year.

  CLEAR: ev_success, ev_message, ev_matdoc, ev_matyear.

*---- 1. Parse JSON input -----------------------------------------------*
  /ui2/cl_json=>deserialize(
    EXPORTING json = iv_items_json
    CHANGING  data = lt_parsed ).

  IF lt_parsed IS INITIAL.
    ev_message = |No items provided.|.
    RETURN.
  ENDIF.

*---- 2. Build BAPI header ----------------------------------------------*
  ls_header-pstng_date = sy-datum.
  ls_header-doc_date   = sy-datum.
  ls_header-header_txt = '301 Acceptance'.

  ls_code-gm_code = '04'.

*---- 3. Build BAPI items and serial numbers ----------------------------*
  DATA lv_line TYPE i VALUE 1.

  LOOP AT lt_parsed INTO DATA(ls_parsed).

    CLEAR ls_item.
    ls_item-material   = ls_parsed-material.
    ls_item-plant      = 'GM01'.
    ls_item-stge_loc   = 'IP01'.
    ls_item-move_type  = '301'.
    ls_item-entry_qnt  = '1'.
    ls_item-entry_uom  = 'PC'.
    ls_item-move_plant = 'GD01'.
    ls_item-move_stloc = 'WF02'.
    APPEND ls_item TO lt_items.

    CLEAR ls_serial.
    ls_serial-matdoc_itm = lv_line.
    ls_serial-serialno   = ls_parsed-serialnumber.
    APPEND ls_serial TO lt_serial.

    lv_line = lv_line + 1.

  ENDLOOP.

*---- 4. Call BAPI ------------------------------------------------------*
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
    EXPORTING
      goodsmvt_header  = ls_header
      goodsmvt_code    = ls_code
    IMPORTING
      materialdocument = lv_matdoc
      matdocumentyear  = lv_matyear
    TABLES
      goodsmvt_item         = lt_items
      goodsmvt_serialnumber = lt_serial
      return                = lt_return.

*---- 5. Check result ---------------------------------------------------*
  LOOP AT lt_return INTO DATA(ls_ret) WHERE type CA 'EAX'.
    ev_message = ls_ret-message.
    EXIT.
  ENDLOOP.

  IF lv_matdoc IS NOT INITIAL.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING wait = abap_true.

    ev_success = abap_true.
    ev_matdoc  = lv_matdoc.
    ev_matyear = lv_matyear.
    ev_message = |Goods Movement { lv_matdoc } / { lv_matyear } posted.|.
  ELSE.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    IF ev_message IS INITIAL.
      ev_message = |Goods movement posting failed.|.
    ENDIF.
  ENDIF.

ENDFUNCTION.
