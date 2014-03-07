# /packages/intranet-employee-evaluation/tcl/intranet-employee-evaluation-procs.tcl
#
# Copyright (C) 1998-2014 various parties
# The software is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_library {
    @author klaus.hofeditz@project-open.com
}

# -----------------------------------------------------------
# New question Type: "Combined Type One"
# -----------------------------------------------------------

ad_proc -public create_html_combined_type_one {
    question_id
    employee_id
    wf_task_name
} {
    Returns HTML code for "Combined Type 1" type
    +----------------------------------------------------------------------------------------------------+
    |                | sub_question 1 txt      | sub_question 2 txt      | ... | sub_question 4 txt      |
    | ----------------------------------------------------------------------------------------------------
    | question_text  | sub_question 1 response | sub_question 2 response | ... | sub_question 4 response |
    +----------------------------------------------------------------------------------------------------+
} {

    # Get Main Question Txt
    set main_question_txt [db_string get_main_question_txt "select question_text from survsimp_questions where question_id = :question_id" -default 0]

    # Get sub-questions 
    set sql "
        select
                child_question_id
        from
                im_employee_evaluation_questions_tree t,
                survsimp_questions q
        where
                t.parent_question_id = $question_id
                and q.question_id = t.parent_question_id
        order by
                q.sort_key
    "

    # Get sub-question HTML
    set ctr 0
    set subquestion_list [db_list get_sub_questions $sql]

    foreach sub_question_id $subquestion_list {
        incr ctr
	ns_log NOTICE "intranet-employee-evaluation-procs::create_html_combined_type_one - sub_question_id: $sub_question_id"
	# ad_return_complaint xx "im_employee_evaluation_question_display $sub_question_id $employee_id '$wf_task_name'"
	eval {set subquestion_html_$ctr [im_employee_evaluation_question_display $sub_question_id $employee_id $wf_task_name ""]}
    }

    if { $ctr != 4 } {
	ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.Expecting5SubQuestions "Expecting 4 Sub-Questions for this question type, but found only: $ctr"]
    }

    # Build table
    return "
        <table border=\"0\">
        <tr>
                <td valign='top' width='300px'><span class='ee-survey-question-main-question-text' title='$question_id'>$main_question_txt</span></td>
                <td valign='top'>&nbsp;</td>
                <td valign='top'>$subquestion_html_1</td>
                <td valign='top'>&nbsp;&nbsp;</td>
                <td valign='top'>$subquestion_html_2</td>
                <td valign='top'>&nbsp;</td>
                <td valign='top'>$subquestion_html_3</td>
                <td valign='top'>&nbsp;&nbsp;</td>
                <td valign='top'>$subquestion_html_4</td>
        </tr>
        </table>
    "
}


ad_proc -public create_html_combined_type_two {
    question_id
    employee_id
    wf_task_name
} {
    Returns HTML code for "Combined Type 1" type

    +----------------------------------------------------------------------------------------------------+
    |  main question                                                                                     |  
    | ---------------------------------------------------------------------------------------------------|
    |  sub_question 1  | sub_question4 |                                                                 |
    | ----------------------------------------------------------------------------------------------------
    |  sub_question 2  | sub_question3 | sub_question 5                                                  |
    +----------------------------------------------------------------------------------------------------+

} {

    # Get Main Question Txt
    set main_question_txt [db_string get_main_question_txt "select question_text from survsimp_questions where question_id = :question_id" -default 0]

    # Get sub-questions
    set sql "
        select
                child_question_id
        from
                im_employee_evaluation_questions_tree t,
                survsimp_questions q
        where
                t.parent_question_id = $question_id
                and q.question_id = t.parent_question_id
        order by
                q.sort_key
    "

    # Get sub-question HTML
    set ctr 0
    set subquestion_list [db_list get_sub_questions $sql]

    foreach sub_question_id $subquestion_list {
        incr ctr
        ns_log NOTICE "intranet-employee-evaluation-procs::create_html_combined_type_one - sub_question_id: $sub_question_id"
        # ad_return_complaint xx "im_employee_evaluation_question_display $sub_question_id $employee_id '$wf_task_name'"
        eval {set subquestion_html_$ctr [im_employee_evaluation_question_display $sub_question_id $employee_id $wf_task_name ""]}
    }

    if { $ctr != 5 } {
	ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.Expecting5SubQuestions "Expecting 5 Sub-Questions for this quesion type but found: $ctr"]
    }

    # Build table
    return "
        <table class='' border=\"0\">
        <tr>
                <td valign='top' colspan='3'><span title='$question_id'>$main_question_txt</span></td>
	</tr>
        <tr>
                <td valign='top'>$subquestion_html_1</td>
		<td valign='top' colspan='2'>$subquestion_html_4</td>

	</tr>
	<tr>
		<td valign='top'>$subquestion_html_2</td>
		<td valign='top'>$subquestion_html_3</td>
		<td valign='top'>$subquestion_html_5</td>
	</tr>
        </table>
    "

}


