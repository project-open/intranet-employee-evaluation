# /packages/intranet-employee-evaluation/www/next-step.tcl
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

# Stand-Alone Head:
# This code is called when the page is used as a normal "EditPage" or "NewPage".

ad_page_contract {
    Creates Workflow Panel
    
    @param next_task_id
    @author klaus.hofeditz@project-open.com
    
} {
    next_task_id:integer 
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set show_context_help_p 0
set current_user_id [ad_maybe_redirect_for_registration]

set task_assignee_id [db_string get_task_assignee "select party_id from wf_task_assignments where task_id = :next_task_id limit 1" -default 0]

if { 0 != $task_assignee_id } {

    set from_email [parameter::get -package_id [apm_package_id_from_key acs-kernel] -parameter "SystemOwner" -default -1]
    set to_addr [db_string get_data "select email from parties where party_id = :task_assignee_id" -default ""]
    set system_url [parameter::get -package_id [apm_package_id_from_key acs-kernel] -parameter "SystemURL" -default ""]

    if {[catch {
	acs_mail_lite::send \
	    -send_immediately \
	    -to_addr $to_addr \
	    -from_addr $from_email \
	    -subject  "Automatic notification - Employee Evaluation Workflow" \
	    -body "A workflow task has been completed. You have been assigned to next task. Please go to:\n\n <a href=\"${system_url}intranet-employee-evaluation/\">${system_url}intranet-employee-evaluation/</a>\n\n to continue." \
	    -extraheaders "" \
	    -mime_type "text/html"
    } err_msg]} {
	global errorInfo
	ns_log Error "Unable to send notfication email: $errorInfo" 
    }
}

set msg "<br><br><strong>Thanks for providing the information requested. We have informed the employee who is in charge for the next workflow task. <br>You will receive a notification when you'll be assigned to the next task for this workflow.</strong>"
