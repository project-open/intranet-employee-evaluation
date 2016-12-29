# /packages/intranet-employee-evaluation/tcl/intranet-employee-evaluation-procs.tcl
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

ad_library {
    @author others@openacs.org
    @author klaus.hofeditz@project-open.com
}

# -----------------------------------------------------------
# New question Type: "Combined Type One"
# -----------------------------------------------------------

ad_proc -public im_employee_evaluation_supervisor_upload_component {
    current_user_id
} {
    Provides links and status information for Employee Evaluation
} {

    # Check if current user is supervisor of an employee
    set number_direct_reports [db_string get_number_direct_reports "select count(*) from im_employees where supervisor_id = :current_user_id" -default 0]
    if { 0 == $number_direct_reports } {return "" }
    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

    set html_lines ""
    set deadline_employee_evaluation ""
    set start_date ""
    set end_date ""

    db_foreach r "select * from im_employee_evaluation_processes where status in ('Current','Next')" {
	switch $status {
	    Current {
			set evaluation_name_this_year $name
			set survey_name_this_year $survey_name
			set project_id_this_year $project_id
			set transition_name_printing_this_year $transition_name_printing
			set evaluation_year_this_year $evaluation_year
	    }
	    Next {
			set evaluation_name_next_year $name
			set survey_name_next_year $survey_name
			set project_id_next_year $project_id		
			set transition_name_printing_next_year $transition_name_printing
			set evaluation_year_next_year $evaluation_year
	    }
	}
    }
    if { ![info exists evaluation_name_this_year] || ![info exists evaluation_name_this_year] } {
        set msg "Can not show PORTLET. No data for Employee Evaluation Processes found. Table 'im_employee_evaluation_processes' needs to have at least one record with status 'Current' and one with status 'Next'. Please contact your System Administrator."
        return [lang::message::lookup "" intranet-employee-evaluation.ParameterWorkflowKeyNotFound $msg]
    }


    if {[catch {
        db_1row get_project_data "
		select 
	        project_name, 
			to_char(start_date, 'YYYY-MM-DD') as start_date_pretty, 
			to_char(end_date, 'YYYY-MM-DD') as end_date_pretty, 
			to_char(deadline_employee_evaluation, 'YYYY-MM-DD') as deadline_employee_evaluation_pretty 
		from im_projects where project_id = :project_id_this_year"
    } err_msg]} {
        global errorInfo
        ns_log Error $errorInfo
        return "Can't show PORTLET. [lang::message::lookup "" intranet-core.Db_Error "Database error:"] $errorInfo"
    }


    # Get directs
    set sql "
        select
            e.employee_id,
            im_name_from_user_id(e.employee_id, :name_order) as name,
            COALESCE((select employee_evaluation_id from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),0) as employee_evaluation_id_this_year,
            COALESCE((select temporarily_blocked_for_supervisor_p from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),'f') as temporarily_blocked_for_supervisor_this_year,
            COALESCE((select case_id from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),0) as case_id_this_year,
            COALESCE((select employee_evaluation_id from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),0) as employee_evaluation_id_next_year,
            COALESCE((select temporarily_blocked_for_supervisor_p from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),'f') as temporarily_blocked_for_supervisor_next_year,
            COALESCE((select case_id from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),0) as case_id_next_year
        from
            im_employees e,
	    cc_users cc
        where
    	    e.supervisor_id = :current_user_id
	    and e.employee_id = cc.user_id 
	    and cc.member_state = 'approved'

	UNION 
	select 
            e.employee_id,
            im_name_from_user_id(e.employee_id, :name_order) as name,
            COALESCE((select employee_evaluation_id from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),0) as employee_evaluation_id_this_year,
            COALESCE((select temporarily_blocked_for_supervisor_p from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),'f') as temporarily_blocked_for_supervisor_this_year,
            COALESCE((select case_id from im_employee_evaluations where project_id=:project_id_this_year and employee_id = e.employee_id),0) as case_id_this_year,
            COALESCE((select employee_evaluation_id from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),0) as employee_evaluation_id_next_year,
            COALESCE((select temporarily_blocked_for_supervisor_p from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),'f') as temporarily_blocked_for_supervisor_next_year,
            COALESCE((select case_id from im_employee_evaluations where project_id=:project_id_next_year and employee_id = e.employee_id),0) as case_id_next_year
        from
            im_employees e,
            cc_users cc
        where
            e.l3_director_id = :current_user_id
            and e.employee_id = cc.user_id
            and cc.member_state = 'approved'

	order by 
	    name
    "

    db_foreach rec $sql {

       append html_lines "<tr>" 
       append html_lines "<td><a href='/intranet/users/view?user_id=$employee_id'>$name</a></td>" 

       # THIS YEAR  
       if { 0 != $employee_evaluation_id_this_year } {
		   # Button Continue/Nothing to do 
		   set sql "select task_id from wf_task_assignments where task_id in (select task_id from wf_tasks where case_id = :case_id_this_year and state = 'enabled') and party_id = :current_user_id"
		   set current_task_id [db_string get_task_id $sql -default 0]
		   if { 0 != $current_task_id } {
			   set continue_btn "<button style='margin-top:-10px' onclick=\"location.href='/acs-workflow/task?task_id=$current_task_id'\"><nobr>Next Step</nobr></button>"
		   } else {
			   set sql "select count(*) from wf_cases where case_id = :case_id_this_year and state = 'finished'"
			   if { [db_string get_task_id $sql -default 0] } {
				   set continue_btn "<span style='color:green'>[lang::message::lookup "" intranet-employee-evaluation.Finished "Finished"]</span>"
			   } else {
				   set continue_btn "<span style='color:orange'>[lang::message::lookup "" intranet-employee-evaluation.WaitingForEmployee "Waiting"]</span>"
			   }
		   }
           append html_lines "<td>$continue_btn</td>"
		   
		   # Button 'Print'
		   set print_link "/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$employee_evaluation_id_this_year&transition_name_to_print=$transition_name_printing_this_year"

		   if { t == $temporarily_blocked_for_supervisor_this_year } {
			   append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.AccessBlockedByEmployee "Access temporarily blocked by Employee"]</td>"
		   } else {
			   append html_lines "<td><button style='margin-top:-10px' onclick=\"window.open('$print_link','_blank')\">[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</button></td>"
		   }
		   
       } else {
		   # set start_link "/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id_this_year&employee_id=$employee_id&survey_name=$survey_name_this_year"
		   # append html_lines "<td><button style='margin-top:-10px' onclick=\"location.href='$start_link'\">[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</button></td>"
	   	   append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.NotYetStarted "Not yet started"]</td>"	   
		   append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]</td>"
       }

       # ----------------------------------
       # Uploading column 
       # ----------------------------------
       set object_id $employee_id
       set bread_crum_path "employee_evaluation/$evaluation_year_this_year"
       set folder_type "user"
       set return_url "/intranet-employee-evaluation/"

       set upload_form "
		<form enctype='multipart/form-data' method='POST' action=/intranet-filestorage/upload-2.tcl>
				[export_vars -form {bread_crum_path folder_type object_id return_url}]
				<input type='file' name='upload_file' size='10'> &nbsp; <input type=submit value=\"[lang::message::lookup "" intranet-employee-evaluation.Upload "Upload"]\">
		</form>
       "

       # Make sure we have a folder to upload to 
       set path "[parameter::get -package_id [apm_package_id_from_key intranet-filestorage] -parameter "UserBasePathUnix" -default ""]/${employee_id}/${bread_crum_path}"
       if { [file exists $path] } {
	   if { ![file writable $path] || "" == $path } {
	       set help_txt_def "You are not allowed to upload files to $path/employee_evaluation/$evaluation_year_this_year. Please contact your System Administrator"
	       set help_txt [lang::message::lookup "" intranet-employee-evaluation.NoWritePermissions $help_txt_def]
               append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.UploadNotAvailable "Not available"]&nbsp;<img src='/intranet/images/navbar_default/help.png' "
               append html_lines "title='$help_txt' alt='$help_txt'></td>"
	   } else {
	       append html_lines "<td>$upload_form</td>"       
	   }
       } else {
	   file mkdir $path
	   append html_lines "<td>$upload_form</td>"       
       }

       # ----------------------------------
       # Uploaded column
       # ----------------------------------

       set column_uploaded_content ""
       set base_path_depth [llength [split $path "/"]]

       if { [catch {
		   # Executing the find command
		   set file_list [exec [im_filestorage_find_cmd] $path -noleaf]
		   set files [lsort [split $file_list "\n"]]
		   # remove the first (root path) from the list of files returned by "find".
		   set files [lrange $files 1 [llength $files]]
		   
		   foreach file $files {
			   # decode to utf-8
			   encoding convertto $file
			   set file_paths [split $file "/"]
			   set file_paths_len [llength $file_paths]
			   set rel_path_list [lrange $file_paths $base_path_depth $file_paths_len]
			   # set rel_path [join $rel_path_list "/"]
			   set current_depth [llength $rel_path_list]
			   
			   # Get more information about the file
			   set file_body [lindex $rel_path_list [expr $current_depth -1]]
			   
			   append column_uploaded_content "$file_body<br>"
		   }
		   
		   if { "" == $column_uploaded_content } {set column_uploaded_content [lang::message::lookup "" intranet-employee-evaluation.NoFilesUploadedYet "None"] }
		   append html_lines "<td>$column_uploaded_content</td>"
       } err_msg] } {
           append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.NoFilesFound "-"]</td>"
       }
       
       # Empty column to separate last year from current year 
       append html_lines "<td></td>"

       # ####################################
       # NEXT YEAR 
       # ####################################

       # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_supervisor_upload_component Next Year: employee_id: $employee_id, employee_evaluation_id_next_year: $employee_evaluation_id_next_year"
       # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_supervisor_upload_component case_id_next_year: $case_id_next_year"


       if { 0 != $employee_evaluation_id_next_year } {

	   set sql "
		select 
		    count(*)
		from 
		    wf_task_assignments a,
		    wf_tasks t
		where 
		    a.task_id = t.task_id
		    and a.party_id = 624
		    and t.transition_key = 'stage_0__appraiser_enter_appraisees_objectives'
		    and t.state = 'enabled'
		    and t.case_id = :case_id_next_year
	   "

	   if { [db_string get_objectives_entered_p $sql] } {
	       append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.ObjectivesEntered "Objectives<br>entered"]</td>"
	   } else {
	       set task_id_next_year [db_string get_task_id "select task_id from wf_tasks where case_id = :case_id_next_year and state = 'enabled'" -default 0]
	       append html_lines "<td><button style='margin-top:-10px' onclick=\"location.href='/acs-workflow/task?task_id=$task_id_next_year'\"><nobr>[lang::message::lookup "" intranet-employee-evaluation.EditObjectivesEntered "Edit"]</nobr></button></td>"
	   }

	   # Button 'Print'
           set print_link "/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$employee_evaluation_id_next_year&transition_name_to_print=$transition_name_printing_next_year"
	   
	   if { t == $temporarily_blocked_for_supervisor_next_year } {
	       append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.AccessBlockedByEmployee "Access temporarily blocked by Employee"]</td>"
	   } else {
	       append html_lines "<td><button style='margin-top:-10px' onclick=\"window.open('$print_link','_blank')\">[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</button></td>"
	   }
       } else {
	   set start_link "/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id_next_year&employee_id=$employee_id&survey_name=$survey_name_next_year"
	   append html_lines "<td><button class='start_next_year' href='$start_link' style='margin-top:-10px'>[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</button></td>"
	   append html_lines "<td>[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]</td>" 
      }
      # Print
      append html_lines "</tr>" 
    }
 
    set html "
	<!--[lang::message::lookup "" intranet-employee-evaluation.TitlePortletSupervisor "Please manage the Employee Performance Evaluation of your Direct Reports from here."]<br/>-->
	<!--
	<table cellpadding='5' cellspacing='5' border='0'>
	<tr>
	<td>[lang::message::lookup "" intranet-core.StartDate "Start Date"]:</td>
	<td>$start_date_pretty</td>
	</tr>
	<tr>
	<td>[lang::message::lookup "" intranet-core.EndDate "End Date"]:</td>
	<td>$end_date_pretty</td>
	</tr>
	<tr>
	<td>[lang::message::lookup "" intranet-employee-evaluation.Deadline "Deadline"]:</td>
	<td>$deadline_employee_evaluation_pretty</td>
	</tr>
	</table>
	-->

	<table cellpadding='5' cellspacing='5' border='0>
		<tr class='rowtitle'>
			<td> &nbsp;</td>
			<td class='rowtitle' colspan='4'>Annual Review $evaluation_year_this_year</td>
			<td> &nbsp;&nbsp;&nbsp;</td>
			<td class='rowtitle' colspan='2'>Objectives setting $evaluation_year_next_year</td>
		</tr>
		<tr class='rowtitle'>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Name"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Workflow "Workflow"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Upload "Upload"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Uploaded "Uploaded"]</td>
			<td></td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Workflow "Workflow"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</td>
		</tr>
		$html_lines
	</table>

	<script type='text/javascript'>
	\$(document).ready(function() {
	  \$('.start_next_year').click(function() {
    	  // if (confirm('Objectives for the current year can be only entered ONCE. Are you sure you want to continue?')) {
	      var url = \$(this).attr('href');	
	      window.location.assign(url);
    	  // };
  	  });
	});
	</script>
    "
    return $html
}

