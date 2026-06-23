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
* Items are GROUPED BY MATERIAL: one goods-movement line per material,
* with quantity = number of serials scanned for it, the base unit of
* measure from the material master (MARA-MEINS), and every serial of
* that material assigned to the single line.
*
* EWM-related: ext_wms = '3' flags the posting as coming from an
* external WMS; the EWM warehouse / GR-zone bin and the frame UII are
* passed through on the item and serial rows.
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

  DATA: ls_header  TYPE bapi2017_gm_head_01,
        ls_code    TYPE bapi2017_gm_code,
        lt_items   TYPE STANDARD TABLE OF bapi2017_gm_item_create,
        lt_serial  TYPE STANDARD TABLE OF bapi2017_gm_serialnumber,
        lt_return  TYPE STANDARD TABLE OF bapiret2,
        lt_parsed  TYPE ty_items,
        lv_matdoc  TYPE bapi2017_gm_head_ret-mat_doc,
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
  ls_header-ext_wms    = '3'.

  ls_code-gm_code = '04'.

*---- 3. Group by material -> one item line per material ----------------*
*        Quantity = number of serials in the group (GROUP SIZE)           *
*        UoM      = material master base unit (MARA-MEINS)               *
*        Every serial of the group is assigned to that one item line      *
  DATA lv_line  TYPE i VALUE 0.
  DATA lv_meins TYPE meins.

  LOOP AT lt_parsed INTO DATA(ls_parsed)
       GROUP BY ( material = ls_parsed-material
                  count    = GROUP SIZE )
       INTO DATA(ls_group).

    lv_line = lv_line + 1.

    " Base unit of measure from the material master
    CLEAR lv_meins.
    SELECT SINGLE meins FROM mara
      WHERE matnr = @ls_group-material
      INTO  @lv_meins.

    " One movement line per material; quantity = number of serials
    APPEND VALUE #( material      = ls_group-material
                    plant         = 'GM01'
                    stge_loc      = 'IP01'
                    move_type     = '301'
                    entry_qnt     = ls_group-count
                    entry_uom     = lv_meins
                    move_plant    = 'GD01'
                    move_stloc    = 'WF02'
                    move_mat      = ls_group-material
                    stge_bin_ewm  = 'GR-ZONE'
                    warehouse_ewm = iv_warehouse ) TO lt_items.

    " One serial-number row per scan, all linked to this material line
    LOOP AT GROUP ls_group INTO DATA(ls_member).
      APPEND VALUE #( matdoc_itm = lv_line
                      serialno   = ls_member-serialnumber
                      uii        = ls_member-uii ) TO lt_serial.
    ENDLOOP.

  ENDLOOP.

*---- 4. Call BAPI ------------------------------------------------------*
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
    EXPORTING
      goodsmvt_header       = ls_header
      goodsmvt_code         = ls_code
    IMPORTING
      materialdocument      = lv_matdoc
      matdocumentyear       = lv_matyear
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
      EXPORTING
        wait = abap_true.

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
