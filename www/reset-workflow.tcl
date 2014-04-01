# /packages/intranet-employee-evaluation/www/reset-workflow.tcl
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
    @author 
} {
    employee_evaluation_id:integer
    { return_url "/intranet-employee-evaluation/"}
}

# ---------------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
if { ![im_is_user_site_wide_or_intranet_admin $current_user_id] && ![im_user_is_hr_p $current_user_id] } {
    ad_return_complaint 1  [lang::message::lookup "" intranet-employee-evaluation.NoPermissionResetWf "You have no permission to reset the workflow"]
}

db_dml reset_wf "delete from im_employee_evaluations where employee_evaluation_id = :employee_evaluation_id"
ad_returnredirect $return_url