ad_proc -public create_html_combined_type_one {
    question_id
    employee_id
    wf_task_name
    { print_p f }
} {
    Returns HTML code for "Combined Type 1" type
    +----------------------------------------------------------------------------------------------------+
    |                | sub_question 1 txt      | sub_question 2 txt      | ... | sub_question 4 txt      |
    | ----------------------------------------------------------------------------------------------------
    | question_text  | sub_question 1 response | sub_question 2 response | ... | sub_question 4 response |
    +----------------------------------------------------------------------------------------------------+
} {

    # Get Main Question Txt
    set main_question_txt [db_string get_main_question_txt "select question_text from survsimp_questions where question_id = :question_id" -default 0]

    # Get sub-questions 
    set sql "
        select
                child_question_id
        from
                im_employee_evaluation_questions_tree t,
                survsimp_questions q
        where
                t.parent_question_id = $question_id
                and q.question_id = t.parent_question_id
        order by
                q.sort_key
    "

    # Get sub-question HTML
    set ctr 0
    set subquestion_list [db_list get_sub_questions $sql]

    foreach sub_question_id $subquestion_list {
        incr ctr
	# ns_log NOTICE "intranet-employee-evaluation-procs::create_html_combined_type_one - sub_question_id: $sub_question_id"
	eval {set subquestion_html_$ctr [im_employee_evaluation_question_display $sub_question_id $employee_id $wf_task_name "" $print_p]}
    }

    if { $ctr != 4 } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.Expecting5SubQuestions "Expecting 4 Sub-Questions for this question type, but found only: $ctr"]
    }

    # Build table
    return "
        <table border=\"0\">
        <tr>
                <td valign='top' width='300px'><span class='ee-survey-question-main-question-text' title='$question_id'>$main_question_txt</span></td>
                <td valign='top'>&nbsp;</td>
                <td valign='top'>$subquestion_html_1</td>
                <td valign='top'>&nbsp;&nbsp;</td>
                <td valign='top'>$subquestion_html_2</td>
                <td valign='top'>&nbsp;</td>
                <td valign='top'>$subquestion_html_3</td>
                <td valign='top'>&nbsp;&nbsp;</td>
                <td valign='top'>$subquestion_html_4</td>
        </tr>
        </table>
    "
}