# -----------------------------------------------------------
# Question Permissions 
# -----------------------------------------------------------

proc_doc im_employee_evaluation_question_permissions {
    { -wf_task_id "" } 
    { -wf_task_name "" } 
    { -wf_role "" } 
    question_id
    employee_id
} {
    Should cover the following use cases 
    	a) User to be evaluated requires access within WF (could be blocked) 
    	b) User to be evaluated requires access outside WF
	c) Task assignee within WF (could be regular supervisor or delegate of regular supervisor) 
	d) Direct Supervisor (Attribute: Employee Information)
	e) One of the superior supervisors of the direct supervisors

	Returns list of three elements - value range: [ 0 | 1 ] 
    	- read permission  
	- write permission 
    	- admin permission 
} {
    if { "" != $wf_task_name } {
	# Access within WF 
	# Check if employee himself inquires
	set sql "select read_p, write_p, admin_p from im_employee_evaluation_config where question_id = :question_id and wf_task_name = :wf_task_name and wf_role = :wf_role"

	if {[catch {
		db_1row get_permissions_for_question $sql
	} err_msg]} {
	    global errorInfo
	    ns_log Error $errorInfo
	    ad_return_complaint 1  "Error getting permissions for question_id: $question_id, wf_task_name: $wf_task_name, wf_role: $wf_role - [lang::message::lookup "" intranet-core.Db_Error "x"] $errorInfo"
	    return
	}

	ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_permissions - question_id: $question_id, wf_task_name: $wf_task_name,  wf_role: $wf_role | $read_p $write_p $admin_p"
	return [list $read_p $write_p $admin_p]

    } else {
	# Access outside of WF: tbd 
	# Check if one of the employees supervisors requires read access 
        # set supervisor_list [im_custom_champ_get_all_supervisors $user_id]  
	return [list 0 0 0]
    }
}


