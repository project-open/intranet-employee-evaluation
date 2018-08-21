# /packages/intranet-employee-evaluation/www/employee-evaluation-detailed-report.tcl
#
# Copyright (C) 2003 - 2015 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {

    Custom implementation for customer who sponsored development. We decided to make this report
    part of the ee-package. THis way it does not get lost in some intranet-cust-* package. 
    Only minor adjustments necessary to make that work for generic EE Reports 
} {
    { user_id 0 }
    { new_global_division_id 0 }
    { new_sub_division_id 0 }
    { user_supervisor_id 0 }
    { l3_director_id 0 }
    { employee_evaluation_process_id 0 }
    { location_id 0 }
    { output_format "html" }
}

# ------------------------------------------------------------
# Security & Permissions
# ------------------------------------------------------------

# Label: Provides the security context for this report
set menu_label "employee-evaluation-detailed-report"
set current_user_id [ad_maybe_redirect_for_registration]

set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

# REMOVE 
set read_p t 

if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------
set debug 0
set employee_group_id [im_employee_group_id]
set page_title [lang::message::lookup "" intranet-reporting.TimesheetMonthlyViewIncludingAbsences "Employee Evaluations"]
set context_bar [im_context_bar $page_title]

# Dropdown EE Processes 
foreach option_pair [db_list_of_lists get_evaluation_projects "select id, name from im_employee_evaluation_processes"] {
    lappend ee_process_options [lindex $option_pair 0] [lindex $option_pair 1]
}

# Get survey_id 
set sql "
	select 
		s.survey_id
	from 
		survsimp_surveys s, 
		im_employee_evaluation_processes ep
	where 
		ep.id = :employee_evaluation_process_id
		and ep.survey_name = s.name

"
set survey_id [db_string get_survey_id $sql -default 0]

# If none found (GET), set by default last one 
if { 0 == $survey_id } {
    set sql "
	select
                s.survey_id,
		ep.id as employee_evaluation_process_id
        from
                survsimp_surveys s,
                im_employee_evaluation_processes ep
        where
                ep.survey_name = s.name
	order by 
		s.survey_id ASC
	limit 1
    "
    if { 0 == [db_0or1row get_survey_id $sql] } {
	 ad_return_complaint xx "No Employee Evaluation processes found"
    }
}

# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
 
set criteria [list]

# Global Division Filter 
if { 0 != $new_global_division_id && "" != $new_global_division_id } {
    lappend criteria "e.new_global_division_id = :new_global_division_id"
}

# Sub Division Filter 
if { 0 != $new_sub_division_id && "" != $new_sub_division_id } {
    lappend criteria "e.new_sub_division_id = :new_sub_division_id"
}

# Director Filter
if { 0 != $l3_director_id && "" != $l3_director_id } {
    lappend criteria "e.l3_director_id = :l3_director_id"
}

# Supervisor Filter
if { 0 != $user_supervisor_id && "" != $user_supervisor_id } {
    lappend criteria "e.supervisor_id = :user_supervisor_id"
}

# Employee Filter
if { 0 != $user_id && "" != $user_id } {
    lappend criteria "e.employee_id = :user_id"
}

# Location Filter
if { 0 != $location_id && "" != $location_id } {
    lappend criteria "e.location_id = :location_id"
}

# Put everything together
set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set sql ""

# ------------------------------------------------------------
# Create main sql 

# KH: Custom implementation for customer who sponsored development I decided to make this report
# part of the ee-package so that the report doesn't get lost in some custom package

