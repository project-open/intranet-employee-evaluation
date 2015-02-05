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

ad_page_contract {

    Insert user response into database.
    This page receives an input for each question named
    response_to_question.$question_id 

    @param   survey_id             survey user is responding to
    @param   return_url            optional redirect address
    @param   group_id              
    @param   response_to_question  since form variables are now named as response_to_question.$question_id, this is actually array holding user responses to all survey questions.
    @param   task_id		   Optionally specified workflow task_id from acs-workflow.
				   Behave like the user would have clicked the "Task done" button.
    
    @author  jsc@arsdigita.com
    @author  nstrug@arsdigita.com
    @author  klaus.hofeditz@project-open.com

    @creation-date    28th September 2000
    @cvs-id $Id$
} {
    survey_id:integer,notnull
    related_object_id 
    { return_url:optional }
    { response_to_question:array,optional,multiple,allhtml }
    { related_context_id:integer "" }
    { task_id "" }
    { task_name "" }
    { role "" }
    { group_id "" }
    { save_btn ""}
	{ save_btn_private "" }
    { save_and_finish_btn "" }
    { cancel_btn "" }

} -validate {

    custom_validation {
	    set sql "
			select 
				eep.validation_function 
			from 
				im_employee_evaluation_processes eep,
				im_employee_evaluations ee
			where 
				ee.survey_id = :survey_id 
				and ee.project_id = eep.project_id
            	and ee.employee_id = :related_object_id
		"
		set custom_validation_function [db_string get_data $sql -default ""]

		if { "" != $custom_validation_function } {
            set val_result [$custom_validation_function \
                                                $survey_id \
                                               	$related_object_id \
												[array get response_to_question] \
                                                $related_object_id \
                                                $related_context_id \
                                                $task_id \
                                                $task_name \
                                                $role \
												$group_id ]

	    	if { "" != $val_result } {
				ad_complain $val_result
	    	}
		}
    }

    cancel { 
		if { "" != $cancel_btn } {
			ns_log NOTICE "intranet-employee-evaluation::process-response - Cancelation"
			ad_returnredirect /intranet/
		}
    }

    survey_exists -requires { survey_id } {
	if ![db_0or1row survey_exists {
	    select 1 from survsimp_surveys where survey_id = :survey_id
	}] {
	    ad_complain "Survey $survey_id does not exist"
	}
    }

    check_questions -requires { survey_id:integer } {
	# Validate input
        set current_user_id [ad_maybe_redirect_for_registration] 
	if { $current_user_id == $related_object_id } {
	    set wf_role "Employee"
	} else {
	    set wf_role "Supervisor"
	}

	set question_info_list [db_list_of_lists survsimp_question_info_list {
            select
                q.question_id, q.question_text, q.abstract_data_type, q.presentation_type, q.required_p
            from
                survsimp_questions q,
                im_employee_evaluation_group_questions_map gqm,
                im_employee_evaluation_config cfg
            where
                q.survey_id = :survey_id
                and cfg.write_p = 't'
	    	and cfg.wf_role = :wf_role
		and cfg.wf_task_name = :task_name
                and gqm.group_id = :group_id
	    	and q.presentation_type <> 'none'
	    	and q.presentation_type not in ('combined_type_one', 'combined_type_two')
                and cfg.question_id = q.question_id
                and q.question_id = gqm.question_id
                and active_p = 't'

	    UNION 
	        -- get child questions
	    	select
                	q.question_id, q.question_text, q.abstract_data_type, q.presentation_type, q.required_p
           	from
                	survsimp_questions q
	    	where 
	    		q.question_id in (
			          select 
				  	tree.child_question_id
				  from 
				  	im_employee_evaluation_questions_tree tree,
				        im_employee_evaluation_config cfg
				  where 
				  	tree.parent_question_id in (
						      select
								  q.question_id
						      from
								  survsimp_questions q,
								  im_employee_evaluation_group_questions_map gqm,
								  im_employee_evaluation_config cfg
						      where
								  q.survey_id = :survey_id
								  and cfg.question_id = q.question_id
								  and q.question_id = gqm.question_id
								  and gqm.group_id = :group_id
								  and active_p = 't'
								  and cfg.write_p = 't'
								  and cfg.wf_task_name = :task_name
								  and q.presentation_type in ('combined_type_one', 'combined_type_two')
						      		  
						      )
				       and tree.child_question_id = cfg.question_id 
				       and cfg.write_p = 't'
				       and cfg.wf_task_name = :task_name
				       and cfg.wf_role = :wf_role 
				  )

	}]
	    
	if { "" == $question_info_list } { 
	    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-avaluation.NoQuestionFound "Did not find any questions ralated to this Panel, please verify"]
        }
	set questions_with_missing_responses [list]

	# Costum validation check 
	set sum_weight 0 
	set description_ctr 0

	ns_log NOTICE "intranet-employee-evaluation::process-response - Validating: question_info_list: $question_info_list"

	foreach question $question_info_list { 

	    set question_id [lindex $question 0]
	    set question_text [lindex $question 1]
	    set abstract_data_type [lindex $question 2]
	    set required_p [lindex $question 4]

	    #  Need to clean-up after mess with :array,multiple flags
	    #  in ad_page_contract.  Because :multiple flag will sorround empty
	    #  strings and all multiword values with one level of curly braces {}
	    #  we need to get rid of them for almost any abstract_data_type
	    #  except 'choice', where this is intended behaviour.  Why bother
	    #  with :multiple flag at all?  Because otherwise we would lost all
	    #  but first value for 'choice' abstract_data_type - see ad_page_contract
	    #  doc and code for more info.
	    #
	    if { [exists_and_not_null response_to_question($question_id)] } {
		if {$abstract_data_type != "choice"} {
		    set response_to_question($question_id) [join $response_to_question($question_id)]
		}
	    }
	    
	    if { $abstract_data_type == "date" } {
		if [catch  { 
		    set response_to_question($question_id) [validate_ad_dateentrywidget "" response_to_question.$question_id [ns_getform]]
		} errmsg] {
		    ad_complain "$errmsg: Please make sure your dates are valid."
		}
	    }
	    
	    if { [exists_and_not_null response_to_question($question_id)] } {
		set response_value [string trim $response_to_question($question_id)]
	    } elseif {$required_p == "t"} {
		lappend questions_with_missing_responses $question_text
		continue
	    } else {
		set response_to_question($question_id) ""
		set response_value ""
	    }
	    
	    if {![empty_string_p $response_value]} {
		if { $abstract_data_type == "number" } {
		    if { ![regexp {^(-?[0-9]+\.)?[0-9]+$} $response_value] } {
			
			ad_complain "The response to \"$question_text\" must be a number. Your answer was \"$response_value\"."
			continue
		    }
		} elseif { $abstract_data_type == "integer" } {
		    if { ![regexp {^[0-9]+$} $response_value] } {
			
			ad_complain "The response to \"$question_text\" must be an integer. Your answer was \"$response_value\"."
			continue
		    }
		}
	    }
	    
	    if { $abstract_data_type == "blob" } {
                set tmp_filename $response_to_question($question_id.tmpfile)
		set n_bytes [file size $tmp_filename]
		if { $n_bytes == 0 && $required_p == "t" } {
		    ad_complain "Your file is zero-length. Either you attempted to upload a zero length file, a file which does not exist, or something went wrong during the transfer."
		}
	    }
	}

	if { [llength $questions_with_missing_responses] > 0 } {
	    ad_complain "You didn't respond to all required sections. You skipped:"
	    foreach skipped_question $questions_with_missing_responses {
		ad_complain $skipped_question
	    }
	    return 0
	} else {
	    return 1
	}
    }
} -properties {
    survey_name:onerow
}