proc_doc im_employee_evaluation_question_display {
    question_id
    employee_id
    wf_task_name 
    { edit_previous_response_p "f" }  
} { 
    Returns a string of HTML to display for a question, suitable for embedding in a form.
    The form variable is of the form \"response_to_question.\$question_id
    
} {

    template::head::add_javascript -src "http://code.jquery.com/ui/1.8.0/jquery-ui.js" -order 9990
    template::head::add_css -href "http://code.jquery.com/ui/1.8.0/themes/smoothness/jquery-ui.css" -media "screen" -order 9980
    template::head::add_css -href "/intranet-employee-evaluation/css/intranet-employee-evaluation.css" -media "screen" -order 9900

    set user_id [auth::get_user_id]
    ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display"
    ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display"
    ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display ****** Enter -question_id: $question_id, employee_id:$employee_id, user_id: $user_id, wf_task_name: $wf_task_name"

    # Check if we have already an answer 
    set sql "
    select 
    	count(*) 
    from 
    	survsimp_responses r,
    	survsimp_question_responses qr
    where 
    	qr.response_id = r.response_id 
    	and related_object_id = :employee_id
    	and qr.question_id = :question_id
    "

    if { [db_string get_responses $sql -default 0] } {
	set edit_previous_response_p "t"
    }

    if { "" != $wf_task_name } {
	# Access within WF
	if { $employee_id == $user_id } {
	    set permission_list [im_employee_evaluation_question_permissions -wf_task_name $wf_task_name -wf_role "Employee" $question_id $employee_id]	    
	} else {
	    set permission_list [im_employee_evaluation_question_permissions -wf_task_name $wf_task_name -wf_role "Supervisor" $question_id $employee_id]	    	    
	}
    }

    regsub -all {t} $permission_list 1 permission_list
    regsub -all {f} $permission_list 0 permission_list
    ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display - edit_previous_response_p: $edit_previous_response_p, permission_list: $permission_list"   

    set visible_p [lindex $permission_list 0]
    set writeable_p [lindex $permission_list 1]

    set element_name "response_to_question.$question_id"

    # Get general QDetails 
    db_1row survsimp_question_properties "
        select
                survey_id,
                sort_key,
                question_text,
                abstract_data_type,
                required_p,
                active_p,
                presentation_type,
                presentation_options,
                presentation_alignment,
                creation_user,
                creation_date
        from
                survsimp_questions, acs_objects
        where
                object_id = question_id
                and question_id = :question_id
    "
    ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display question_text: $question_text - visible_p: $visible_p, writeable_p: $writeable_p"

    set html ""

    if { $presentation_alignment == "below" } {
        # append html "<br>"
    } else {
        append html " "
    }

    set user_value ""

    if {$edit_previous_response_p == "t"} {
        set user_id [ad_get_user_id]

        set prev_response_query "
        select
                choice_id,
                boolean_answer,
                clob_answer,
                number_answer,
                varchar_answer,
                date_answer,
                attachment_file_name
        from
                survsimp_question_responses
        where
                question_id = :question_id
                and response_id in (
                        select  max(r.response_id)
                        from    survsimp_question_responses qr,
				survsimp_responses r 
                        where   
				r.response_id = qr.response_id
				and qr.question_id = :question_id
                                and r.related_object_id = :employee_id
                )
        "

        set count 0
        db_foreach survsimp_response $prev_response_query {
            incr count
            if {$presentation_type == "checkbox"} {
                set selected_choices($choice_id) "t"
            }
        } if_no_rows {
            set choice_id 0
            set boolean_answer ""
            set clob_answer ""
            set number_answer ""
            set varchar_answer ""
            set date_answer ""
            set attachment_file_name ""
        }
    }

    # Verify: Does "if_no_rows" fail ?
    if { ![info exists choice_id] } {
	set choice_id 0
    }


   ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display presentation_type: $presentation_type, visible_p: $visible_p, writeable_p: $writeable_p"

 
   switch -- $presentation_type {
        "none" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span>"
        }
        "combined_type_one" {
            if {[catch {
		if { $visible_p } {
		    append html [create_html_combined_type_one $question_id $employee_id $wf_task_name]
		} else {
		    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}
            } err_msg]} {
                append html "Presentation type not supported, please install package \]po\[ Employee Evaluation"
                ad_return_complaint xx $err_msg
            }
        }
       "combined_type_two" {
	   if {[catch {
	       if { $visible_p } {
		   append html [create_html_combined_type_two $question_id $employee_id $wf_task_name]
	       } else {
		   append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	       }
	   } err_msg]} {
	       append html "Presentation type not supported, please install package \]po\[ Employee Evaluation"
                ad_return_complaint xx $err_msg
	   }
       }
        "upload_file"  {
            if {$edit_previous_response_p == "t"} {
                set user_value $attachment_file_name
            }
            append html "<input type=file name=$element_name $presentation_options>"
        }
        "textbox" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>"
            if {$edit_previous_response_p == "t"} {
                if {$abstract_data_type == "number" || $abstract_data_type == "integer"} {
                    set user_value $number_answer
                } else {
                    # set user_value $varchar_answer
                    set user_value $clob_answer
                }
            }
	    if { $visible_p } {
                if { $writeable_p } {
		    append html "<input type=text name=$element_name id=$element_name value=\"[philg_quote_double_quotes $user_value]\" [ad_decode $presentation_options "large" "size=70" "medium" "size=40" "size=10"]>"
		    if { [string first "date" [string tolower $question_text]] != -1 } {
			append html "&nbsp;<input style=\"height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');\" onclick=\"return showCalendar('$element_name', 'y-m-d');\" type=\"button\">"
		    }
                } else {
		    append html "<input type=text readonly style='background-color:#cccccc;' name=$element_name value=\"[philg_quote_double_quotes $user_value]\" [ad_decode $presentation_options "large" "size=70" "medium" "size=40" "size=10"]>"
                }
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    } 
        }
        "textarea" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>"
            if {$edit_previous_response_p == "t"} {
                if {$abstract_data_type == "number" || $abstract_data_type == "integer"} {
                    set user_value $number_answer
                } elseif { $abstract_data_type == "shorttext" } {
                    set user_value $varchar_answer
                } else {
                    set user_value $clob_answer
                }
            }

            if { $visible_p } {
		if { $writeable_p } {
		    append html "<textarea name=$element_name $presentation_options>$user_value</textarea>"
		} else {
		    append html "<textarea style='background-color:#cccccc;' $presentation_options readonly>$user_value</textarea>"
		}
            } else {
                append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
            }
        }
        "date" {
            if {$edit_previous_response_p == "t"} {
                set user_value $date_answer
            }
            if { $visible_p } {
		append html "[ad_dateentrywidget $element_name $user_value]"
            } else {
                append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
            }

        }
        "select" {
            if { $abstract_data_type == "boolean" } {
                if {$edit_previous_response_p == "t"} {
                    set user_value $boolean_answer
                }
		if { $visible_p } {
			append html "
	                <select name=$element_name>
        	         <option value=\"\">[lang::message::lookup "" simple-survey.Select_One "Select One"]</option>
                	 <option value=\"t\" [ad_decode $user_value "t" "selected" ""]>True</option>
	                 <option value=\"f\" [ad_decode $user_value "f" "selected" ""]>False</option>
        	        </select>
                        "
		} else {
		    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}
            } else {
		append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>" 
                if {$edit_previous_response_p == "t"} {
                    set user_value $choice_id
		    if { "" == $user_value } {
			set user_value [lang::message::lookup "" intranet-employee-avaluation.Empty "Not provided"]
		    } 
                }
		ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display select - not boolean - user_value: $user_value"
                if { $visible_p } {
		    if { $writeable_p } {
			append html "
                	<select name=$element_name>
	                <option value=\"\">[lang::message::lookup "" simple-survey.Select_One "Select One"]</option>
        	        "
			db_foreach survsimp_question_choices "select choice_id, label from survsimp_question_choices where question_id = :question_id order by sort_order" {
			    if { $user_value == $choice_id } {
				append html "<option value=$choice_id selected>$label</option>\n"
			    } else {
				append html "<option value=$choice_id>$label</option>\n"
			    }
			}
			append html "</select>"
		    } else {
			set choice_label [db_string get_select_value "select label from survsimp_question_choices where choice_id = :choice_id" -default ""]
			if { "" != $choice_label } {
			    append html $choice_label
			} else {
			    append html [lang::message::lookup "" intranet-employee-evaluation.NoAnswerProvided "No answer provided"]		    
			}
		    }
		} else {
                    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}

            }
        }

        "radio" {
            if { $abstract_data_type == "boolean" } {

                if {$edit_previous_response_p == "t"} { set user_value $boolean_answer }
                set choices [list \
				 "<input type=radio name=$element_name value=t [ad_decode $user_value "t" "checked" ""]> True" \
				 "<input type=radio name=$element_name value=f [ad_decode $user_value "f" "checked" ""]> False" \
				 ]

            } else {
                if {$edit_previous_response_p == "t"} { set user_value $choice_id }

                set choices [list]
                db_foreach sursimp_question_choices_2 "
                        select  choice_id, label
                        from    survsimp_question_choices
                        where   question_id = :question_id
                        order by sort_order
                " {
                    if { $user_value == $choice_id } {
                        lappend choices "<input type=radio name=$element_name value=$choice_id checked> $label"
                    } else {
                        lappend choices "<input type=radio name=$element_name value=$choice_id> $label"
                    }
                }
            }

	    if { $visible_p } {
		if { $presentation_alignment == "beside" } {
		    append html [join $choices " "]
		} else {
		    append html "<blockquote>\n[join $choices "<br>\n"]\n</blockquote>"
		}
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    }
        }

        "checkbox" {
            set choices [list]
            db_foreach sursimp_question_choices_3 "
                select * from survsimp_question_choices
                where question_id = :question_id
                order by sort_order
                " {

                    if { [info exists selected_choices($choice_id)] } {
                        lappend choices "<input type=checkbox name=$element_name value=$choice_id checked> $label"
                    } else {
                        lappend choices "<input type=checkbox name=$element_name value=$choice_id> $label"
                    }
                }
            if { $visible_p } {
		if { $presentation_alignment == "beside" } {
		    append html [join $choices " "]
		} else {
		    append html "<blockquote>\n[join $choices "<br>\n"]\n</blockquote>"
		}
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    }
        }
    }
    return "$html</br>"
}