if {[catch {
    set user_is_vp_or_dir_p [db_string get_data "select count(*) from im_employees where l2_vp_id = :current_user_id OR l3_director_id = :current_user_id limit 1" -default 0]
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    set user_is_vp_or_dir_p 0
}

if { !$user_is_vp_or_dir_p } {
    # current user is not in L2/L3, simply show direct reports and user himself
    set main_sql "
        select
              cc.party_id as employee_id,
              cc.first_names,
              cc.last_name,
	      e.supervisor_id as supervisor_id_from_db,
	      e.l3_director_id as l3_director_id_from_db,
              (select im_name_from_user_id(e.supervisor_id,2)) as supervisor_name,
              (select im_category_from_id(e.new_global_division_id)) as new_global_division,
              (select im_category_from_id(e.new_sub_division_id)) as new_sub_division,
              (select im_name_from_user_id(e.l2_vp_id,2)) as vice_president_name,
              (select im_name_from_user_id(e.l3_director_id,2)) as director_name,
	      (select im_category_from_id(e.role_function_id)) as role_function,
	      (select im_category_from_id(e.location_id)) as location,
              (select im_category_from_id(e.contractor_permanent_id)) as contractor_permanent,
              (select im_category_from_id(e.employee_champ_entity_id)) as employee_champ_entity
        from
              cc_users cc,
              acs_rels r,
              membership_rels mr,
              im_employees e
        where
              r.object_id_one = :employee_group_id
              and r.object_id_two = cc.party_id
              and r.rel_type = 'membership_rel'
              and r.rel_id = mr.rel_id
              and cc.member_state = 'approved'
              and e.employee_id = cc.party_id
              and e.supervisor_id = :current_user_id

        UNION

        select
              cc.party_id as employee_id,
              cc.first_names,
              cc.last_name,
	      e.supervisor_id as supervisor_id_from_db,
	      e.l3_director_id as l3_director_id_from_db,
              (select im_name_from_user_id(e.supervisor_id,2)) as supervisor_name,
              (select im_category_from_id(e.new_global_division_id)) as new_global_division,
              (select im_category_from_id(e.new_sub_division_id)) as new_sub_division,
              (select im_name_from_user_id(e.l2_vp_id,2)) as vice_president_name,
              (select im_name_from_user_id(e.l3_director_id,2)) as director_name,
	      (select im_category_from_id(e.role_function_id)) as role_function,
	      (select im_category_from_id(e.location_id)) as location,
              (select im_category_from_id(e.contractor_permanent_id)) as contractor_permanent,
              (select im_category_from_id(e.employee_champ_entity_id)) as employee_champ_entity
        from
              cc_users cc,
              im_employees e
        where
              party_id = :current_user_id and
              cc.party_id = e.employee_id
        order by
              last_name,
              first_names
    "
} else {
    # Show all 'Direct Reports' and all users with current user as VP or Director
    set main_sql "
        select
              cc.party_id as employee_id,
              cc.first_names,
              cc.last_name,
	      e.supervisor_id as supervisor_id_from_db,
	      e.l3_director_id as l3_director_id_from_db,
              (select im_name_from_user_id(e.supervisor_id,2)) as supervisor_name,
              (select im_category_from_id(e.new_global_division_id)) as new_global_division,
              (select im_category_from_id(e.new_sub_division_id)) as new_sub_division,
              (select im_name_from_user_id(e.l2_vp_id,2)) as vice_president_name,
              (select im_name_from_user_id(e.l3_director_id,2)) as director_name,
	      (select im_category_from_id(e.role_function_id)) as role_function,
	      (select im_category_from_id(e.location_id)) as location,
              (select im_category_from_id(e.contractor_permanent_id)) as contractor_permanent,
              (select im_category_from_id(e.employee_champ_entity_id)) as employee_champ_entity
        from
              cc_users cc,
              acs_rels r,
              membership_rels mr,
              im_employees e
        where
              r.object_id_one = :employee_group_id
              and r.object_id_two = cc.party_id
              and r.rel_type = 'membership_rel'
              and r.rel_id = mr.rel_id
              and cc.member_state = 'approved'
              and e.employee_id = cc.party_id
              and (e.supervisor_id = :current_user_id OR e.l2_vp_id = :current_user_id OR e.l3_director_id = :current_user_id)
              $where_clause
        order by
              last_name,
              first_names
    "
}

# Current User is SysAdmin or HR Manager - show all
if { [im_is_user_site_wide_or_intranet_admin $current_user_id] || [im_user_is_hr_p $current_user_id] } {
    set main_sql "
        select
              cc.party_id as employee_id,
              cc.first_names,
              cc.last_name,
	      e.supervisor_id as supervisor_id_from_db,
	      e.l3_director_id as l3_director_id_from_db,
              (select im_name_from_user_id(e.supervisor_id,2)) as supervisor_name,
              (select im_category_from_id(e.new_sub_division_id)) as new_sub_division,
              (select im_category_from_id(e.new_global_division_id)) as new_global_division,
              (select im_name_from_user_id(e.l2_vp_id,2)) as vice_president_name,
              (select im_name_from_user_id(e.l3_director_id,2)) as director_name,
	      (select im_category_from_id(e.role_function_id)) as role_function,
	      (select im_category_from_id(e.location_id)) as location,
              (select im_category_from_id(e.contractor_permanent_id)) as contractor_permanent,
              (select im_category_from_id(e.employee_champ_entity_id)) as employee_champ_entity
        from
              cc_users cc,
              acs_rels r,
              membership_rels mr,
              im_employees e
        where
              r.object_id_one = :employee_group_id
              and r.object_id_two = cc.party_id
              and r.rel_type = 'membership_rel'
              and r.rel_id = mr.rel_id
              and cc.member_state = 'approved'
              and e.employee_id = cc.party_id
              $where_clause
        order by
              last_name,
              first_names
    "
}

# If first time request do not pull any records to avoid long loading 
if { "" == [ns_conn query] } { set main_sql "select * from dual where 0=1" }

# ------------------------------------------------------------
# Output 
# ------------------------------------------------------------

# HEADER --------------------------------------------------------------------------------------------------

set html_table "
	<table border=0 class='table_list_simple'>\n
	<tr valign='top' class='rowtitle'>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.EmployeeName "Name"]</td>
        <td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Global-Divison "Global-Division"]</td>
        <td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Sub-Divison "Sub-Division"]</td>
        <td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.DirectorName "Director"]</td>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.SupervisorName "Supervisor"]</td>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.RoleFunction "Role Function"]</td>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Location "Location"]</td>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.ContractPermanent "Contract/Permanent"]</td>
	<td valign='top' class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.ChampEntity "Champ Entity"]</td>
