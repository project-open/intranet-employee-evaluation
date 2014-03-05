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
set msg "Thanks for providing the information requested. You will be notified as soon as you will be assigned to the next task for this workflow."