ad_proc -public im_employee_evaluation_supervisor_component {
    current_user_id
} {
    Provides links and status information for Employee Evaluation
} {

    # Check if current user is supervisor of an employee
    set number_direct_reports [db_string get_number_direct_reports "select count(*) from im_employees where supervisor_id = :current_user_id" -default 0]
    if { 0 == $number_direct_reports } {return "" }

    set project_id [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "CurrentEmployeeEvaluationProjectId" -default 0]
    set survey_name [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "SurveyName" -default ""] 
    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]
    set transition_name_printing [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "TransitionNamePrinting" -default ""]

    set html_lines ""
    set deadline_employee_evaluation ""
    set start_date ""
    set end_date ""

    if { 0 == $project_id } { ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.NoProjectIdFound "No current Project Id found, please contact your System Administrator"] }
    if { "" == $survey_name } { ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.NoSurveyNameFound "No Survey Name found, please contact your System Administrator"] }

    
    if {[catch {
        db_1row get_project_data "
		select 
	        	project_name, 
			to_char(start_date, 'YYYY-MM-DD') as start_date_pretty, 
			to_char(end_date, 'YYYY-MM-DD') as end_date_pretty, 
			to_char(deadline_employee_evaluation, 'YYYY-MM-DD') as deadline_employee_evaluation_pretty 
		from im_projects where project_id = :project_id"
    } err_msg]} {
        global errorInfo
        ns_log Error $errorInfo
        return "Can't show PORTLET. [lang::message::lookup "" intranet-core.Db_Error "Database error:"] $errorInfo"
    }

    # Get directs 
    set sql "
	select 
		employee_id, 
		im_name_from_user_id(employee_id, :name_order) as name
	from 
		im_employees
	where 
		supervisor_id = :current_user_id	

    "
    db_foreach rec $sql {

       # Check if a WF had been started already
       set sql "
                select
                        employee_evaluation_id,
                        case_id
                from
                        im_employee_evaluations
                where
                        project_id = :project_id and
                        employee_id = :employee_id
       "

       if {[catch {
            db_1row get_employee_evaluation_id $sql
       } err_msg]} {
           set employee_evaluation_id 0
           set case_id 0
       }

       append html_lines "<tr>" 
       append html_lines "<td>$name</td>" 
       if { 0 != $employee_evaluation_id } {
	   # Button Continue/Nothing to do 
	   set sql "select task_id from wf_task_assignments where task_id in (select task_id from wf_tasks where case_id = :case_id and state = 'enabled') and party_id = :current_user_id"
	   set current_task_id [db_string get_task_id $sql -default 0]
	   if { 0 != $current_task_id } {
	       set continue_btn "<button style='margin-top:-10px' onclick=\"location.href='/acs-workflow/task?task_id=$current_task_id'\">Next step</button>"
	   } else {
	       set continue_btn [lang::message::lookup "" intranet-employee-evaluation.WaitingForEmployee "Waiting"]
	   }
           append html_lines "<td>$continue_btn</td>"

	   # Button 'Print'
	   set print_link "/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$employee_evaluation_id&transition_name_to_print=$transition_name_printing"
	   append html_lines "<td><button style='margin-top:-10px' onclick=\"location.href='$print_link'\">[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</button></td>"
       } else {
	   set start_link "/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id&employee_id=$employee_id&survey_name=$survey_name"
	   append html_lines "<td><button style='margin-top:-10px' onclick=\"location.href='$start_link'\">[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</button></td>"
	   append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]</td>"
       }
       append html_lines "</tr>" 
    }
 
    set html "
	<!--[lang::message::lookup "" intranet-employee-evaluation.TitlePortletSupervisor "Please manage the Employee Performance Evaluation of your Direct Reports from here."]<br/>-->
	<table cellpadding='0' cellspacing='0' border='0'>
	<tr>
	<td>[lang::message::lookup "" intranet-core.StartDate "Start Date"]:</td>
	<td>$start_date_pretty</td>
	</tr>
	<tr>
	<td>[lang::message::lookup "" intranet-core.EndDate "End Date"]:</td>
	<td>$end_date_pretty</td>
	</tr>
	<tr>
	<td>[lang::message::lookup "" intranet-employee-evaluation.Deadline "Deadline"]:</td>
	<td>$deadline_employee_evaluation_pretty</td>
	</tr>
	</table>

	<table cellpadding='5' cellspacing='5' border='0'>
		<tr class='rowtitle'>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Name"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Action "Action"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</td>
		</tr>
		$html_lines
	</table>
    "
    return $html
}