"
set csv_output_debug "\"\";\"\";\"\";\"\";\"\";"
set csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.EmployeeName "Name"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.Global-Divison "Global-Division"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.Sub-Divison "Sub-Division"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.DirectorName "Director"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.SupervisorName "Supervisor"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.RoleFunction "Role Function"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.Location "Location"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.ContractPermanent "Contract/Permanent"]\";"
append csv_output "\"[lang::message::lookup "" intranet-employee-evaluation.ChampEntity "Champ Entity"]\";"


set question_list [list]

# set sql "
#        select
#                gqm.question_id,
#                ssq.question_text,
#                ssq.question_text_beautified
#        from
#                im_employee_evaluation_panel_group_map pgm,
#                im_employee_evaluation_group_questions_map gqm,
#                im_employee_evaluation_groups g,
#                survsimp_questions ssq
#        where
#                gqm.group_id = g.group_id and
#                pgm.wf_task_name = (select transition_name_printing from im_employee_evaluation_processes where id = :employee_evaluation_process_id) and
#                pgm.survey_id = :survey_id and
#                pgm.group_id = g.group_id and
#                ssq.question_id = gqm.question_id
#        order by
#                ssq.sort_key
#        "

set sql "
	select 
		distinct gqm.question_id, 
		(select question_text from survsimp_questions where question_id = gqm.question_id) as question_text,
		(select question_text_beautified from survsimp_questions where question_id = gqm.question_id) as question_text_beautified
	from 
		im_employee_evaluation_panel_group_map pgm INNER JOIN im_employee_evaluation_group_questions_map gqm ON pgm.group_id = gqm.group_id 
	where 
		pgm.survey_id = :survey_id 
		AND pgm.wf_task_name = (select transition_name_printing from im_employee_evaluation_processes where id = :employee_evaluation_process_id)
	order by 
		question_id
