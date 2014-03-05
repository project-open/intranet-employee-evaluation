# /packages/intranet-employee-evaluation/index.tcl
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
    { employee_evaluation_id:integer 0}
}

# ---------------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set page_title [lang::message::lookup "" intranet-employee-evaluation.TitleIndex "Employee Evaluation"]



