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
} {
    { task_id:integer}
}

# ---------------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set name [im_name_from_user_id $current_user_id]
set page_title [lang::message::lookup "" intranet-employee-evaluation.TitleNextYearSaveAction "Continue"]
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
