# /packages/intranet-employee-evaluation/www/handle-next-year-save-action.tcl
#
# Copyright (C) 1998-2004 various parties
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
    View all the info about a specific project.

    @param project_id the group id
    @param orderby the display order
    @param show_all_comments whether to show all comments

    @author Frank Bergmann (frank.bergmann@project-open.com)
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)
} {
    { task_id:integer}
    button 
    employee_evaluation_id    
}

# ---------------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set name [im_name_from_user_id $current_user_id]
set page_title [lang::message::lookup "" intranet-employee-evaluation.TitleNextYearSaveAction "Continue"]

if {[catch {
    if { "save_and_finish_btn" == $button } {
	# Assign to SysAdmin so that user can't edit objectives anymore
	db_dml set_task_to_finish "update wf_task_assignments set party_id = 624 where task_id = :task_id"
	# Unblock so that employee can view/print objectives
	set sql "update im_employee_evaluations set temporarily_blocked_for_employee_p = 'f' where employee_evaluation_id = :employee_evaluation_id"
	db_dml set_temporarily_blocked_for_employee $sql
    } else {
	db_dml set_task_to_enabled "update wf_tasks set state = 'enabled' where task_id = :task_id"
	set sql "update im_employee_evaluations set temporarily_blocked_for_employee_p = 't' where employee_evaluation_id = :employee_evaluation_id"
	db_dml set_temporarily_blocked_for_employee $sql
    } 
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    ad_return_complaint 1  "[lang::message::lookup "" intranet-employee-evaluation.ErrorHandlingNextYearSave "Something went wrong saving the form. Please contact your System Administrator"] $errorInfo"
}

# ad_return_complaint xx "Assigned: [db_string get_data "select party_id from wf_task_assignments where task_id = :task_id" -default 0]"
ad_returnredirect "/intranet-employee-evaluation/"
ad_script_abort    


set html "
<br><br>
<strong>
Your entries have been saved. <br><br>
Please choose how to continue:<br><br> 
<br><br>
</strong>
<button onclick=\"window.location.replace('/acs-workflow/task?task_id=$task_id')\">Back to Objectives</button>&nbsp;&nbsp;OR&nbsp;&nbsp;
<button onclick=\"window.location.replace('/intranet-employee-evaluation/block-evaluation?task_id=$task_id')\">Leave - I understand that I will not be able to return to edit the objectives anymore</button>
"

