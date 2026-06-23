CLASS lhc_seriallookup DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_gm_item,
             material     TYPE c LENGTH 40,
             serialnumber TYPE c LENGTH 30,
             uii          TYPE c LENGTH 72,
           END OF ty_gm_item,
           ty_gm_items TYPE STANDARD TABLE OF ty_gm_item WITH EMPTY KEY.

    METHODS read FOR READ
      IMPORTING keys FOR READ seriallookup RESULT result.

    METHODS postgoodsmovement FOR MODIFY
      IMPORTING keys FOR ACTION seriallookup~postgoodsmovement RESULT result.

ENDCLASS.

CLASS lhc_seriallookup IMPLEMENTATION.

  METHOD read.
  ENDMETHOD.

  METHOD postgoodsmovement.

    LOOP AT keys INTO DATA(key).

      DATA(warehouse) = key-%param-warehousenumber.
      DATA(items_json) = key-%param-itemsjson.

      DATA lv_success  TYPE flag.
      DATA lv_message  TYPE string.
      DATA lv_mat_doc  TYPE char10.
      DATA lv_mat_year TYPE char4.

      CALL FUNCTION 'ZMM_FM_POST_GM301'
        DESTINATION 'NONE'
        EXPORTING
          iv_warehouse   = warehouse
          iv_items_json  = items_json
        IMPORTING
          ev_success     = lv_success
          ev_message     = lv_message
          ev_matdoc      = lv_mat_doc
          ev_matyear     = lv_mat_year
        EXCEPTIONS
          system_failure        = 1
          communication_failure = 2
          OTHERS                = 3.

      IF sy-subrc <> 0.
        lv_success = abap_false.
        lv_message = |FM call failed: { sy-subrc }|.
      ENDIF.

      APPEND VALUE #(
        %cid   = key-%cid
        %param = VALUE #(
          success          = lv_success
          materialdocument = lv_mat_doc
          materialdocyear  = lv_mat_year
          message          = lv_message ) ) TO result.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_zmm_i_gracceptance DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_zmm_i_gracceptance IMPLEMENTATION.
  METHOD finalize.
  ENDMETHOD.
  METHOD check_before_save.
  ENDMETHOD.
  METHOD save.
  ENDMETHOD.
  METHOD cleanup.
  ENDMETHOD.
  METHOD cleanup_finalize.
  ENDMETHOD.
ENDCLASS.