"


db_foreach r $sql {

    # Check for subquestions 
    set sql_inner "
	select 
		child_question_id, 
		ssq_inner.question_text as question_text_inner,
		ssq_inner.question_text_beautified as question_text_beautified_inner
	from 
		im_employee_evaluation_questions_tree t, 
		survsimp_questions ssq_inner 
	where 
		t.child_question_id = ssq_inner.question_id
		and t.parent_question_id = :question_id
    "

    db_foreach s $sql_inner {
	# Debug
	# if { "" == $question_text_beautified } { set question_text_beautified "($question_id)" }
	# if { "" == $question_text_beautified_inner } { set question_text_beautified_inner "($child_question_id)" }
        append html_table "<td title='$child_question_id - $question_text_inner' class='rowtitle'>$question_text_beautified<br/>---<br/>$question_text_beautified_inner</td>"
        append csv_output "\"[im_report_quote_cell -encoding "" -output_format csv "$question_text_beautified -- $question_text_beautified_inner"]\";"
	lappend question_list $child_question_id
    } if_no_rows {
	append html_table "<td title='$question_id - $question_text' class='rowtitle'>$question_text_beautified</td>"
	append csv_output "\"[im_report_quote_cell -encoding "" -output_format csv "$question_text_beautified"]\";"
	lappend question_list $question_id
    }
    append csv_output_debug "\"$question_id\";"
}

append html_table "</tr>"
set csv_output "[string replace $csv_output end end]\r\n"
# append csv_output "$csv_output_debug\n"

# RECORDS --------------------------------------------------------------------------------------------------

set answer_where_clause [join $question_list ","]