ad_proc -public create_html_combined_type_two {
    question_id
    employee_id
    wf_task_name
    {print_p f}
} {
    Returns HTML code for "Combined Type 1" type

    +----------------------------------------------------------------------------------------------------+
    |  main question                                                                                     |  
    | ---------------------------------------------------------------------------------------------------|
    |  sub_question 1  | sub_question4 |                                                                 |
    | ----------------------------------------------------------------------------------------------------
    |  sub_question 2  | sub_question3 | sub_question 5                                                  |
    +----------------------------------------------------------------------------------------------------+

} {

    # Get Main Question Txt
    set main_question_txt [db_string get_main_question_txt "select question_text from survsimp_questions where question_id = :question_id" -default 0]

    # Get sub-questions
    set sql "
        select
                child_question_id
        from
                im_employee_evaluation_questions_tree t,
                survsimp_questions q
        where
                t.parent_question_id = $question_id
                and q.question_id = t.parent_question_id
        order by
                q.sort_key
    "

    # Get sub-question HTML
    set ctr 0
    set subquestion_list [db_list get_sub_questions $sql]

    foreach sub_question_id $subquestion_list {
        incr ctr
        # ns_log NOTICE "intranet-employee-evaluation-procs::create_html_combined_type_one - sub_question_id: $sub_question_id"
        eval {set subquestion_html_$ctr [im_employee_evaluation_question_display $sub_question_id $employee_id $wf_task_name "" $print_p]}
    }

    if { $ctr != 5 } {
	ad_return_complaint 1  [lang::message::lookup "" intranet-employee-evaluation.Expecting5SubQuestions "Expecting 5 Sub-Questions for this quesion type but found: $ctr"]
    }

    # Build table
    return "
        <table class='' border=\"0\">
        <tr>
                <td valign='top' colspan='3'><span title='$question_id'>$main_question_txt</span></td>
	</tr>
        <tr>
                <td valign='top'>$subquestion_html_1</td>
		<td valign='top' colspan='2'>$subquestion_html_4</td>

	</tr>
	<tr>
		<td valign='top'>$subquestion_html_2</td>
		<td valign='top'>$subquestion_html_3</td>
		<td valign='top'>$subquestion_html_5</td>
	</tr>
        </table>
    "

}


