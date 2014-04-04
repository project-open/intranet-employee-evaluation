# /packages/intranet-employee-evaluation/www/block-evaluation.tcl
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
    @author klaus.hofeditz@project-open.com
} {
    { task_id:integer}
}

set current_user_id [ad_maybe_redirect_for_registration]

# Assign to SysAdmin so that user can't edit objectives anymore 
db_dml set_task_to_finish "update wf_task_assignments set party_id = 624 where task_id = :task_id"

ad_returnredirect "/intranet/"
