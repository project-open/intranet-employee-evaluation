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
   
    This script allows printing the Employee Evaluation based on WF status. 
    
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
set last_transition "Stage 6: Supervisor finishing"
set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

# Permission
# Access is granted to employee, his/her supervisor or one of the supervisors
# TODO

# Get Employee Evaluation Data
# project_id,employee_id,supervisor_id,case_id,survey_id,workflow_key

if {[catch {
    db_1row get_employee_evaluation_data "
	select 
		ee.*,
		to_char(p.start_date, 'YYYY-MM-DD') as start_date_pretty,
		to_char(p.end_date,'YYYY-MM-DD') as end_date_pretty,
                to_char(p.deadline_employee_evaluation,'YYYY-MM-DD') as deadline_pretty		
	from 
		im_employee_evaluations ee,
		im_projects p
	where 
		employee_evaluation_id = :employee_evaluation_id and 
		p.project_id = ee.project_id
    "
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    ad_return_complaint 1 "[lang::message::lookup "" intranet-employee-evaluation.ProblemDBAccess "There was a problem accessing the database:"] $errorInfo"
}

# Set Names
set employee_name [db_string get_user_name "select im_name_from_user_id(:employee_id, $name_order)" -default ""]
set supervisor_name [db_string get_user_name "select im_name_from_user_id(:supervisor_id, $name_order)" -default ""]

# Set position
# set employee_position [im_category_from_id [db_string get_role "select role_function_id from im_employees where employee_id = :employee_id" -default 0]]
set employee_position "<position>"

# Set location
set employee_location "<location>"

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
<table cellpadding='5' cellspacing='5' border='0'>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.Employee "Employee"]:</td>
	        <td>$employee_name</td>
	</tr>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.Position "Position"]:</td>
	        <td>$employee_position</td>
	</tr>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.Location "Location"]:</td>
	        <td>$employee_location</td>
	</tr>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.EvaluatingSupervisor "Evaluating Supervisor"]:</td>
	        <td>$supervisor_name</td>
	</tr>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.PerformancePeriod "Performance Period"]:</td>
        	<td>$start_date_pretty - $end_date_pretty</td>
	</tr>
	<tr>
        	<td>[lang::message::lookup "" intranet-employee-evaluation.Deadline "Deadline"]:</td>
        	<td>$deadline_pretty</td>
	</tr>
</table>
"

foreach transition_key $transition_keys {
    ns_log NOTICE "intranet-ee::print-employee-evaluation - workflow_key: $workflow_key, transition_key: $transition_key" 
    set transition_name [db_string get_transition_name "select transition_name from wf_transitions where transition_key = :transition_key and workflow_key = :workflow_key" -default ""]
    ns_log NOTICE "intranet-ee::print-employee-evaluation - transition_name: $transition_name" 
    set sql "
	select
	      	gqm.question_id
	from
      		im_employee_evaluation_panel_group_map pgm,
      		im_employee_evaluation_group_questions_map gqm,
      		im_employee_evaluation_groups g
	where
      		gqm.group_id = g.group_id and
      		pgm.wf_task_name = :transition_name and
      		pgm.survey_id = :survey_id and
      		pgm.group_id = g.group_id
	order by 
		gqm.sort_key
    "
    set question_list [db_list get_questions_for_group $sql]
    foreach question_id $question_list {
        ns_log NOTICE "intranet-ee::print-employee-evaluation - Writing question id: $question_id, employee_id: $employee_id, task_name:$transition_name"
	append html_output [im_employee_evaluation_question_display $question_id $employee_id $transition_name ""]
	# ns_log NOTICE "intranet-ee::print-employee-evaluation - question_html: \n [im_employee_evaluation_question_display $question_id $employee_id $transition_name ""]"
    }
}
append html_output "</table>"