# -----------------------------------------------------------
# Question Permissions 
# -----------------------------------------------------------

ad_proc -public im_employee_evaluation_question_permissions {
    { -wf_task_id "" } 
    { -wf_task_name "" } 
    { -wf_role "" } 
    question_id
    employee_id
} {
    Should cover the following use cases 
    	a) User to be evaluated requires access within WF (could be blocked) 
    	b) User to be evaluated requires access outside WF
	c) Task assignee within WF (could be regular supervisor or delegate of regular supervisor) 
	d) Direct Supervisor (Attribute: Employee Information)
	e) One of the superior supervisors of the direct supervisors

	Returns list of three elements - value range: [ 0 | 1 ] 
    	- read permission  
	- write permission 
    	- admin permission 
} {
    if { "" != $wf_task_name } {
	# Access within WF 
	# Check if employee himself inquires
	set sql "select read_p, write_p, admin_p from im_employee_evaluation_config where question_id = :question_id and wf_task_name = :wf_task_name and wf_role = :wf_role"

	if {[catch {
		db_1row get_permissions_for_question $sql
	} err_msg]} {
	    global errorInfo
	    ns_log Error $errorInfo
	    ad_return_complaint 1  "Error getting permissions for question_id: $question_id, wf_task_name: $wf_task_name, wf_role: $wf_role - [lang::message::lookup "" intranet-core.Db_Error "x"] $errorInfo"
	    return
	}

	# ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_permissions - question_id: $question_id, wf_task_name: $wf_task_name,  wf_role: $wf_role | $read_p $write_p $admin_p"
	return [list $read_p $write_p $admin_p]

    } else {
	# Access outside of WF: tbd 
	# Check if one of the employees supervisors requires read access 
        # set supervisor_list [im_custom_champ_get_all_supervisors $user_id]  
	return [list 0 0 0]
    }
}


