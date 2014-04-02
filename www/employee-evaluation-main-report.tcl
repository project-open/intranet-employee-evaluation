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
    { user_supervisor_id 0 }
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
    set employee_evaluation_arr($key) $employee_evaluation_id
}

set sql_distinct_eval_year "select evaluation_year, transition_name_printing from im_employee_evaluation_processes order by evaluation_year"
set evaluation_year_list [db_list_of_lists get_distinct_year_list $sql_distinct_eval_year] 

# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
 
set criteria [list]

# Employee Filter
if { 0 != $user_id && "" != $user_id } {
    lappend criteria "e.employee_id = :user_id"
}

# Supervisor Filter
if { 0 != $user_supervisor_id && "" != $user_supervisor_id } {
    lappend criteria "e.supervisor_id = :user_supervisor_id"
}

# Put everything together
set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

set sql ""

# ------------------------------------------------------------
# Create main sql 
#

# KH: Custom implementation for customer who sponsored development I decided to make this report 
# part of the ee-package so that the report doesn't get lost in some custom package  

if {[catch {
    set user_is_vp_or_dir_p [db_string get_data "select count(*) from im_employees where l2_vp_id = :current_user_id OR l3_director_id = :current_user_id limit 1" -default 0]
} err_msg]} {
    global errorInfo
    ns_log Error $errorInfo
    set user_is_vp_or_dir_p 0
}

if { !$user_is_vp_or_dir_p } {
    # current user is not in L2/L3, simply show direct reports and user himself
    set main_sql "
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
              and cc.member_state = 'approved'
              and e.employee_id = cc.party_id
              and e.supervisor_id = :current_user_id

	UNION

        select
              party_id as employee_id,
              first_names,
              last_name
        from
              cc_users
        where
              party_id = :current_user_id

        order by
              last_name,
              first_names
    "
} else {
    # Show all 'Direct Reports' and all users with current user as VP or Director 
    set main_sql "
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
              and cc.member_state = 'approved'
              and e.employee_id = cc.party_id
              and e.supervisor_id = :current_user_id
	      and (e.l2_vp_id = :current_user_id OR e.l3_director_id = :current_user_id)
              $where_clause
        order by
              last_name,
              first_names
    "
}

# Current User is SysAdmin or HR Manager - show all 
if { [im_is_user_site_wide_or_intranet_admin $current_user_id] || [im_user_is_hr_p $current_user_id] } {
    set main_sql "
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
	      and cc.member_state = 'approved'
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
# Output 

# We start with the main table because filter display depends on user status   

set html_table "
	<table border=0 class='table_list_simple'>\n
	<tr class='rowtitle'>
	<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.EmployeeName "Name"]</td>
"
foreach rec $evaluation_year_list {
    append html_table "<td class='rowtitle'>[lindex $rec 0]</td>"    
}
append html_table "</tr>"

set ctr 0 
db_foreach rec $main_sql {
    if { [im_is_user_site_wide_or_intranet_admin $current_user_id] } {
	set employee_name "<a href='/intranet/users/view?user_id=$employee_id'>$last_name, $first_names</a>"
    } else {
	set employee_name "$last_name, $first_names"
    }

    append html_table "\n
    	<tr>\n
		<td>$employee_name</td>
    "
    foreach rec $evaluation_year_list {
	set key "$employee_id,[lindex $rec 0]" 
	if { [info exists employee_evaluation_arr($key)] } {
	    append html_table "<td><a href='/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$employee_evaluation_arr($key)&transition_name_to_print=[lindex $rec 1]'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</a>"
	    if { [im_is_user_site_wide_or_intranet_admin $current_user_id] } {
		append html_table "<br><a href='/intranet-employee-evaluation/reset-workflow?employee_evaluation_id=$employee_evaluation_arr($key)&employee_id=$employee_id'>[lang::message::lookup "" intranet-employee-evaluation.ResetWorkflow "Reset WF"]</a>"
	    }	    
            append html_table "</td>\n"
	} else {
		append html_table "<td>-</td>\n"
	}
    }
    append html_table "\n		    	
	</tr>
    "
    incr ctr
}

append html_table "</table>"


set html "
		[im_header]
		[im_navbar]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		<td>
"
if { 1 != $ctr } {
    # User is not a Supervisor/Director/VP/Admin
    append html "
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
		  <td class=form-label>[lang::message::lookup "" intranet-core.Supervisor "Supervisor"]</td>
		  <td class=form-widget>
		    [im_supervisor_select -include_empty_p 1 $user_supervisor_id]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-core.Employee "Employee"]</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 -include_empty_name "" user_id $user_id]
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
"
}
append html "
		</td>
		<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td valign='top' width='600px'>
	    	<!--<ul>
			<li></li>
		</ul>-->
		</td>
		</tr>
		</table>
		$html_table
        	\n[im_footer]\n
" 
