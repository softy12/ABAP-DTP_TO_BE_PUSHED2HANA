REPORT ZMM_DTP_TO_BE_PUSHED2HANA LINE-SIZE 1023.

DATA: l_t_dtp TYPE STANDARD TABLE OF rsbkdtp WITH HEADER LINE,
      g_r_dtp TYPE REF TO cl_rsbk_dtp,
      l_dtp   TYPE rsbkdtpnm,
      lt_msg     TYPE rs_t_msg,
      lt_msg_all TYPE rs_t_msg,
      ls_msg  TYPE rs_s_msg,
      rs_c_false1 TYPE rs_bool,
      rs_c_false2 TYPE rs_bool.

SELECT-OPTIONS: s_dtp for l_t_dtp-dtp.

LOOP AT s_dtp.
  l_dtp = s_dtp-low.
  IF l_dtp IS NOT INITIAL.
    FREE g_r_dtp.
    g_r_dtp = cl_rsbk_dtp=>factory( l_dtp ).
    PERFORM check_haap_possible USING g_r_dtp rs_c_false1 rs_c_false2 lt_msg.
    APPEND LINES OF lt_msg TO lt_msg_all.
  ENDIF.
ENDLOOP.

DELETE lt_msg_all WHERE msgv1 <> 'DTP compatible with SAP HANA Execution'.

LOOP AT lt_msg_all INTO ls_msg.
  WRITE:  / ls_msg-msgv1, ls_msg-msgv2, ls_msg-msgv3, ls_msg-msgv4.
ENDLOOP.

FORM check_haap_possible  USING g_r_dtp    TYPE REF TO cl_rsbk_dtp
                                u_canceled TYPE rs_bool
                                u_set      TYPE rs_bool
                                t_msg      TYPE rs_t_msg
                          RAISING cx_rs_failed.

  DATA: ls_rsbkdynp200 TYPE rsbkdynp200,
        l_r_msg        TYPE REF TO cl_rso_msg,
        l_s_msg        TYPE rs_s_msg,
        l_r_no_handler TYPE REF TO cx_sy_no_handler.

  TRY.
    DATA(l_script_proc) = g_r_dtp->if_rsbk_dtp_display~get_script_proc( "DTP Script enabling degree
                                             i_check_also_dtp = rs_c_true
                                             i_from_ui        = xsdbool( u_canceled IS INITIAL AND
                                                                         u_set      IS INITIAL     ) ).
    CATCH cx_sy_no_handler INTO l_r_no_handler.
    IF l_r_no_handler IS NOT INITIAL.
      EXIT.
    ENDIF.
  ENDTRY.

  TRY.
      IF l_script_proc = rstr_c_realization-must_not OR
         l_script_proc = rstr_c_realization-invalid.

        l_r_msg = g_r_dtp->get_obj_ref_display( )->n_r_msg.
        IF l_r_msg IS BOUND.
          DATA l_title TYPE text132.
          IF u_canceled = rs_c_true.
            l_title = 'Last change is incompatible with SAP HANA processing'(HNC).
          ELSE.
            l_title = 'SAP HANA processing not possible'(HNP).
          ENDIF.
          DATA(l_t_msg) = l_r_msg->get_all_msg( ).
          IF u_canceled = rs_c_true.
            DATA wa TYPE bal_s_msg.
            MOVE-CORRESPONDING sy TO wa.
            wa-msgv1 = l_dtp.
            INSERT wa INTO l_t_msg INDEX 1.
          ENDIF.
          READ TABLE l_t_msg INTO l_s_msg INDEX 1.
          l_s_msg-msgv2 = l_dtp.
          l_s_msg-msgv1 = l_title.
          MODIFY l_t_msg FROM l_s_msg INDEX 1.
          t_msg = l_t_msg[].
          RETURN.
        ENDIF.
      ELSEIF l_script_proc = rstr_c_realization-must_be      OR
             l_script_proc = rstr_c_realization-maybe        AND
             u_set = rs_c_false AND u_canceled = rs_c_false  AND
             NOT  rsbc_c_processmode-script && '/' &&
                  rsbc_c_processmode-script_par CS
                  g_r_dtp->get_processmode( ).
        l_s_msg-msgty = 'I'.
        l_s_msg-msgid = 'RSBK'.
        l_s_msg-msgno = '139'.
        l_s_msg-msgv2 = l_dtp.
        l_s_msg-msgv1 = 'DTP compatible with SAP HANA Execution'.
        APPEND l_s_msg TO t_msg.
      ENDIF.
    CATCH cx_rs_cancelled cx_rs_access_error INTO DATA(l_r_exc).
  ENDTRY.
  IF u_set = rs_c_true.
    g_r_dtp->if_rsbk_dtp_maintain~set_script_proc(
                                ls_rsbkdynp200-exec_script ).
  ENDIF.
ENDFORM.
