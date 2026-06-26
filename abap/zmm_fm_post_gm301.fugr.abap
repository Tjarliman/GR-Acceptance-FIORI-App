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
* Flow: ext_wms = '1' makes BAPI_GOODSMVT_CREATE create an INBOUND
* DELIVERY (not a material document). The IBD number is read from the
* return table (msg id 'L9', number 514, MESSAGE_V1). Once the IBD is
* committed, the Goods Receipt is posted for it by reusing the EWM
* function module ZEWM_FM_POST_GR (same function group ZEWM_GR).
* The EWM warehouse / GR-zone bin and the frame UII are still passed on
* the item / serial rows.
*
* Plant / storage locations are NOT hardcoded - they are read from the
* parameter table ZCAT_USRPARAMD (ZZMODUL 'EWM', ZZPARAMID 'EWM-I-002',
* ZZACTIV 'X'):
*   From Plant / SLoc = ZZDERVAL1 / ZZDERVAL2  (ORIG_PLANT / ORIG_SLOC)
*   To   Plant / SLoc = ZZDERVAL3 / ZZDERVAL4  (MOVE_PLANT / MOVE_SLOC)
*   EWM GR bin        = ZZDERVAL5              (STGE_BIN_EWM)
*   GOODSMVT_CODE = 04 and Move Type = 301 stay hardcoded
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

*---- 1b. Reject serials already assigned in EWM (/SCWM/SERI) -----------*
  LOOP AT lt_parsed INTO DATA(ls_chk).
    SELECT SINGLE serid FROM /scwm/seri
      WHERE serid = @ls_chk-serialnumber
      INTO @DATA(lv_seri_chk).
    IF sy-subrc = 0.
      ev_message = |Serial { ls_chk-serialnumber } is already assigned to another delivery.|.
      RETURN.
    ENDIF.
  ENDLOOP.

*---- 2. Build BAPI header ----------------------------------------------*
  ls_header-pstng_date = sy-datum.
  ls_header-doc_date   = sy-datum.
  ls_header-header_txt = '301 Acceptance'.
  ls_header-ext_wms    = '1'.   " 1 = create inbound delivery (was 3 = material doc)

  ls_code-gm_code = '04'.

*---- 2b. Plant / storage location config (ZCAT_USRPARAMD, EWM-I-002) ---*
  SELECT SINGLE zzderval1, zzderval2, zzderval3, zzderval4, zzderval5
    FROM zcat_usrparamd
    WHERE zzmodul   = 'EWM'
      AND zzparamid = 'EWM-I-002'
      AND zzparam1  = 'ORIG_PLANT'
      AND zzparam2  = 'ORIG_SLOC'
      AND zzparam3  = 'MOVE_PLANT'
      AND zzparam4  = 'MOVE_SLOC'
      AND zzparam5  = 'STGE_BIN_EWM'
      AND zzactiv   = 'X'
    INTO @DATA(ls_cfg).

  IF sy-subrc <> 0.
    ev_message = |Plant/SLoc config (ZCAT_USRPARAMD / EWM-I-002) not found.|.
    RETURN.
  ENDIF.

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
                    plant         = ls_cfg-zzderval1
                    stge_loc      = ls_cfg-zzderval2
                    move_type     = '301'
                    entry_qnt     = ls_group-count
                    entry_uom     = lv_meins
                    move_plant    = ls_cfg-zzderval3
                    move_stloc    = ls_cfg-zzderval4
                    move_mat      = ls_group-material
                    stge_bin_ewm  = ls_cfg-zzderval5
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

*---- 5. Read the inbound delivery created by the BAPI ------------------*
*        ext_wms = '1' creates an IBD; its number comes back as
*        message id 'L9', number 514, in MESSAGE_V1.
  DATA lv_ibd TYPE char35.

  LOOP AT lt_return INTO DATA(ls_ibd) WHERE id = 'L9' AND number = '514'.
    lv_ibd = ls_ibd-message_v1.
    EXIT.
  ENDLOOP.

  IF lv_ibd IS INITIAL.
    " No inbound delivery created -> report first hard error and stop
    LOOP AT lt_return INTO DATA(ls_err) WHERE type CA 'EAX'.
      ev_message = ls_err-message.
      EXIT.
    ENDLOOP.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    IF ev_message IS INITIAL.
      ev_message = |Inbound delivery creation failed.|.
    ENDIF.
    RETURN.
  ENDIF.

  CONDENSE lv_ibd.

  " Persist the inbound delivery before posting the GR
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = abap_true.

*---- 6. Wait for the IBD to be distributed to EWM ----------------------*
*        BAPI_GOODSMVT_CREATE creates the ERP inbound delivery, which is
*        distributed to the EWM delivery (/SCDL) asynchronously. Poll the
*        EWM delivery header first - otherwise the GR FM reports
*        "Delivery not found".
  DATA lv_docno TYPE c LENGTH 35.
  lv_docno = lv_ibd.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = lv_docno
    IMPORTING
      output = lv_docno.

  DATA lv_found TYPE abap_bool.
  DO 15 TIMES.
    SELECT SINGLE docid FROM /scdl/db_proch_i
      INTO @DATA(lv_docid)
      WHERE docno = @lv_docno.
    IF sy-subrc = 0.
      lv_found = abap_true.
      EXIT.
    ENDIF.
    WAIT UP TO 1 SECONDS.
  ENDDO.

  IF lv_found = abap_false.
    ev_success = abap_false.
    ev_matdoc  = lv_ibd.
    ev_message = |Inbound delivery { lv_ibd } created, but not yet distributed to EWM - post the GR later.|.
    RETURN.
  ENDIF.

*---- 7. Post the Goods Receipt for the new inbound delivery ------------*
*        Reuse the EWM GR function module from the engine/frame app
*        (same function group ZEWM_GR).
  DATA: lv_gr_ok   TYPE flag,
        lv_gr_msg  TYPE string,
        lv_gr_doc  TYPE char20,
        lv_gr_year TYPE char4.

  CALL FUNCTION 'ZEWM_FM_POST_GR'
    EXPORTING
      iv_warehouse     = iv_warehouse
      iv_delivery      = lv_ibd
    IMPORTING
      ev_success       = lv_gr_ok
      ev_message       = lv_gr_msg
      ev_matdoc_number = lv_gr_doc
      ev_matdoc_year   = lv_gr_year.

  ev_matdoc  = lv_ibd.        " return the inbound delivery number
  ev_matyear = lv_gr_year.

  IF lv_gr_ok = abap_true.
    ev_success = abap_true.
    ev_message = |Inbound delivery { lv_ibd } created and GR posted.|.
  ELSE.
    ev_success = abap_false.
    ev_message = |Inbound delivery { lv_ibd } created, but GR failed: { lv_gr_msg }|.
  ENDIF.

ENDFUNCTION.