ad_proc -public im_employee_evaluation_question_display {
    question_id
    employee_id
    wf_task_name 
    { edit_previous_response_p "f" }  
    { print_p "f" } 
} { 
    Returns a string of HTML to display for a question, suitable for embedding in a form.
    The form variable is of the form \"response_to_question.\$question_id
} {
    template::head::add_javascript -src "http://code.jquery.com/ui/1.8.0/jquery-ui.js" -order 9990
    template::head::add_css -href "http://code.jquery.com/ui/1.8.0/themes/smoothness/jquery-ui.css" -media "screen" -order 9980
    template::head::add_css -href "/intranet-employee-evaluation/css/intranet-employee-evaluation.css" -media "screen" -order 9900

    set user_id [auth::get_user_id]
    # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display"
    # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display"
    # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display ****** Enter -question_id: $question_id, employee_id:$employee_id, user_id: $user_id, wf_task_name: $wf_task_name"

    # Check if we have already an answer 
    set sql "
    select 
    	count(*) 
    from 
    	survsimp_responses r,
    	survsimp_question_responses qr
    where 
    	qr.response_id = r.response_id 
    	and related_object_id = :employee_id
    	and qr.question_id = :question_id
    "

    if { [db_string get_responses $sql -default 0] } {
	set edit_previous_response_p "t"
    }

    if { "" != $wf_task_name } {
	# Access within WF
	if { $employee_id == $user_id } {
	    set permission_list [im_employee_evaluation_question_permissions -wf_task_name $wf_task_name -wf_role "Employee" $question_id $employee_id]	    
	} else {
	    set permission_list [im_employee_evaluation_question_permissions -wf_task_name $wf_task_name -wf_role "Supervisor" $question_id $employee_id]	    	    
	}
    }

    regsub -all {t} $permission_list 1 permission_list
    regsub -all {f} $permission_list 0 permission_list
    # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display - edit_previous_response_p: $edit_previous_response_p, permission_list: $permission_list"   

    set visible_p [lindex $permission_list 0]
    set writeable_p [lindex $permission_list 1]

    set element_name "response_to_question.$question_id"

    # Get general QDetails 
    db_1row survsimp_question_properties "
        select
                survey_id,
                sort_key,
                question_text,
                abstract_data_type,
                required_p,
                active_p,
                presentation_type,
                presentation_options,
                presentation_alignment,
                creation_user,
                creation_date
        from
                survsimp_questions, acs_objects
        where
                object_id = question_id
                and question_id = :question_id
    "
    # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display question_text: $question_text - visible_p: $visible_p, writeable_p: $writeable_p"

    set html ""

    if { $presentation_alignment == "below" } {
        # append html "<br>"
    } else {
        append html " "
    }

    set user_value ""

    if {$edit_previous_response_p == "t"} {
        set user_id [ad_conn user_id]

        set prev_response_query "
        select
                choice_id,
                boolean_answer,
                clob_answer,
                number_answer,
                varchar_answer,
                date_answer,
                attachment_file_name
        from
                survsimp_question_responses
        where
                question_id = :question_id
                and response_id in (
                        select  max(r.response_id)
                        from    survsimp_question_responses qr,
				survsimp_responses r 
                        where   
				r.response_id = qr.response_id
				and qr.question_id = :question_id
                                and r.related_object_id = :employee_id
                )
        "

        set count 0
        db_foreach survsimp_response $prev_response_query {
            incr count
            if {$presentation_type == "checkbox"} {
                set selected_choices($choice_id) "t"
            }
        } if_no_rows {
            set choice_id 0
            set boolean_answer ""
            set clob_answer ""
            set number_answer ""
            set varchar_answer ""
            set date_answer ""
            set attachment_file_name ""
        }
    }

    # Verify: Does "if_no_rows" fail ?
    if { ![info exists choice_id] } {
	set choice_id 0
    }


   # ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display presentation_type: $presentation_type, visible_p: $visible_p, writeable_p: $writeable_p"

 
   switch -- $presentation_type {
        "none" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span>"
        }
        "combined_type_one" {
            if {[catch {
		if { $visible_p } {
		    append html [create_html_combined_type_one $question_id $employee_id $wf_task_name $print_p]
		} else {
		    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}
            } err_msg]} {
                append html "Presentation type not supported, please install package \]po\[ Employee Evaluation"
                ad_return_complaint 1 $err_msg
            }
        }
       "combined_type_two" {
	   if {[catch {
	       if { $visible_p } {
		   append html [create_html_combined_type_two $question_id $employee_id $wf_task_name $print_p]
	       } else {
		   append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	       }
	   } err_msg]} {
	       append html "Presentation type not supported, please install package \]po\[ Employee Evaluation"
                ad_return_complaint 1 $err_msg
	   }
       }
        "upload_file"  {
            if {$edit_previous_response_p == "t"} {
                set user_value $attachment_file_name
            }
            append html "<input type=file name=$element_name $presentation_options>"
        }
        "textbox" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>"
            if {$edit_previous_response_p == "t"} {
                if {$abstract_data_type == "number" || $abstract_data_type == "integer"} {
                    set user_value $number_answer
                } else {
                    # set user_value $varchar_answer
                    set user_value $clob_answer
                }
            }
	    if { $visible_p } {
                if { $writeable_p } {
		    append html "<input type=text name=$element_name id=$element_name value=\"[philg_quote_double_quotes $user_value]\" [ad_decode $presentation_options "large" "size=70" "medium" "size=40" "size=10"]>"
		    if { [string first "date" [string tolower $question_text]] != -1 } {
			append html "&nbsp;<input style=\"height:20px; width:20px; background: url('/resources/acs-templating/calendar.gif');\" onclick=\"return showCalendar('$element_name', 'y-m-d');\" type=\"button\">"
		    }
                } else {
		    append html "<input type=text readonly style='background-color:#cccccc;' name=$element_name value=\"[philg_quote_double_quotes $user_value]\" [ad_decode $presentation_options "large" "size=70" "medium" "size=40" "size=10"]>"
                }
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    } 
        }
        "textarea" {
	    append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>"
            if {$edit_previous_response_p == "t"} {
                if {$abstract_data_type == "number" || $abstract_data_type == "integer"} {
                    set user_value $number_answer
                } elseif { $abstract_data_type == "shorttext" } {
                    set user_value $varchar_answer
                } else {
                    set user_value $clob_answer
                }
            }

            if { $visible_p } {
		if { $print_p } {
		    append html "<span class='ee-survey-textarea-print'>$user_value</span>"
		} else {
		    if { $writeable_p } {
			append html "<textarea name=$element_name $presentation_options>$user_value</textarea>"
		    } else {
			append html "<textarea style='background-color:#cccccc;' $presentation_options readonly>$user_value</textarea>"
		    }
		}
            } else {
                append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
            }
        }
        "date" {
            if {$edit_previous_response_p == "t"} {
                set user_value $date_answer
            }
            if { $visible_p } {
		append html "[ad_dateentrywidget $element_name $user_value]"
            } else {
                append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
            }

        }
        "select" {
            if { $abstract_data_type == "boolean" } {
                if {$edit_previous_response_p == "t"} {
                    set user_value $boolean_answer
                }
		if { $visible_p } {
			append html "
	                <select name=$element_name>
        	         <option value=\"\">[lang::message::lookup "" simple-survey.Select_One "Select One"]</option>
                	 <option value=\"t\" [ad_decode $user_value "t" "selected" ""]>True</option>
	                 <option value=\"f\" [ad_decode $user_value "f" "selected" ""]>False</option>
        	        </select>
                        "
		} else {
		    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}
            } else {
		append html "<span class='ee-survey-question-main-question-text' title='$question_id'>$question_text</span><br/>" 
                if {$edit_previous_response_p == "t"} {
                    set user_value $choice_id
		    if { "" == $user_value } {
			set user_value [lang::message::lookup "" intranet-employee-avaluation.Empty "Not provided"]
		    } 
                }
		# ns_log NOTICE "intranet-employee-evaluation-procs::im_employee_evaluation_question_display select - not boolean - user_value: $user_value"
                if { $visible_p } {
		    if { $writeable_p } {
			append html "
                	<select name=$element_name>
	                <option value=\"\">[lang::message::lookup "" simple-survey.Select_One "Select One"]</option>
        	        "
			db_foreach survsimp_question_choices "select choice_id, label from survsimp_question_choices where question_id = :question_id order by sort_order" {
			    if { $user_value == $choice_id } {
				append html "<option value=$choice_id selected>$label</option>\n"
			    } else {
				append html "<option value=$choice_id>$label</option>\n"
			    }
			}
			append html "</select>"
		    } else {
			set choice_label [db_string get_select_value "select label from survsimp_question_choices where choice_id = :choice_id" -default ""]
			if { "" != $choice_label } {
			    append html $choice_label
			} else {
			    append html [lang::message::lookup "" intranet-employee-evaluation.NoAnswerProvided "No answer provided"]		    
			}
		    }
		} else {
                    append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
		}

            }
        }

        "radio" {
            if { $abstract_data_type == "boolean" } {

                if {$edit_previous_response_p == "t"} { set user_value $boolean_answer }
                set choices [list \
				 "<input type=radio name=$element_name value=t [ad_decode $user_value "t" "checked" ""]> True" \
				 "<input type=radio name=$element_name value=f [ad_decode $user_value "f" "checked" ""]> False" \
				 ]

            } else {
                if {$edit_previous_response_p == "t"} { set user_value $choice_id }

                set choices [list]
                db_foreach sursimp_question_choices_2 "
                        select  choice_id, label
                        from    survsimp_question_choices
                        where   question_id = :question_id
                        order by sort_order
                " {
                    if { $user_value == $choice_id } {
                        lappend choices "<input type=radio name=$element_name value=$choice_id checked> $label"
                    } else {
                        lappend choices "<input type=radio name=$element_name value=$choice_id> $label"
                    }
                }
            }

	    if { $visible_p } {
		if { $presentation_alignment == "beside" } {
		    append html [join $choices " "]
		} else {
		    append html "<blockquote>\n[join $choices "<br>\n"]\n</blockquote>"
		}
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    }
        }

        "checkbox" {
            set choices [list]
            db_foreach sursimp_question_choices_3 "
                select * from survsimp_question_choices
                where question_id = :question_id
                order by sort_order
                " {

                    if { [info exists selected_choices($choice_id)] } {
                        lappend choices "<input type=checkbox name=$element_name value=$choice_id checked> $label"
                    } else {
                        lappend choices "<input type=checkbox name=$element_name value=$choice_id> $label"
                    }
                }
            if { $visible_p } {
		if { $presentation_alignment == "beside" } {
		    append html [join $choices " "]
		} else {
		    append html "<blockquote>\n[join $choices "<br>\n"]\n</blockquote>"
		}
	    } else {
		append html [lang::message::lookup "" intranet-employee-evaluation.NotVisible "\[-\]"]
	    }
        }
    }
    return "$html</br>"
}