# -----------------------------------------------------
# Check if user is allowed to take survey
# -----------------------------------------------------
# ad_require_permission $survey_id survsimp_take_survey

set user_id [ad_verify_and_get_user_id]
set response_id [db_nextval acs_object_id_seq]
set creation_ip [ad_conn peeraddr]
set user_name [im_name_from_user_id $user_id]

# -----------------------------------------------------
# Do the inserts.
# -----------------------------------------------------

db_transaction {

    ns_log NOTICE "intranet-employee-evaluation::process-response - Saving .... "

    db_exec_plsql create_response {
	begin
	    :1 := survsimp_response.new (
		response_id => :response_id,
		survey_id => :survey_id,		
		context_id => :survey_id,
		creation_user => :user_id
	    );
	end;
    }
   
    db_dml update_oid "
	update survsimp_responses set
		related_object_id = :related_object_id,
		related_context_id = :related_context_id
	where response_id = :response_id
    "

    ns_log NOTICE "intranet-employee-evaluation::process-response - question_info_list: $question_info_list"
    
    # Something is wrong when there's an empty list
    if { "" == $question_info_list } { 
	ad_return_complaint 1 [lang::message::lookup "" intranet-employee-avaluation.NoQuestionFound "Did not find any questions ralated to this Panel, please verify"]
    }

    foreach question $question_info_list { 
	set question_id [lindex $question 0]
	set question_text [lindex $question 1]
	set abstract_data_type [lindex $question 2]
	set presentation_type [lindex $question 3]
	set response_value [string trim $response_to_question($question_id)]

	# 2nd check for check_write_permissions 
	if { ![db_string get_write_permission "select write_p from im_employee_evaluation_config where question_id=:question_id and wf_role=:wf_role and wf_task_name=:task_name" -default 0] } {
	    ns_log NOTICE "Denied writing response for question_id: $question_id by user_id :$user_id due to missing permissions."
	    ad_return_complaint 1 [lang::message::lookup "" intranet-employee-evaluation.WritingResponseDenied "No 'write' permission for question_id: $question_id by user_id :$user_id (role: $wf_role), please contact your System Administrator"]
	}

	ns_log NOTICE "intranet-employee-evaluation::process-response - Saving: question_id: $question_id, abstract_data_type: $abstract_data_type, presentation_type: presentation_type, response_value: $response_value"

	switch -- $abstract_data_type {
	    "choice" {
		if { $presentation_type == "checkbox" } {
		    # Deal with multiple responses. 
		    set checked_responses $response_to_question($question_id)
		    foreach response_value $checked_responses {
			if { [empty_string_p $response_value] } {
			    set response_value [db_null]
			}

			db_dml survsimp_question_response_checkbox_insert "insert into survsimp_question_responses (response_id, question_id, choice_id) values (:response_id, :question_id, :response_value)"
		    }
		}  else {
		    if { [empty_string_p $response_value] } {
			set response_value [db_null]
		    }

		    db_dml survsimp_question_response_choice_insert "insert into survsimp_question_responses (response_id, question_id, choice_id) values (:response_id, :question_id, :response_value)"
		}
	    }
	    "shorttext" {
		db_dml survsimp_question_choice_shorttext_insert "insert into survsimp_question_responses (response_id, question_id, varchar_answer) values (:response_id, :question_id, :response_value)"
	    }
	    "boolean" {
		if { [empty_string_p $response_value] } {
		    set response_value [db_null]
		}

		db_dml survsimp_question_response_boolean_insert "insert into survsimp_question_responses (response_id, question_id, boolean_answer) values (:response_id, :question_id, :response_value)"
	    }
	    "number" {
                if { [empty_string_p $response_value] } {
                    set response_value [db_null]
                } 
		db_dml survsimp_question_response_integer_insert "insert into survsimp_question_responses (response_id, question_id, number_answer) values (:response_id, :question_id, :response_value)"
	    }

	    "integer" {
                if { [empty_string_p $response_value] } {
                    set response_value [db_null]
                } 

		db_dml survsimp_question_response_integer_insert "insert into survsimp_question_responses (response_id, question_id, number_answer) values (:response_id, :question_id, :response_value)"
	    }
	    "text" {
                if { [empty_string_p $response_value] } {
                    set response_value [db_null]
                }

		# fraber 060103: missing variable clob_answer in .xql file
		set clob_answer $response_value

		db_dml survsimp_question_response_text_insert "
			insert into survsimp_question_responses (response_id, question_id, clob_answer) values (:response_id, :question_id, empty_clob()) returning clob_answer into :1
		" -clobs [list $response_value]
	    }
	    "date" {
                if { [empty_string_p $response_value] } {
                    set response_value [db_null]
                }

		db_dml survsimp_question_response_date_insert "insert into survsimp_question_responses (response_id, question_id, date_answer) values (:response_id, :question_id, :response_value)"
	    }   
            "blob" {
                if { ![empty_string_p $response_value] } {
                    # this stuff only makes sense to do if we know the file exists
		    set tmp_filename $response_to_question($question_id.tmpfile)
                    set file_extension [string tolower [file extension $response_value]]
                    # remove the first . from the file extension
                    regsub {\.} $file_extension "" file_extension
                    set guessed_file_type [ns_guesstype $response_value]

                    set n_bytes [file size $tmp_filename]
                    # strip off the C:\directories... crud and just get the file name
                    if ![regexp {([^/\\]+)$} $response_value match client_filename] {
                        # couldn't find a match
                        set client_filename $response_value
                    }
                    if { $n_bytes == 0 } {
                        error "This should have been checked earlier."
                    } else {

			### add content repository support
			# 1. create new content item
			# 2. create relation between user and content item
			# 3. create a new empty content revision and make live
			# 4. update the cr_revisions table with the blob data
			# 5. update the survey table
			db_transaction {
			    set name "blob-response-$response_id"

			    set item_id [db_exec_plsql create_item "
				begin
				:1 := content_item.new (
				    name => :name,
				    creation_ip => :creation_ip);
				end;"]

			    set rel_id [db_exec_plsql create_rel "
				begin
				:1 := acs_rel.new (
				    rel_type => 'user_blob_response_rel',
				    object_id_one => :user_id,
				    object_id_two => :item_id);
				end;"]

			    set revision_id [db_exec_plsql create_revision "
				begin
				:1 := content_revision.new (
				    title => 'A Blob Response',
				    item_id => :item_id,
				    text => 'not_important',
				    mime_type => :guessed_file_type,
				    creation_date => sysdate,
				    creation_user => :user_id,
				    creation_ip => :creation_ip);

				update cr_items
				set live_revision = :1
				where item_id = :item_id;
				
				end;"]

			    db_dml update_response "
				update cr_revisions
				set content = empty_blob()
				where revision_id = :revision_id
				returning content into :1" -blob_files [list $tmp_filename]

			    set content_length [cr_file_size $tmp_filename]

			    db_dml survsimp_question_response_blob_insert "
				insert into survsimp_question_responses 
				(response_id, question_id, item_id, 
				content_length,
				attachment_file_name, attachment_file_type, 
				attachment_file_extension)
				values 
				(:response_id, :question_id, :item_id, 
				:content_length,
				:response_value, :guessed_file_type, 
				:file_extension)
			    "
			}
		    }
                }
            }
	}
    }
} on_error {
    ad_return_complaint 1 "Database Error. There was an error while trying to process your response: $errmsg"
    return
}

# -----------------------------------------------------
# Workflow Action
# -----------------------------------------------------"


# ad_return_complaint xx "survey_id: $survey_id, related_object_id $related_object_id"

set sql "
        select
            ee.employee_evaluation_id
        from
            im_employee_evaluation_processes eep,
            im_employee_evaluations ee
        where
            ee.survey_id = :survey_id
            and ee.project_id = eep.project_id
            and ee.employee_id = :related_object_id
"
set employee_evaluation_id [db_string get_data $sql -default ""]

set blocked_for_supervisor_sql "update im_employee_evaluations set temporarily_blocked_for_supervisor_p = :temporarily_blocked_for_supervisor_p where employee_evaluation_id = :employee_evaluation_id"
set blocked_for_employee_sql "update im_employee_evaluations set temporarily_blocked_for_employee_p = :temporarily_blocked_for_employee_p where employee_evaluation_id = :employee_evaluation_id"

# Close the workflow task if task_id is available
if { "" != $task_id && "" != $save_and_finish_btn } {
    set the_action "finish"
    set message [lang::message::lookup "" simple-survey.Task_finished_by_simple_survey "Task: $task_name finished by: $user_name"]

    set journal_id [wf_task_action \
			-user_id $user_id \
			-msg $message \
			-attributes {} \
			-assignments {} \
			$task_id \
			$the_action \
	]

    set next_task_id [db_string get_next_task_id "select task_id from wf_tasks where case_id in (select case_id from wf_tasks where task_id=:task_id) and state='enabled'" -default 0]
    set task_assignee_p [db_string get_task_assignee "select count(*) from wf_task_assignments where task_id = :next_task_id and party_id = :user_id" -default 0] 

	# Remove block flag
	set temporarily_blocked_for_supervisor_p FALSE
	db_dml set_temporarily_blocked_for_supervisor_p $blocked_for_supervisor_sql

    if { $task_assignee_p } {
		ad_returnredirect "/acs-workflow/task?task_id=$next_task_id"
    } else {
		ad_returnredirect "/intranet-employee-evaluation/next-step?next_task_id=$next_task_id"
    }
} else {
    # Save button
    # Handle special case that Objectives for next year have been entered
    set sql "
	select 
		eep.status 
	from 
		im_employee_evaluation_processes eep,
		im_employee_evaluations ee
	where 
		ee.survey_id = :survey_id 
		and ee.project_id = eep.project_id
		and ee.employee_id = :related_object_id 		
    "
    set status [db_string get_status $sql -default ""]
    if { "Next" == $status } {
		ad_returnredirect "/intranet-employee-evaluation/handle-next-year-save-action?task_id=$task_id"	
    } else {
		
		if { "" != $save_btn_private } {
			# Set "private" flag
			if { "Employee" == $wf_role } {
				set temporarily_blocked_for_supervisor_p TRUE
				db_dml set_temporarily_blocked_for_supervisor_p $blocked_for_supervisor_sql
			} else {
				set temporarily_blocked_for_employee_p TRUE
				db_dml set_temporarily_blocked_for_employee_p $blocked_for_employee_sql
			}
		} else {
			# Remove block flag
            if { "Employee" == $wf_role } {
				set temporarily_blocked_for_supervisor_p FALSE
				db_dml set_temporarily_blocked_for_supervisor_p $blocked_for_supervisor_sql
			} else {
                set temporarily_blocked_for_employee_p FALSE
                db_dml set_temporarily_blocked_for_employee_p $blocked_for_employee_sql			
			}
		}
		ad_returnredirect "/acs-workflow/task?task_id=$task_id"
    }
}
