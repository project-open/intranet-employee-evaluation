# /packages/intranet-employee-evaluation/www/workflow-start-survey.tcl
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
    Start a Employee Evaluation Survey 

    @param project_id the group id
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)
} {
    { employee_id:integer 0 }
    { employee_email "" }
    project_id:integer
    { survey_id:integer 0 }
    { survey_name "" }
}

set current_user_id [ad_maybe_redirect_for_registration]
set admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set wf_key [parameter::get -package_id [apm_package_id_from_key intranet-employee-evaluation] -parameter "WorkflowKey" -default ""]

# Either survey_id or name  
if { 0 == $survey_id } {
    set survey_id [db_string get_survey_id "select survey_id from survsimp_surveys where name = :survey_name" -default 0]
}

if { 0 == $survey_id  } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.SurveyIdMissing "Please provide either survey name of survey id"]
    ad_script_abort
}

# we need either email or employee_id
# if { 0 == $employee_id && ""==$employee_email } {
#    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.MissingUserInfo "Please provide either email or an user ID"]
# }

# Get employee id from email 
# if { "" != $employee_email } {
#    set employee_id [db_string get_data "select party_id from parties where email = :employee_email" -default -1]
# }

# if { -1 == $employee_id  } {
#    [lang::message::lookup "" intranet-employee-evaluation.UserNotFound "User not found"]
# }


# if { 0 == $employee_id && "" == $employee_email} {
#    set employee_id $current_user_id
# }

# Check if current user = employee 
# if { $employee_id != $current_user_id } {
#    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.NotAllowed "You are not allowed to start this workflow "]
#    ad_script_abort
# }

# Check if current user is supervisor of employee 
set supervisor_id [db_string get_supervisor_employee "select supervisor_id from im_employees where employee_id = :employee_id" -default 0]
if { $supervisor_id != $current_user_id } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.NotAllowed "You are not allowed to start this workflow. You are not the supervisor of this employee."]
    ad_script_abort
}

# Check if employee is member of the EE Project 
if { ![im_biz_object_member_p $employee_id $project_id] } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.NotAllowed "You are not allowed to start this workflow. Please contact HR."]
    ad_script_abort
}

# Prevent that user starts a workflow twice for the same EE project 
if { 0 < [db_string check_if_wf_exists "select count(*) from im_employee_evaluations where project_id=:project_id and employee_id = :employee_id" -default 0] } {
    # ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.NotAllowed "A workflow has already been started. Please contact HR if you think that this is an error."]
    ad_script_abort
}

# Check if survey exists
if { 0 == [db_string get_data "select count(*) from survsimp_surveys where survey_id = :survey_id" -default 0] } {
    ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.SurveyNotFound "Survey does not exist, please verify link."]
    ad_script_abort
}

#-- ------------------------------------------------------------- 
#-- All validation ended 
#-- -------------------------------------------------------------

# New "Employee Evaluation" object
if {[catch {
    set employee_evaluation_id [db_string get_employee_evaluation_id "select acs_object__new(null,'im_employee_evaluation')"]
    db_dml create_employee_evaluation "insert into im_employee_evaluations (employee_evaluation_id, project_id, employee_id, supervisor_id, survey_id, workflow_key) 
				       values (:employee_evaluation_id,:project_id,:employee_id,:supervisor_id,:survey_id,:wf_key)"
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    ad_return_complaint 1  "[lang::message::lookup "" intranet-employee-evaluation.ErrorCreatingEmployeEvaluation "Error creating Employee Evaluation"] $errorInfo"
}

# Create WF case
set case_id [wf_case_new $wf_key "" $employee_evaluation_id ]

# Update "Config Object" - add case_id
db_dml add_case_id_to_conf_object "update im_employee_evaluations set case_id = :case_id where employee_evaluation_id = :employee_evaluation_id"

# Determine the first transition used for organizational stuff  
im_workflow_skip_first_transition -case_id $case_id

# Show first panel
set task_id [db_string get_task_id "select task_id from wf_tasks where workflow_key = :wf_key and case_id = :case_id and state='enabled'" -default 0]
ad_returnredirect "/acs-workflow/task?task_id=$task_id"