ad_proc -public im_employee_evaluation_employee_component {
    current_user_id
} {
    Provides links and status information for current and past 'Employee Performance Evaluations'.
    Current transition name to be printed is required in order to create the 'Print' link.  
} {

    set name_order [parameter::get -package_id [apm_package_id_from_key intranet-core] -parameter "NameOrder" -default 1]

    # Init  
    set start_date "" 
    set end_date "" 
    set deadline_employee_evaluation ""
    set case_id -1

    db_foreach r "select * from im_employee_evaluation_processes where status in ('Current','Next')" {
        switch $status {
            "Current" {
                set evaluation_name_this_year $name
                set project_id_this_year $project_id
                set transition_name_printing_this_year $transition_name_printing
		set workflow_key_this_year $workflow_key
		set evaluation_year_this_year $evaluation_year
            }
            "Next" {
                set evaluation_name_next_year $name
                set project_id_next_year $project_id
                set transition_name_printing_next_year $transition_name_printing
		set workflow_key_next_year $workflow_key
		set evaluation_year_next_year $evaluation_year
            }
        }
    }

    if { ![info exists workflow_key_this_year] || ![info exists workflow_key_next_year] } { 
		set msg "Can not show PORTLET. No data for Employee Evaluation Processes found. Table 'im_employee_evaluation_processes' needs to have at least one record with status 'Current' and one with status 'next'. Please contact your System Administrator."
		return [lang::message::lookup "" intranet-employee-evaluation.ParameterWorkflowKeyNotFound $msg]
    }

    # Additional Sanity checks: Check if transition exists: 
    if { ![db_string sanity_check_wf_transition "select count(*) from wf_transitions where workflow_key = :workflow_key_this_year and transition_name = :transition_name_printing_this_year" -default ""] } {
		return [lang::message::lookup "" intranet-employee-evaluation.WorkflowMissesTransition. "Can not show PORTLET. No transition: '$transition_name_printing_this_year' in workflow: '$workflow_key_this_year' found. Please contact your System Administrator."]
    }
    
    set html_lines ""


    # Check if a WF had been started already
    set sql "
                select
                        employee_evaluation_id,
                        case_id,
			temporarily_blocked_for_employee_p
                from
                        im_employee_evaluations
                where
                        project_id = :project_id_this_year and
                        employee_id = :current_user_id
    "

    if {[catch {
		db_1row get_employee_evaluation_id $sql
    } err_msg]} {
		set employee_evaluation_id 0
		set case_id 0
    }


    if {[catch {
        db_1row get_project_data "select project_name, start_date, end_date, to_char(deadline_employee_evaluation, 'YYYY-MM-DD') as deadline_employee_evaluation from im_projects where project_id = :project_id_this_year"
    } err_msg]} {
        global errorInfo
        ns_log Error $errorInfo
        return "Can't show PORTLET. [lang::message::lookup "" intranet-core.Db_Error "Database error:"] $errorInfo"
    }

    # Status 
    set current_task_id [db_string get_task_id "select task_id from wf_task_assignments where task_id in (select task_id from wf_tasks where case_id = :case_id and state = 'enabled') and party_id = :current_user_id" -default 0] 

    if { 0 != $current_task_id } {
        set wf_button "<button style='margin-top: -10px' onclick=\"location.href='/acs-workflow/task?task_id=$current_task_id'\">Next step</button>"
    } else {

	if { 0 != $employee_evaluation_id } {
	    set wf_button [lang::message::lookup "" intranet-employee-evaluation.NoAssignment "You are currently not assigned to a Workflow Task"]
	} else {
	    set survey_name_this_year [db_string sql "select survey_name from im_employee_evaluation_processes where status in ('Current')" -default ""]
            set start_link "/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id_this_year&employee_id=$current_user_id&survey_name=$survey_name_this_year"
	    set wf_button "<button style='margin-top:-10px' onclick=\"location.href='$start_link'\">[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</button>"
	}
    }

    # Print Button 
    if { 0 != $employee_evaluation_id } {

		# Check if employee is able to access performance evaluation 
		if { t == $temporarily_blocked_for_employee_p } { 
			set print_button [lang::message::lookup "" intranet-employee-evaluation.AccessBlockedBySupervisor "Access temporarily blocked by Supervisor"]
		} else {
			set print_button "
                <form action='/intranet-employee-evaluation/print-employee-evaluation' method='POST' target='_blank'>
                <input type='hidden' name= 'transition_name_to_print' value='$transition_name_printing_this_year'>
                <input type='hidden' name= 'employee_evaluation_id' value='$employee_evaluation_id'>
                <input type='submit' value='[lang::message::lookup "" intranet-employee-evaluation.Print Print]'>
                </form>
			"
		}
    } else {
		set print_button "[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]"
	        # set start_link "/intranet-employee-evaluation/workflow-start-survey?project_id=$project_id_this_year&employee_id=$employee_id&survey_name=$survey_name_this_year"
		# set print_button "<button style='margin-top:-10px' onclick=\"location.href='$start_link'\">[lang::message::lookup "" intranet-employee-evaluation.Start "Start"]</button>"
    }

    append html_lines "<tr>" 
    append html_lines "<td>$wf_button</td>"
    append html_lines "<td>$print_button</td>"
    append html_lines "<td>$deadline_employee_evaluation</td>" 
    append html_lines "</tr>" 
 
    set html "
	<h3>$evaluation_year_this_year</h3>
	<table cellpadding='5' cellspacing='5' border='0'>
		<tr class='rowtitle'>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Status"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.ToBeFinishedBy "Deadline"]</td>
		</tr>
		$html_lines
	</table>
	<br/>
	<h3> [lang::message::lookup "" intranet-employee-evaluation.Objectives "Objectives"] $evaluation_year_next_year:</h3>
	<table cellpadding='5' cellspacing='5' border='0'>
		<tr class='rowtitle'>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.Status "Status"]</td>
			<td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.ToBeFinishedBy "Deadline"]</td>
		</tr>
    "

    # Check if a WF had been started already
    set sql "
                select
                        employee_evaluation_id,
                        case_id,
			temporarily_blocked_for_employee_p
                from
                        im_employee_evaluations
                where
                        project_id = :project_id_next_year and
                        employee_id = :current_user_id
    "

    if {[catch {
        db_1row get_employee_evaluation_id $sql
    } err_msg]} {
        set employee_evaluation_id 0
        set case_id 0
    }

    if { 0 != $employee_evaluation_id && !$temporarily_blocked_for_employee_p } {
	set print_button "
                <form action='/intranet-employee-evaluation/print-employee-evaluation' method='POST' target='_blank'>
                <input type='hidden' name= 'transition_name_to_print' value='$transition_name_printing_next_year'>
                <input type='hidden' name= 'employee_evaluation_id' value='$employee_evaluation_id'>
                <input type='submit' value='[lang::message::lookup "" intranet-employee-evaluation.Print Print]'>
                </form>
            "
	set status [lang::message::lookup "" intranet-employee-evaluation.ObjectivesEntered "Objectives entered"]
    } else {
        set print_button "[lang::message::lookup "" intranet-employee-evaluation.NotStartedYet "Nothing to print"]"
	set status [lang::message::lookup "" intranet-employee-evaluation.ObjectivesNotYetEntered "Objectives not yet entered"]
    }
    
    append html "
                <tr class='rowtitle'>
                        <td>$status</td>
                        <td>$print_button</td>
                </tr>
	</table>
    "
    # Past EE's 
    set sql_distinct_eval_year "select evaluation_year, transition_name_printing from im_employee_evaluation_processes order by evaluation_year"
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
		    where 
			 employee_id = :current_user_id 
    "

    db_foreach r $evaluation_sql {
	set key "$employee_id,$evaluation_year"
	set employee_evaluation_arr($key) $employee_evaluation_id
    }

    append html "
	<h3>[lang::message::lookup "" intranet-employee-evaluation.PastReviews "Past Reviews"]:</h3>
        <table border=0 class='table_list_simple'>\n
        <tr class='rowtitle'>
    "

    set found_past_evaluation_year_p 0
    set evaluation_year_list [db_list_of_lists get_distinct_year_list $sql_distinct_eval_year]
    foreach rec $evaluation_year_list {
        if { $evaluation_year_this_year != [lindex $rec 0] && $evaluation_year_next_year != [lindex $rec 0]  } {
	    set found_past_evaluation_year_p 1
	    append html "<td class='rowtitle'>[lindex $rec 0]</td>"
	}
    }

    append html "</tr><tr>"
    foreach rec $evaluation_year_list {
	if { $evaluation_year_this_year != [lindex $rec 0] && $evaluation_year_next_year != [lindex $rec 0]  } {
	set key "$current_user_id,[lindex $rec 0]"
	    if { [info exists employee_evaluation_arr($key)] } {
		append html "<td><a href='/intranet-employee-evaluation/print-employee-evaluation?employee_evaluation_id=$employee_evaluation_arr($key)&transition_name_to_print=[lindex $rec 1]'>[lang::message::lookup "" intranet-employee-evaluation.Print "Print"]</a></td>\n"
	    } else {
		append html "<td>-</td>\n"
	    }
	}
    } 
    if { !$found_past_evaluation_year_p } {append html [lang::message::lookup "" intranet-employee-evaluation.NoPastEvaluationsFound "No past evaluations found"] }
    append html "</tr></table>"
    return $html
}

