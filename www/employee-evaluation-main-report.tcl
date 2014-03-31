# /packages/intranet-employee-evaluation/www/employee_evaluation-main-report.tcl
#
# Copyright (C) 2003 - 2014 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { user_id 0 }
    { cost_center_id 0 }
    { department_id 0 }
}

# ------------------------------------------------------------
# Security & Permissions
# ------------------------------------------------------------

# Label: Provides the security context for this report
set menu_label "employee-evaluation-main-report"
set current_user_id [ad_maybe_redirect_for_registration]

set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

# ------------------------------------------------------------
# Validate 
# ------------------------------------------------------------


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------
set debug 0
set employee_group_id [im_employee_group_id]
set page_title [lang::message::lookup "" intranet-reporting.TimesheetMonthlyViewIncludingAbsences "Employee Evaluations"]
set context_bar [im_context_bar $page_title]

# ------------------------------------------------------------
# Set Evaluation array
#

set evaluation_sql "
    select 
	employee_id, 
	(select 
		ep.evaluation_year 
	 from 
		im_employee_evaluation_processes ep, 
		im_employee_evaluations ee 
	 where 
		ee.employee_id = e.employee_id 
		and ee.project_id = ep.project_id 
		and e.project_id = ep.project_id
	) as evaluation_year,  
	e.employee_evaluation_id
    from 
	im_employee_evaluations e
    order by 
	e.employee_id
"

db_foreach r $evaluation_sql {
    set key "$employee_id,$evaluation_year"
    set ev_arr($key) $employee_evaluation_id
}


set sql_distinct_eval_year "select distinct evaluation_year from im_employee_evaluation_processes"
set ev_year_list [db_list get_distinct_year_list $sql_distinct_eval_year] 

# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
 
set criteria [list]

if { 0 != $user_id } {
    lappend criteria "e.employee_id = :user_id"
}

# Put everything together
set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}


set sql ""
# First simple case - current User is SysAdmin or HR Manager - show all 

# Second case - current user is not in L2/L2, simply show direct reports  
if { [db_string get_data "select count(*) from im_employees where l2_vp_id = :current_user_id OR l3_vp_id = :current_user_id" -default 0] } {
    set sql "
        select
              cc.party_id as employee_id,
              cc.first_names,
              cc.last_name
        from
              cc_users cc,
              acs_rels r,
              membership_rels mr,
              im_employees e
        where
              r.object_id_one = :employee_group_id
              and r.object_id_two = cc.party_id
              and r.rel_type = 'membership_rel'
              and r.rel_id = mr.rel_id
              and mr.member_state = 'approved'
              and e.employee_id = cc.party_id
              and e.supervisor_id = :current_user_id
	      $where_clause
        order by
              last_name,
              first_names
    "
}

if { [im_is_user_site_wide_or_intranet_admin $current_user_id] || [im_user_is_hr_p $current_user_id] } {
    set sql "
    	select 
	      cc.party_id as employee_id,
     	      cc.first_names, 
	      cc.last_name 
	from 
	      cc_users cc, 
	      acs_rels r, 
	      membership_rels mr,
	      im_employees e 
	where 
	      r.object_id_one = :employee_group_id
	      and r.object_id_two = cc.party_id 
	      and r.rel_type = 'membership_rel' 
	      and r.rel_id = mr.rel_id 
	      and mr.member_state = 'approved'
              and e.employee_id = cc.party_id
	      $where_clause
	order by 
	      last_name, 
	      first_names
    "
}


# -----------------------------------------------------------
# Outer where 
# -----------------------------------------------------------

# Check for filter "Department"  

if { "0" != $department_id &&  "" != $department_id } {
  	lappend criteria_outer "
                user_id in (
                        select employee_id from im_employees where department_id in (
                                select
                                        object_id
                                from
                                        acs_object_context_index
                                where
                                        ancestor_id = $department_id
                	)
           	)
        "
}

# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set html "
		[im_header]
		[im_navbar]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		<td>
		<form>
		<table border=0 cellspacing=1 cellpadding=1>
<!--
		<tr>
                  <td class=form-label>[_ intranet-core.Cost_Center]:</td>
                  <td class=form-widget>
		      [im_cost_center_select -include_empty 1  -department_only_p 0  cost_center_id $cost_center_id [im_cost_type_timesheet]]
                 </td>
		</tr>
		<tr>
                  <td class=form-label>[_ intranet-core.Department]:</td>
                  <td class=form-widget>
		      [im_cost_center_select -include_empty 1  -department_only_p 1  department_id $department_id [im_cost_type_timesheet]]
                 </td>
		</tr>
-->
		<tr>
		  <td class=form-label>Employee</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 user_id $user_id]
		  </td>
		</tr>
                <tr>
  		 <tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
		<br><br>
	</form>
	</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
	<td valign='top' width='600px'>
	    	<!--<ul>
			<li></li>
		</ul>-->
	</td>
	</tr>
	</table>
" 

# Table Title 
append html "
	<table border=0 cellspacing=5 cellpadding=5>\n
	<tr>
	<td>[lang::message::lookup "" intranet-employee-evaluation.EmployeeName "Name"]</td>
"
foreach r $ev_year_list {
    append html "<td>$r</td>"    
}
append html "</tr>"

# Table body
db_foreach r $sql {
    append html "\n
    	<tr>\n
		<td>$last_name, $first_names</td>
    "
    foreach r $ev_year_list {
	set key "$employee_id,$r" 
	if { [info exists ev_arr($key)] } {
	    append html "<td><a href='/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$ev_arr($key)'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</a>"
	    if { [im_is_user_site_wide_or_intranet_admin $current_user_id] } {
		append html "<br><a href='/intranet-employee-evaluation/reset-workflow?employee_evaluation_id=$ev_arr($key)'>[lang::message::lookup "" intranet-employee-evaluation.ResetWorkflow "Reset WF"]</a>"
	    }	    
            append html "</td>\n"
	} else {
		append html "<td>-</td>\n"
	}
    }
    append html "\n		    	
	</tr>
    "
}

append html "</table>\n[im_footer]\n"
