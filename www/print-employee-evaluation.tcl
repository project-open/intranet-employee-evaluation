# /packages/intranet-employee-evaluation/www/print-employee-evaluation.tcl
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

ad_page_contract {
    This script allows printing the Employee Evaluation
    @param employee_evaluation_id
    @author klaus.hofeditz@project-open.com
} {
    employee_evaluation_id:integer 
    { transition_name_to_print "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set show_context_help_p 0
set current_user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set today [lindex [split [ns_localsqltimestamp] " "] 0]
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]
set cust_line_break_function [db_string get_data "select line_break_function from im_employee_evaluation_processes where status = 'Current'" -default ""]

# Get Employee Evaluation Data
# project_id,employee_id,supervisor_id,case_id,survey_id,workflow_key

if {[catch {
    db_1row get_employee_evaluation_data "
	select 
		ee.*,
		ep.evaluation_year,
		to_char(p.start_date, 'YYYY-MM-DD') as start_date_pretty,
		to_char(p.end_date,'YYYY-MM-DD') as end_date_pretty,
                to_char(p.deadline_employee_evaluation,'YYYY-MM-DD') as deadline_pretty,
		(select im_name_from_user_id(ee.employee_id, $name_order)) as employee_name,
		(select im_name_from_user_id(ee.supervisor_id, $name_order)) supervisor_name,
		(select im_category_from_id(e.location_id)) as employee_location,
		(select im_category_from_id(e.role_function_id)) as employee_position
	from 
		im_employee_evaluations ee,
		im_projects p,
		im_employees e,
		im_employee_evaluation_processes ep
	where 
		employee_evaluation_id = :employee_evaluation_id
		and p.project_id = ee.project_id 
		and e.employee_id = ee.employee_id 
		and ee.project_id = ep.project_id 
    "
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    ad_return_complaint 1 "[lang::message::lookup "" intranet-employee-evaluation.ProblemDBAccess "There was a problem accessing the database:"] $errorInfo"
}

# Permissions
if { !($current_user_id != $supervisor_id || $current_user_id != $employee_id) } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.NoPermission "You do not have the permission to view or print this evaluation."]
}

set overall_performance ""
set sql "
        select
                (select label from survsimp_question_choices where choice_id = qr.choice_id) as choice_label
        from
                survsimp_questions q,
                survsimp_question_responses qr,
                survsimp_responses r
        where
                lower(q.question_text) ~ lower('<strong>Overall Performance Score:</strong>')
                and q.question_id = qr.question_id
                and r.response_id = qr.response_id
                and r.related_object_id = :employee_id
                and r.survey_id = :survey_id
        order by
                r.response_id DESC
        limit 1
"

if {[catch {
    set overall_performance [db_string get_data $sql -default "not found"]
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    set overall_performance "not found"
}


# Set Role 
if { $current_user_id == $employee_id } {
    set role "Employee"
} else {
    set role "Supervisor"
}

# ---------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------

# WF Status 
# Check if WF exists of WF is closed 
# - While case is not finished, show content based on permissions set for WF transition 
# - If case is finished, show everything 

# Special case - Check if wf_case is finished. If so, all information is available to employees & supervisors
# If WF is still in progress, we have at least one task with state 'enabled'
set wf_in_progress_p 0
set wf_in_progress_p [db_string get_data "select count(*) from wf_tasks where case_id = :case_id and state = 'enabled'" -default 0]

if { "" != $transition_name_to_print } {
    set transition_keys [db_list get_transition_keys "select transition_key from wf_transitions where workflow_key = :workflow_key and transition_name = :transition_name_to_print"]
} else {
    if { $wf_in_progress_p } {
	# Get all transition_keys with state 'finished'
	set transition_keys [db_list get_transition_keys "select transition_key from wf_tasks where case_id = :case_id and state = 'finished' order by task_id"]
    } else {
	set transition_keys [db_list get_transition_keys "select transition_key from wf_tasks where case_id = :case_id order by task_id"]
    }
}


# ---------------------------------------------------------------
# Create output 
# ---------------------------------------------------------------

# Header

set html_output "
<table cellpadding='5' cellspacing='5' border='0' width='100%'>
        <tr>
                <td align='left'><img src='/logo.gif' alt='' /></td>
                <td><span style='font-size:1.5em;font-weight:bold'>CHAMP Cargosystems<br>PERFORMANCE REVIEW FORM</span></td>
                <td align='right'><span style='font-size:4em;font-weight:bold'>$evaluation_year</span></td>
        </tr>
</table>"

append html_output "
<table cellpadding='5' cellspacing='5' border='0'>
	<tr>
        	<td><strong>[lang::message::lookup "" intranet-employee-evaluation.Employee "Employee"]:</strong><br>$employee_name</td>
	        <td><strong>[lang::message::lookup "" intranet-employee-evaluation.PerformancePeriod "Performance Period"]:</strong><br>$start_date_pretty - $end_date_pretty</td>
		<td><strong>[lang::message::lookup "" intranet-employee-evaluation.DatePerformanceDialog "Date of Performance Dialog"]:</strong><br>_________________________</td>
	</tr>
		<tr><td colspan='3'>&nbsp;</td></tr>
	<tr>
        	<td><strong>[lang::message::lookup "" intranet-employee-evaluation.Position "Position"]:</strong><br>$employee_position</td>
        	<td><strong>[lang::message::lookup "" intranet-employee-evaluation.Location "Location"]:</strong><br>$employee_location</td>
        	<td><strong>[lang::message::lookup "" intranet-employee-evaluation.EvaluatingSupervisor "Evaluating Supervisor"]:</strong><br>$supervisor_name</td>
	<tr>
</table>
<table cellpadding='5' cellspacing='5' border='0'>
        <tr>
                <td colspan='2'><h1>Section 1: Performance Plan Signatures</h1></td>
        </tr>

        <tr>
                <td valign='top'>
			<strong>Performance Plan Signatures--Employee</strong><br>
			I understand my job and individual responsibilities, and my manager has discussed with me the performance expectations.<br><br><br>
		</td>
                <td valign='top'>

			<strong>Performance Plan Signatures--Supervisor/Manager</strong><br>
			I have discussed the job and individual responsibilities, performance expectations with the employee.<br><br><br>
		</td>
        </tr>
	<tr>
                <td valign='top'>
                        <strong>Signature:</strong> _________________________________<br><br>
			<strong>Date:</strong> _________________________________<br>
                </td>
                <td valign='top'>
                        <strong>Signature:</strong> _________________________________<br><br>
			<strong>Date:</strong> _________________________________<br>
                </td>
        </tr>
	<tr><td colspan='2'><br><br></td></tr>
        <tr>
                <td valign='top'>
                        <strong>Overall performance:</strong> $overall_performance<br>
                </td>
                <td valign='top'>
			<strong>Performance Plan Signatures--Supervisor/Manager N+1</strong><br><br>
                        <strong>Signature:</strong> _________________________________<br><br>
                        <strong>Date:</strong> _________________________________<br>
                </td>
        </tr>

</table>


<div class='page-break'></div>
"

foreach transition_key $transition_keys {
    ns_log NOTICE "intranet-ee::print-employee-evaluation - workflow_key: $workflow_key, transition_key: $transition_key" 
    set transition_name [db_string get_transition_name "select transition_name from wf_transitions where transition_key = :transition_key and workflow_key = :workflow_key" -default ""]
    ns_log NOTICE "intranet-ee::print-employee-evaluation - transition_name: $transition_name" 
    set sql "
	select
	      	gqm.question_id,
		ssq.question_text		
	from
      		im_employee_evaluation_panel_group_map pgm,
      		im_employee_evaluation_group_questions_map gqm,
      		im_employee_evaluation_groups g,
		survsimp_questions ssq
	where
      		gqm.group_id = g.group_id and
      		pgm.wf_task_name = :transition_name and
      		pgm.survey_id = :survey_id and
      		pgm.group_id = g.group_id and 
		ssq.question_id = gqm.question_id 
	order by 
		gqm.sort_key
    "
    db_foreach r $sql {
        ns_log NOTICE "intranet-ee::print-employee-evaluation - Writing question id: $question_id, employee_id: $employee_id, task_name:$transition_name"
	# Include page breaks 
	if { "" != $cust_line_break_function } {
	    append html_output [eval $cust_line_break_function $question_id {$question_text}]
	}
	append html_output [im_employee_evaluation_question_display $question_id $employee_id $transition_name "" "t"]
	# ns_log NOTICE "intranet-ee::print-employee-evaluation - question_html: \n [im_employee_evaluation_question_display $question_id $employee_id $transition_name ""]"
    }
}
append html_output "</table>"