ad_proc -public im_employee_evaluation_statistics_current_project {
    current_user_id
} {
    Provides statistical data about progress of current survey 
} {

    # Init 
    db_foreach r "select * from im_employee_evaluation_processes where status in ('Current','Next')" {
        switch $status {
            Current {
                set evaluation_name_this_year $name
                set project_id_this_year $project_id
                set transition_name_printing_this_year $transition_name_printing
                set workflow_key_this_year $workflow_key
		set survey_name_this_year $survey_name
            }
            Next {
                set evaluation_name_next_year $name
                set project_id_next_year $project_id
                set transition_name_printing_next_year $transition_name_printing
                set workflow_key_next_year $workflow_key
                set survey_name_next_year $survey_name
            }
        }
    }

    if { ![info exists workflow_key_this_year] || ![info exists workflow_key_next_year] } { 
        set msg "Can not show PORTLET. No data for Employee Evaluation Processes found. Table 'im_employee_evaluation_processes' needs to have at least one record with status 'Current' and one with status 'next'. Please contact your System Administrator."
        return [lang::message::lookup "" intranet-employee-evaluation.ParameterWorkflowKeyNotFound $msg]
    }

    # Get total number of employees
    set sql "select count(*) from acs_rels where object_id_one = :project_id_this_year and rel_type = 'im_biz_object_member'"
    set total_participants [db_string get_total_participants $sql -default 0]
    set total_participants_display $total_participants
    append total_participants e0

    set html_output "<strong>[lang::message::lookup "" intranet-employee-evaluation.TotalParticipants "Total Participants"]:</strong> $total_participants_display <br/><br/>"
    append html_output "<strong>[lang::message::lookup "" intranet-employee-evaluation.ActiveWorkflows: "Active Workflows"]:</strong> &nbsp;"

    # Get finished cases 
    set sql "
	select 
		count(*)
	from 
		im_employee_evaluations ee, 
		wf_cases c
	where 
		c.case_id = ee.case_id
		and ee.project_id = :project_id_this_year
		and c.state = 'finished'
    "
    set count_finished_wfs [db_string get_count_finished_wfs $sql -default 0]

    # Statistics 'Places'
    set sql "
        select
                p.place_name,
                s.count_cases
        from
              (
              select
                 (select place_key from wf_places where place_key = t.place_key and workflow_key=:workflow_key_this_year) as place_key,
                 count(*) as count_cases
              from
                 wf_tokens t
              where
                  state = 'free'
                  and t.workflow_key = :workflow_key_this_year
                  and t.case_id in (
                      select distinct case_id from im_employee_evaluations where project_id = :project_id_this_year
                  )
             group by
                   place_key
             ) s,
             wf_places p
        where
             p.place_key = s.place_key
        order by
             p.sort_order
    "

    set status_table_lines_html_active ""
    set total_started_wfs 0

    db_foreach r $sql {
        if { 0 != $count_cases } {
            set percentage [format "%.2f" [expr {double(round(100*[expr 100 * $count_cases / $total_participants]))/100}]]
        } else {
            set percentage 0
        }
        append status_table_lines_html_active "
                <tr>
                <td>$place_name</td>
                <td align='right'>$count_cases</td>
                <td align='right'>${percentage}%</td>
                </tr>
        "
        set total_started_wfs [expr $total_started_wfs + $count_cases]
    }

    if { "" != $status_table_lines_html_active || 0 != $count_finished_wfs } {
        append html_output "
                <br/><br/>
                <table cellpadding='5' cellspacing='5' border='0'>
                        <tr class='rowtitle'>
                        <td class='rowtitle'>[lang::message::lookup "" intranet-employee-evaluation.WfPlaceName "Place"]</td>
                        <td class='rowtitle' align='center'>[lang::message::lookup "" intranet-employee-evaluation.NumberCases "Number<br/>Cases"]</td>
                        <td class='rowtitle' align='center'>[lang::message::lookup "" intranet-employee-evaluation.Percent "Percent"]</td>
                        </tr>
                        $status_table_lines_html_active
                        <tr>
                                <td colspan='3'>&nbsp;</td>
                        </tr>
                        <tr>
                                <td><strong>[lang::message::lookup "" intranet-employee-evaluation.Finished "Finished"]</strong></td>
                                <td align='right'><strong>$count_finished_wfs</strong></td>
                                <td align='right'><strong>[format "%.2f" [expr {double(round(100*[expr 100 * $count_finished_wfs/$total_participants]))/100}]]%</strong></td>
                        </tr>
                        <tr>
                                <td><strong>[lang::message::lookup "" intranet-employee-evaluation.NotYetStarted "Not yet started"]</strong></td>
                                <td align='right'><strong>[expr $total_participants_display - $count_finished_wfs - $total_started_wfs]</strong></td>
                                <td align='right'><strong>[format "%.2f" [expr {double(round(100*[expr ($total_participants - $count_finished_wfs - $total_started_wfs)*100/$total_participants]))/100}]]%</strong></td>
                        </tr>
                </table>"
    } else {
        append html_output [lang::message::lookup "" intranet-employee-evaluation.NoWorkflowsStartedYet "No workflows started yet"]
    }

    return $html_output

}


ad_proc im_filestorage_employee_evaluation_component { user_id user_to_show_id user_name return_url} {
    Filestorage for Employee Evaluation
} {
    set user_path [im_filestorage_user_path $user_id]
    set folder_type "user"
    return [im_filestorage_base_component $user_id $user_to_show_id $user_name $user_path $folder_type]
}