ad_proc -public im_employee_evaluation_employee_component {
    current_user_id
} {
    Provides links and status information for current and past 'Employee Performance Evaluations'.
    Current transition name to be printed is required in order to create the 'Print' link.  
} {

    set project_id [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "CurrentEmployeeEvaluationProjectId" -default 0]
    set survey_name [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "SurveyName" -default ""] 
    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]
    set transition_name_printing [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "TransitionNamePrinting" -default ""]
    set workflow_key [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "WorkflowKey" -default ""]

    # Init  
    set start_date "" 
    set end_date "" 
    set deadline_employee_evaluation ""
    set case_id -1

    if { 0 == $project_id } { return [lang::message::lookup "" intranet-employee-evaluation.NoProjectIdFound "Can not show PORTLET, Parameter 'CurrentEmployeeEvaluationProjectId' of package 'intranet-employee-evaluation' not found. Please contact your System Administrator."] }
    if { "" == $survey_name } { return [lang::message::lookup "" intranet-employee-evaluation.NoSurveyNameFound "Can not show PORTLET, Parameter 'SurveyName' of package 'intranet-employee-evaluation' not found. Please contact your System Administrator."] }
    if { "" == $transition_name_printing } { return [lang::message::lookup "" intranet-employee-evaluation.ParameterTransitionNamePrintingNotFound "Can not show PORTLET, Parameter 'TransitionNamePrinting' not found. Please contact your System Administrator."] }
    if { "" == $workflow_key } { return [lang::message::lookup "" intranet-employee-evaluation.ParameterWorkflowKeyNotFound "Can not show PORTLET, Parameter 'WorkflowKey' of package 'intranet-employee-evaluation' not found. Please contact your System Administrator."] }

    # Additional Sanity checks: Check if transition exists: 
    if { ![db_string sanity_check_wf_transition "select count(*) from wf_transitions where workflow_key = :workflow_key and transition_name = :transition_name_printing" -default ""] } {
	return [lang::message::lookup "" intranet-employee-evaluation.WorkflowMissesTransition. "Can not show PORTLET. No transition: '$transition_name_printing' in workflow: '$workflow_key' found. Please contact your System Administrator."]
    }
    
    set html_lines ""

    # Check if a WF had been started already
    set sql "
                select
                        employee_evaluation_id,
                        case_id
                from
                        im_employee_evaluations
                where
                        project_id = :project_id and
                        employee_id = :current_user_id
    "

    if {[catch {
	db_1row get_employee_evaluation_id $sql
    } err_msg]} {
	set employee_evaluation_id 0
	set case_id 0
    }


    if {[catch {
        db_1row get_project_data "select project_name, start_date, end_date, to_char(deadline_employee_evaluation, 'YYYY-MM-DD') as deadline_employee_evaluation from im_projects where project_id = :project_id"
    } err_msg]} {
        global errorInfo
        ns_log Error $errorInfo
        return "Can't show PORTLET. [lang::message::lookup "" intranet-core.Db_Error "Database error:"] $errorInfo"
    }

    # Status 
    set current_task_id [db_string get_task_id "select task_id from wf_task_assignments where task_id in (select task_id from wf_tasks where case_id = :case_id and state = 'enabled') and party_id = :current_user_id" -default 0] 

    if { 0 != $current_task_id } {
        set wf_button "<button style='margin-top: -10px' onclick=\"location.href='/acs-workflow/task?task_id=$current_task_id'\">Next step</button>"
    } else {
	set wf_button [lang::message::lookup "" intranet-employee-evaluation.NoAssignment "You are currently not assigned to a Workflow Task"]
    }

    # Print Button 
    if { 0 != $employee_evaluation_id } {
	set print_button "
                <form action='/intranet-employee-evaluation/print-employee-evaluation' method='POST' target='_blank'>
                <input type='hidden' name= 'transition_name_to_print' value='$transition_name_printing'>
                <input type='hidden' name= 'employee_evaluation_id' value='$employee_evaluation_id'>
                <input type='submit' value='[lang::message::lookup "" intranet-employee-evaluation.Print Print]'>
                </form>
        "
    } else {
	set print_button "[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]"
    }

    append html_lines "<tr>" 
    append html_lines "<td>$project_name <br/> [lang::message::lookup "" intranet-employee-evaluation.ToBeFinishedBy "Deadline"]: $deadline_employee_evaluation</td>" 
    append html_lines "<td>$wf_button</td>"
    append html_lines "<td>$print_button</td>"
    append html_lines "</tr>" 
 
    set html "
	<table cellpadding='5' cellspacing='5' border='0'>
		<tr class='rowtitle'>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.CurrentProject "Current Employee Evaluation Project"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Status"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</td>
		</tr>
		$html_lines
	</table>
    "
    return $html
}