set ctr 0 
db_foreach rec $main_sql {

    ns_log Notice ""


    array set answer_arr [list]

    set employee_name_html "<a href='/intranet/users/view?user_id=$employee_id'>$last_name, $first_names</a>"
    set director_name_html "<a href='/intranet/users/view?user_id=$l3_director_id_from_db'>$director_name</a>"
    set supervisor_name_html "<a href='/intranet/users/view?user_id=$supervisor_id_from_db'>$supervisor_name</a>"

    append html_table "\n
        <tr>\n
                <td valign='top'>$employee_name_html</td>\n
                <td valign='top'>$new_global_division</td>\n
                <td valign='top'>$new_sub_division</td>\n
                <td valign='top'>$director_name_html</td>\n
                <td valign='top'>$supervisor_name_html</td>\n
                <td valign='top'>$role_function</td>\n
                <td valign='top'>$location</td>\n
                <td valign='top'>$contractor_permanent</td>\n
                <td valign='top'>$employee_champ_entity</td>\n

    "
    append csv_output "\"$last_name, $first_names\";\"$new_global_division\";\"$new_sub_division\";\"$director_name\";\"$supervisor_name\""
    append csv_output ";\"$role_function\";\"$location\";\"$contractor_permanent\";\"$employee_champ_entity\""

    # Set answer array 
    # order by "r.response_id ASC" ensures that the last response found becomes the relevant response
    set sql "
        select
                qr.question_id,
                replace(qr.clob_answer, ';', ',') as clob_answer,
                qr.number_answer,
		(select label from survsimp_question_choices where choice_id = qr.choice_id) as choice_label 
        from
                survsimp_question_responses qr,
                survsimp_responses r
        where
                qr.question_id in ($answer_where_clause)
                and qr.response_id = r.response_id
                and r.survey_id = :survey_id
                and r.related_object_id = :employee_id
	order by 
		r.response_id ASC
    "

    db_foreach r $sql {
	regsub -all {"} $clob_answer {'} clob_answer; #"
	regsub -all {[\u0000-\u001f\u007f]+} $clob_answer "" clob_answer
	regsub -all {[^\u0020-\u007e]+} $clob_answer "" clob_answer
	set answer_arr($question_id) [list $clob_answer $number_answer $choice_label]
    }  

    # Questions 
    foreach q $question_list {
	if { [info exists answer_arr($q)] } {
	    append html_table "<td valign='top'>[lindex $answer_arr($q) 0][lindex $answer_arr($q) 1][lindex $answer_arr($q) 2]</td>\n"
	    append csv_output ";\"[lindex $answer_arr($q) 0][lindex $answer_arr($q) 1][lindex $answer_arr($q) 2]\""
	} else {
            append html_table "<td valign='top'>&nbsp;</td>\n"
	    append csv_output ";\"\""
	}
    }

    append html_table "\n</tr>\n"
    set csv_output "[string replace $csv_output end end]\n" 
    incr ctr
    
    unset answer_arr
} if_no_rows {
    append html_table "<tr><td colspan='99'>[lang::message::lookup "" intranet-employee-evaluation.NoRecordsFound "No records found"]</td></tr>"
}


# / RECORDS --------------------------------------------------------------------------------------------------

append html_table "</table>"

# ad_return_complaint xx [array size [array get [ns_conn form]]]
if { "" == [ns_conn query] } {
     set html_table "<strong>[lang::message::lookup "" intranet-employee-evaluation.NoRecordsSelectedYet "No records selected yet, please set filters and submit form"]</strong>"
}


set html "
	[im_header]
	[im_navbar reporting]
	<table border=0 cellspacing=1 cellpadding=1>
		<tr>
			<td>
"

append html "
	<form>
	<table border=0 cellspacing=1 cellpadding=1>
               <tr>
                 <td class=form-label>[lang::message::lookup "" intranet-core.PerformanceEvaluation "Performance Evaluation"]</td>
                 <td class=form-widget>
                   [im_select employee_evaluation_process_id $ee_process_options $employee_evaluation_process_id]
                 </td>
               </tr>
                <tr>
                 <td class=form-label>[lang::message::lookup "" intranet-cust-champ.GlobalDivision "Global Division"]</td>
                 <td class=form-widget>
                   [im_category_select -include_empty_p 1 -include_empty_name "All" "Intranet New Global Division" new_global_division_id $new_global_division_id]
                </td>
               </tr>
               <tr>
                 <td class=form-label>[lang::message::lookup "" intranet-cust-champ.SubDivision "Sub Division"]</td>
                 <td class=form-widget>
                   [im_category_select -include_empty_p 1 -include_empty_name "All" "Intranet New Sub Division" new_sub_division_id $new_sub_division_id]
                 </td>
               </tr>
               <tr>
                 <td class=form-label>[lang::message::lookup "" intranet-cust-champ.Director "Director"]</td>
                 <td class=form-widget>
		    [im_cust_champ_director_select -include_empty_p 1 -include_empty_name "All" $l3_director_id]
                 </td>
               </tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-core.Supervisor "Supervisor"]</td>
		  <td class=form-widget>
		    [im_supervisor_select -include_empty_p 1 -include_empty_name "All" $user_supervisor_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-core.Employee "Employee"]</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 -include_empty_name "All" user_id $user_id]
		  </td>
		</tr>
                <tr>
                 <td class=form-label>[lang::message::lookup "" intranet-cust-champ.Location "Location"]</td>
                 <td class=form-widget>
                   [im_category_select -include_empty_p 1 -include_empty_name "All" "Intranet Location" location_id $location_id]
                </td>
               </tr>

	               <tr>
	                 <td class=form-label>[lang::message::lookup "" intranet-reporting.Format "Format"]</td>
	                 <td class=form-widget>
	                   [im_report_output_format_select output_format "" $output_format]
	                 </td>
	               </tr>
	               <tr>
	 		 <tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
	</table>
	</form>
"

append html "
		</td>
		<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td valign='top' width='600px'>
		</td>
		</tr>
		</table>
		$html_table
        	\n[im_footer]\n
" 

if { "csv" == $output_format } {
    im_report_write_http_headers -report_name $page_title -output_format $output_format
    ns_write $csv_output
    ad_script_abort
}
