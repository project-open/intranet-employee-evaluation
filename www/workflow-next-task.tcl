# /packages/intranet-employee-evaluation/www/process-response.tcl
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
    Evaluates next task_id and shows it 
    @param case_id
    @author Klaus Hofeditz (klaus.hofeditz@project-open.com)
} {
    case_id 
}

set current_user_id [ad_maybe_redirect_for_registration]
set next_task_id [db_string get_next_task_id "select task_id from wf_tasks where case_id=:case_id and state='enabled'" -default 0]

if { 0 == $next_task_id } {
    # Check if finished 
    if { ![db_string get_next_task_id "select count(*) from wf_tasks where case_id=:case_id and state='finished'" -default 0] } {
	ad_return_complaint 1  [lang::message::lookup "" intranet-employee-evaluation.NoTaskFound "Did not find task, please contact your System Administrator"]
    } else {
	ad_returnredirect "/intranet-employee-evaluation/"
    }
} 

# Clarify: Security check necessary? Is user allowed to see that task 
ad_returnredirect "/acs-workflow/task?task_id=$next_task_id"

