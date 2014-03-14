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

## ###################
#  Documentation 
## ###################
# Use case_id to get survey_id & and employee_id 
# Look up "im_employee_evaluation_panel_group_map" to get the group we need to show on the panel 
# Look up "im_employee_evaluation_group_questions_map" to get all questions we need to show 

if {[info exists task]} {

    # This code is called when this page is embedded in a WF "Panel"
    # ---------------------------------------------------------------
    # Defaults & Security
    # ---------------------------------------------------------------

    set current_user_id [ad_maybe_redirect_for_registration]
    set task_id $task(task_id)
    set case_id $task(case_id)    
    set task_name $task(task_name)
    set task_status $task(state)
    
    # get survey_id & employee_id
    db_1row get_survey_id "select survey_id, employee_id from im_employee_evaluations where case_id=:case_id"
    set return_url [im_url_with_query]
    set related_object_id $employee_id

    set html ""
    set tab_html_li ""
    set tab_html_div ""

    # TODO: Add check to make sure that current_user_id is a Supervisor 
    if { $current_user_id == $related_object_id } {
	set role "Employee"
    } else {
	set role "Supervisor" 
    }

    # Sanity check: Make sure that iuser is assigned to this task
    set task_assignee_p [db_string get_task_assignee "select count(*) from wf_task_assignments where task_id = :task_id and party_id = :current_user_id" -default 0]

    if { !$task_assignee_p } {
	ad_return_complaint xx  [lang::message::lookup "" intranet-employee-evaluation.NotAssigned "It appears that you are not assigned to this task. Please contact your System Administrator"]
    }

    # ---------------------------------------------------------------
    # Build Panel
    # ---------------------------------------------------------------

    # ad_return_complaint xx "select group_id from im_employee_evaluation_panel_group_map where wf_task_name = '$task_name' and survey_id=$survey_id"

    # Getting group_id for this PANEL
    set sql "
	select
		g.group_id
	from
		im_employee_evaluation_panel_group_map gm,
		im_employee_evaluation_groups g
	where
		wf_task_name = :task_name
		and gm.survey_id = :survey_id
		and gm.group_id = g.group_id
		and g.grouping_type = 'panel'
    "	
    set group_id [db_string get_group_id $sql -default 0] 

    append html "<form action='/intranet-employee-evaluation/process-response' enctype='multipart/form-data' method='post'>"
    append html "[export_vars -form { survey_id return_url related_object_id task_id task_name group_id role}]"

    ns_log NOTICE "intranet-ee::buildPanel - survey_id: $survey_id, task_id: $task_id, task_name: $task_name, group_id: $group_id, role: $role"

    # Check if there are TAB's on this page 
    set sql "
	select  
		g.group_id,
		g.group_name
	from 
		im_employee_evaluation_groups g,
		im_employee_evaluation_panel_group_map pgm
	where 
		g.grouping_type = 'tab'
		and pgm.wf_task_name = :task_name
		and g.group_id = pgm.group_id
                and pgm.survey_id = :survey_id
	order by 
		group_id
    "

    set ctr 1
    db_foreach tab $sql {
	append tab_html_li "<li><a href=\"#ee-tabs-$ctr\">$group_name</a></li>\n"
	append tab_html_div "\n<div id=\"ee-tabs-$ctr\">"
	    # Get all questions for this group
	    set sql_inner "
            select
                gqm.question_id
            from
                im_employee_evaluation_group_questions_map gqm,
                im_employee_evaluation_groups g
            where
                gqm.group_id = g.group_id and
                g.group_id = :group_id
            order by
                gqm.sort_key
            "
	set question_list [db_list get_questions_for_group $sql_inner]
	ns_log NOTICE "intranet-ee::buildPanel question_list: $question_list, group_name: $group_name, group_id: $group_id"

	foreach question_id $question_list {
	    ns_log NOTICE "intranet-ee::buildPanel - Writing question id: $question_id, employee_id: $employee_id, task_name:$task_name"
	    append tab_html_div [im_employee_evaluation_question_display $question_id $employee_id $task_name ""]
	    ns_log NOTICE "intranet-ee::buildPanel - question_html: \n [im_employee_evaluation_question_display $question_id $employee_id $task_name ""]"  
	}
        append tab_html_div "</div>\n\n"
	incr ctr
    }

    if { 1 != $ctr } {
	set tab_html "<div id=\"tabs_ee\">\n\n<ul>\n$tab_html_li\n</ul>$tab_html_div\n\n</div>\n"
	append tab_html "
	<script>
	\$(function() {
	    \$( \"\#tabs_ee\" ).tabs();
	});
	</script>"
	append html $tab_html

        append html "<br/><hr/><br/>
                <table cellpadding='0' cellspacing='0' border='0' width='100%'><tr><td align='center'>
                <input type='submit' value='Cancel' name='cancel_btn'>&nbsp;
                <input type='submit' value='Save Draft' name='save_btn'>&nbsp;
                <input type='submit' value='                    Save and Finish Stage                    ' name='save_and_finish_btn'>&nbsp;
		</td></tr></table></form><br/><hr>
		<strong>Legend:</strong><br/><ul>
			<li style='font-seize: 80%'>Save Draft: Save current status. The Workflow does not progress. You can open the form again to make changes and extensions.</li>
			<li style='font-seize: 80%'>Save and Finish Stage: The next 'Workflow Task' will be triggered. It's owner will be informed that you have finished your part.</li>
		</ul>"
    } else {
	# Get all questions for this group 
	set sql "
	    select 
    		gqm.question_id,
		g.grouping_type 
    	    from 
    		im_employee_evaluation_group_questions_map gqm,
    		im_employee_evaluation_groups g
    	    where
    		gqm.group_id = g.group_id and 
    		g.group_id = :group_id
	    order by 
		gqm.sort_key
         "

	# ad_return_complaint xx [db_list get_group_questions $sql]

	# Create HTML for each question 
	foreach question_id [db_list get_group_questions $sql] {
	    # ad_return_complaint xx "question_id: '$question_id', employee_id: '$employee_id', task_name: '$task_name'"
	    append html [im_employee_evaluation_question_display $question_id $employee_id $task_name ""]
	}

	if { "finished" != $task_status } {
	    append html "<br/><hr/><br/>
                <table cellpadding='0' cellspacing='0' border='0' width='100%'><tr><td align='center'>
                <input type='submit' value='Cancel' name='cancel_btn'>&nbsp;
                <input type='submit' value='Save Draft' name='save_btn'>&nbsp;
                <input type='submit' value='                    Submit                    ' name='save_and_finish_btn'>&nbsp;
                </td></tr></table></form>"
	}
    }

    return $html

} else {

    # Stand-Alone Head:
    # This code is called when the page is used as a normal "EditPage" or "NewPage".
    ad_page_contract {
	Creates Workflow Panel

	@param group_id
	@author klaus.hofeditz@project-open.com

    } {
	group_id:multiple,integer 
    }
    # ---------------------------------------------------------------
    # Not implemented yet .... 
    # ---------------------------------------------------------------

    return ""

    # ---------------------------------------------------------------
    # Defaults & Security
    # ---------------------------------------------------------------

    set show_context_help_p 0
    set current_user_id [ad_maybe_redirect_for_registration]
    set admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set current_user_id $user_id
    set today [lindex [split [ns_localsqltimestamp] " "] 0]

}


set ttt {

    set return_url ""
    if {[info exists task(return_url)]} { set return_url $task(return_url) }
    set survey_id [db_string pid "select object_id from wf_cases where case_id = :case_id" -default ""]
    
    
    # Get all groups for this panel 
    set sql "
	select 
		pgm.group_id
	from 
		im_employee_evaluation_panel_group_map pgm,
	where 
		pgm.wf_transition_name = :wf_transition_name
	order by
		pgm.sort_key
"  
    set group_id_list [db_list get_groups_for_panel $sql] 


    foreach group_id $group_id_list {
	# Create HTML for all active questions 
	set sql "
		select 
	        	gqm.question_id
		from 
			im_employee_evaluation_group_questions_map gqm,
			survsimp_questions q
		where 
			gqm.grouping_type = 'display'
			and gqm.group_id = $group_id
			and gqm.question_id in (select parent_question_id from im_employee_evaluation_questions_tree)
			and gqm.question_id = q.question_id
			and q.active_p == true
		order by
			sort_key
   " 

   db_foreach question_id $sql {
       append html_output [im_employee_evaluation_get_question_html $question_id] 
       # add group seperator ??
    }
    }
    return $html_output
}





