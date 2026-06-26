*----------------------------------------------------------------------*
* Project     : GR Acceptance
* RICEFW ID   :
* Description : Query provider - looks up material from serial number
* Program Name: ZCL_MM_QRY_GRACPT
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
CLASS zcl_mm_qry_gracpt DEFINITION PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_mm_qry_gracpt IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zmm_i_gracceptance.

    DATA(lo_request) = io_request.
    DATA(lo_response) = io_response.

    TRY.
        DATA(lt_filter) = lo_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        RETURN.
    ENDTRY.

    DATA lv_serial    TYPE c LENGTH 30.
    DATA lv_warehouse TYPE c LENGTH 4.

    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'SERIALNUMBER'.
          READ TABLE ls_filter-range INTO DATA(ls_range) INDEX 1.
          IF sy-subrc = 0.
            lv_serial = ls_range-low.
          ENDIF.
        WHEN 'WAREHOUSENUMBER'.
          READ TABLE ls_filter-range INTO ls_range INDEX 1.
          IF sy-subrc = 0.
            lv_warehouse = ls_range-low.
          ENDIF.
      ENDCASE.
    ENDLOOP.

    IF lv_serial IS INITIAL.
      IF lo_request->is_total_numb_of_rec_requested( ).
        lo_response->set_total_number_of_records( 0 ).
      ENDIF.
      lo_response->set_data( lt_result ).
      RETURN.
    ENDIF.

    " Look up material from serial number via EQUI (equipment master)
    SELECT SINGLE equnr, matnr, sernr
      FROM equi
      INTO @DATA(ls_equi)
      WHERE sernr = @lv_serial.

    IF sy-subrc = 0 AND ls_equi-matnr IS NOT INITIAL.
      " Get material description
      SELECT SINGLE maktx
        FROM makt
        INTO @DATA(lv_maktx)
        WHERE matnr = @ls_equi-matnr
          AND spras = @sy-langu.

      " Block if the serial is already assigned in EWM (/SCWM/SERI)
      DATA lv_conflict TYPE string.
      CLEAR lv_conflict.
      SELECT SINGLE serid FROM /scwm/seri
        WHERE serid = @lv_serial
        INTO @DATA(lv_seri_serid).
      IF sy-subrc = 0.
        lv_conflict = |Serial { lv_serial } is already assigned to another delivery.|.
      ENDIF.

      APPEND VALUE #(
        serialnumber    = lv_serial
        warehousenumber = lv_warehouse
        material        = ls_equi-matnr
        materialdesc    = lv_maktx
        message         = lv_conflict
      ) TO lt_result.
    ENDIF.

    " Apply paging
    IF lo_request->is_total_numb_of_rec_requested( ).
      DATA lv_total TYPE int8.
      lv_total = lines( lt_result ).
      lo_response->set_total_number_of_records( lv_total ).
    ENDIF.

    DATA(lo_paging) = lo_request->get_paging( ).
    DATA(lv_skip)   = lo_paging->get_offset( ).
    DATA(lv_top)    = lo_paging->get_page_size( ).

    IF lv_skip > 0.
      DELETE lt_result FROM 1 TO lv_skip.
    ENDIF.
    IF lv_top > 0 AND lines( lt_result ) > lv_top.
      DELETE lt_result FROM ( lv_top + 1 ).
    ENDIF.

    lo_response->set_data( lt_result ).

  ENDMETHOD.

ENDCLASS.