ad_proc -public im_employee_evaluation_statistics_current_project {
    current_user_id
} {
    Provides statistical data about progress of current survey 
} {

    set project_id [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "CurrentEmployeeEvaluationProjectId" -default 0]
    set survey_name [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "SurveyName" -default ""]
    set wf_key [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "WorkflowKey" -default ""]

    if { 0 == $project_id } { ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.NoProjectIdFound "No current Project Id found, please contact your System Administrator"] }
    if { "" == $survey_name } { ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.NoSurveyNameFound "No Survey Name found, please contact your System Administrator"] }


    # Total participants 
    set sql "
    	select
		count(*)
		-- rels.object_id_two as user_id, 
		-- rels.object_id_two as party_id, 
		-- im_email_from_user_id(rels.object_id_two) as email,
		-- im_name_from_user_id(rels.object_id_two, 1) as name
	from
		acs_rels rels
		LEFT OUTER JOIN im_biz_object_members bo_rels ON (rels.rel_id = bo_rels.rel_id)
		LEFT OUTER JOIN im_categories c ON (c.category_id = bo_rels.object_role_id)
	where
		rels.object_id_one = :project_id and
		rels.object_id_two in (select party_id from parties) and
		rels.object_id_two not in (
		   -- Exclude banned or deleted users
		   select     m.member_id
		   from     group_member_map m,
		   membership_rels mr
		   where     m.rel_id = mr.rel_id and
		   m.group_id = acs__magic_object_id('registered_users') and
		   m.container_id = m.group_id and
		   mr.member_state != 'approved'
		) 
		and rels.object_id_two in (select member_id from group_distinct_member_map m where group_id = [im_employee_group_id]);
    "
    set total_participants [db_string get_total_participants $sql -default 0]

    # Statistics 'Places'
    set sql "
      select 
	 (select place_name from wf_places where place_key = t.place_key) as place_name,
	 count(*) as amount
      from 
    	 wf_tokens t
      where 
          state = 'free' 
    	  and t.workflow_key = :wf_key
    	  and t.case_id in (
	      select distinct case_id from im_employee_evaluations where project_id = :project_id
    	  )
     group by 
     	   place_name
     order by 
	   amount
     "

    set status_table_html "<table cellpadding='0' cellspacing='0' border='0'>"

    db_foreach r $sql {
	if { 0 != $amount } {
	    set percentage [expr 100 * $amount / $total_participants]
	} else {
	    set percentage 0 
	}
	append status_table_html "<tr>
		<td>[lang::message::lookup "" intranet-employee-evaluation.WfPlaceName "Place"]</td>
       		<td>[lang::message::lookup "" intranet-employee-evaluation.Number cases "Number Cases"]</td>
		<td>$percentage %</td>
	</tr>"
    }
    append status_table_html "</table>"
    set html "
        <table cellpadding='5' cellspacing='5' border='0'>
                <tr class='rowtitle'>
                        <td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Project "Project"]</td>
                        <td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Status"]</td>
                        <td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Link "Link"]</td>
                </tr>
                <tr>
                        <td>Employee Evaluation</td>
                        <td>-</td>
                        <td><a href='/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id&survey_name=$survey_name'>[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</a></td>
                </tr>
        </table>
    "
    return $html
}



