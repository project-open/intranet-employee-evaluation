-- /packages/intranet-employee-evaluation/sql/postgres/intranet-employee-evaluation-create.sql

-- Copyright (C) 1998-2014 various parties
-- The software is based on ArsDigita ACS 3.4

-- --------------------------------------------------------------
-- Create new object type 
-- --------------------------------------------------------------

-- Unassigned callback that assigns the transition to the supervisor of the owner
-- of the underlying object

create or replace function im_employee_evaluation__assign_to_employee (integer, text)
returns integer as '
declare
        p_task_id               alias for $1;
        p_custom_arg            alias for $2;
        v_case_id               integer;        v_object_id             integer;
        v_creation_user         integer;        v_creation_ip           varchar;
        v_journal_id            integer;        v_object_type           varchar;
        v_employee_id           integer;        v_employee_name         varchar;
        v_transition_key        varchar;
        v_str                   text;
        row                     RECORD;
begin
        -- Get information about the transition and the "environment"
        select  tr.transition_key, t.case_id, c.object_id, o.creation_user, o.creation_ip, o.object_type
        into    v_transition_key, v_case_id, v_object_id, v_creation_user, v_creation_ip, v_object_type
        from    wf_tasks t, wf_cases c, wf_transitions tr, acs_objects o
        where   t.task_id = p_task_id
                and t.case_id = c.case_id
                and o.object_id = t.case_id
                and t.workflow_key = tr.workflow_key
                and t.transition_key = tr.transition_key;

        select  e.employee_id, im_name_from_user_id(e.employee_id)
        into    v_employee_id, v_employee_name
        from    
		im_employees e,
		im_employee_evaluations ee
        where   
		ee.case_id = v_case_id
		and ee.employee_id = e.employee_id;

        IF v_employee_id is not null THEN
                v_journal_id := journal_entry__new(
                    null, v_case_id,
                    v_transition_key || '' assign_to_employee '' || v_employee_name,
                    v_transition_key || '' assign_to_employee '' || v_employee_name,
                    now(), v_creation_user, v_creation_ip,
                    ''Assigning to '' || v_employee_name || ''.''
                );
                PERFORM workflow_case__add_task_assignment(p_task_id, v_employee_id, ''f'');
                PERFORM workflow_case__notify_assignee (p_task_id, v_employee_id, null, null,
                        ''wf_'' || v_object_type || ''_assignment_notif'');
        END IF;
        return 0;
end;' language 'plpgsql';

-- Create new Project Type 
SELECT im_category_new ('104', 'Employee Evaluation', 'Intranet Project Type');


-- Create Employee Evaluation ACS object
CREATE OR REPLACE FUNCTION inline_0 () RETURNS integer AS $BODY$
declare
        attribute_id                 integer;
begin
	-- Create a new DynField: 'Deadline Employee Evaluation'
        SELECT im_dynfield_attribute_new (
                'im_project',                          -- p_object_type
                'deadline_employee_evaluation',	       -- p_column_name
                'Deadline Employee Evaluation',	       -- p_pretty_name
                'date',				       -- p_widget_name
                'date',                                -- p_datatype
                't',                                   -- p_required_p
                 0,                                    -- p_pos_y
                'f',                                   -- p_also_hard_coded_p
                'im_projects'                          -- p_table_name
        ) into attribute_id;

	return 0;
	-- set im_dynfield_type_attribute_map
	-- insert into im_dynfield_type_attribute_map ( attribute_id, object_type_id, display_mode) values (:attribute_id, :object_type_id, :new_val); 

end;$BODY$ LANGUAGE 'plpgsql';
select inline_0 ();
DROP FUNCTION inline_0 ();

-- Create Employee Evaluation ACS object 
CREATE OR REPLACE FUNCTION inline_0 () RETURNS integer AS $BODY$
declare
        v_count                 integer;
begin

	select count(*) into v_count from acs_objects where object_type = 'im_employee_evaluation';

	IF v_count = 0 THEN 
		select acs_object_type__create_type (
               'im_employee_evaluation',       -- object_type
	       'Employee Evaluation',          -- pretty_name
	       'Employee Evaluation',          -- pretty_plural
	       'im_biz_object',            	-- supertype
	       'im_employee_evaluations',      -- table_name
               'employee_evaluation_id',  	-- id_column
               'intranet-employee-evaluation',		-- package_name
               'f',                    		-- abstract_p
               '',			       -- type_extension_table
               'im_employee_evaluation__name'   -- name_method
	       ) into v_count;

	       insert into acs_object_type_tables (object_type,table_name,id_column) values ('im_employee_evaluation', 'im_employee_evaluations', 'employee_evaluation_id');
	END IF; 

	return 0; 

end;$BODY$ LANGUAGE 'plpgsql';
select inline_0 ();
DROP FUNCTION inline_0 ();


create or replace function im_employee_evaluation__name(integer)
returns varchar as $BODY$
DECLARE
        p_employee_evaluation_id             alias for $1;
	v_employee_id			     integer;
	v_name_order_id			     integer;
        v_employee_name                      varchar;
BEGIN

	-- Get Name Order
	select v.attr_value into v_name_order_id
	from apm_parameters p,apm_parameter_values v 
	where p.parameter_id = v.parameter_id and p.parameter_name = 'NameOrder' and p.package_key = 'intranet-core';
	
	-- Get employee_id
	select employee_id into v_employee_id from im_employee_evaluations where employee_evaluation_id = p_employee_evaluation_id;  

	-- Get name 
        select im_name_from_user_id(v_employee_id, v_name_order_id) into v_employee_name from dual;

        return v_employee_name;

end;$BODY$ language 'plpgsql';

-- update acs_object_types set
--        status_type_table = 'im_projects',
--        status_column = 'project_status_id',
--        type_column = 'project_type_id'
-- where object_type = 'im_project';

-- --------------------------------------------------------------
-- Extend constraint
-- --------------------------------------------------------------

ALTER TABLE survsimp_questions DROP CONSTRAINT survsimp_q_pres_type_ck;
ALTER TABLE survsimp_questions ADD CONSTRAINT survsimp_q_pres_type_ck check (presentation_type in ('textbox','textarea','select','radio', 'checkbox', 'date', 'upload_file', 'none','combined_type_one','combined_type_two'));

-- --------------------------------------------------------------
-- Data Layer
-- --------------------------------------------------------------

create sequence im_employee_evaluation_processes_seq;
create table im_employee_evaluation_processes (
       id				integer
					primary key,
       name                  		varchar(100)
       					NOT NULL,
       project_id			integer
					constraint project_id_fk
                                        references im_projects
					NOT NULL
					UNIQUE,
       survey_name			varchar(100)
       					NOT NULL,
       workflow_key			varchar(50),					
       line_break_function		varchar(50),					
       validation_function		varchar(50),					
       transition_name_printing         varchar(50),
       evaluation_year			integer
       					NOT NULL,
       status				varchar(50)
					NOT NULL					
);

ALTER TABLE im_employee_evaluation_processes ADD CONSTRAINT im_employee_evaluation_processes_status_ck check (status in ('Current','Next','Finished'));

-- Manage Evaluations
-- Avoid two WF cases for one EE project 
create table im_employee_evaluations (
           employee_evaluation_id       integer
                                        primary key,
           project_id                   integer
	   				constraint project_id_fk
					references im_projects,
           employee_id                 	integer
	   				constraint employee_id_fk
					references im_employees,
           supervisor_id               	integer
					references im_employees,
           case_id                  	integer
	   				constraint case_id_fk
					references wf_cases,
	   survey_id			integer
	                                constraint survey_id_fk
                                        references survsimp_surveys,
	   workflow_key			varchar(100)
	                                constraint worflow_key_fk
                                        references wf_workflows,
	   UNIQUE (project_id, employee_id, survey_id)
);


-- Manage relationships btw. questions
-- Used for combined response type, e.g. "combined_type_one"
create sequence im_employee_evaluation_questions_tree_seq;
create table im_employee_evaluation_questions_tree (
           id                           integer
                                        primary key,
           parent_question_id           integer
                                        constraint parent_question_id_fk
                                        references survsimp_questions,
           child_question_id            integer
                                        constraint child_question_id_fk
                                        references survsimp_questions
);


-- Managing grouping of questions
create sequence im_employee_evaluation_groups_seq;
create table im_employee_evaluation_groups (
           group_id                     integer
                                        primary key,
           group_name                   varchar(100),
           grouping_type                varchar(50) -- e.g.: 'display'
);


-- Grouping is needed for layout, workflow or functional (e.g. statistical) purposes
create sequence im_employee_evaluation_group_questions_map_seq;
create table im_employee_evaluation_group_questions_map (
           id                           integer
                                        primary key,
           group_id                     integer
                                        constraint group_id_fk
                                        references im_employee_evaluation_groups,
           question_id                  integer
                                        constraint question_id_fk
                                        references survsimp_questions,
           sort_key                     integer
);


-- Mapping groups to wf_panels, a WF transition panel can have one or more groups
create sequence im_employee_evaluation_panel_group_map_seq;
create table im_employee_evaluation_panel_group_map (
       id				integer
					primary key,
       survey_id			integer
					constraint survey_id_fk
                                        references survsimp_surveys,
       wf_task_name                	varchar(100),
       group_id                         integer
                                        constraint group_id_fk
                                        references im_employee_evaluation_groups
);


-- Manage visibility of questions when shown in WF
create sequence im_employee_evaluation_config_seq;
create table im_employee_evaluation_config (
           id                           integer
                                        primary key,
           question_id                  integer
                                        constraint question_id_fk
                                        references survsimp_questions,
           wf_role			varchar(100), 
           wf_task_name            	varchar(100),
           read_p                    	boolean,
           write_p                    	boolean,	   
           admin_p                    	boolean
);

ALTER TABLE im_employee_evaluation_config ADD CONSTRAINT im_employee_evaluation_config_wf_role_ck check (wf_role in ('Employee','Assignee','Supervisor'));


-- --------------------------------------------------------------
-- Create Plugins
-- --------------------------------------------------------------

-- Employee Component Plugin that provides access to past and current EE 
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count               integer;
	v_plugin_id 	      integer;
        v_employees           integer;
begin
	SELECT  im_component_plugin__new (
	        null,                           -- plugin_id
        	'acs_object',                   -- object_type
		now(),                          -- creation_date
		null,                           -- creation_user
		null,                           -- creation_ip
        	null,                           -- context_id
        	'Employee Evaluation', -- plugin_name
        	'intranet-employee-evaluation', -- package_name
        	'left',                        -- location
        	'/intranet-employee-evaluation/index', -- page_url
        	null,                           -- view_name
        	5,                              -- sort_order
        	'im_employee_evaluation_employee_component $current_user_id' -- component_tcl
	) into v_plugin_id;

	select group_id into v_employees from groups where group_name = 'Employees';
        PERFORM im_grant_permission(v_plugin_id, v_employees, 'read');

	return 0; 

end;$BODY$ LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();


-- Employee Component Plugin that provides access to past and current EE
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count               integer;
        v_plugin_id           integer;
        v_employees           integer;
begin
        SELECT  im_component_plugin__new (
                null,                           -- plugin_id
                'acs_object',                   -- object_type
                now(),                          -- creation_date
                null,                           -- creation_user
                null,                           -- creation_ip
                null,                           -- context_id
                'Employee Evaluation for Supervisors',          -- plugin_name
                'intranet-employee-evaluation', -- package_name
                'right',                        -- location
                '/intranet-employee-evaluation/index', -- page_url
                null,                           -- view_name
                10,                              -- sort_order
                'im_employee_evaluation_supervisor_component $current_user_id' -- component_tcl
        ) into v_plugin_id;

        select group_id into v_employees from groups where group_name = 'Employees';
        PERFORM im_grant_permission(v_plugin_id, v_employees, 'read');

        return 0;

end;$BODY$ LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();


-- Component Plugin Filestorage EE
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count               integer;
        v_plugin_id           integer;
        v_employees           integer;
begin

	SELECT im_component_plugin__new (
               null,								-- plugin_id
	       'im_component_plugin',						-- object_type
	       now(),	       							-- creation_date
               null,								-- creation_user
               null,								-- creation_ip
               null,								-- context_id
               'Employee Evaluation Filestorage Component',  			-- plugin_name
               'intranet-employee-evaluation/',         			-- package_name
               'right',								-- location
               '/intranet-employee-evaluation/index',         			-- page_url
               null,								-- view_name
               90,                             					-- sort_order
               'im_filestorage_employee_evaluation_component $current_user_id $current_user_id $name $return_url' -- component_tcl
	) into v_plugin_id;

        select group_id into v_employees from groups where group_name = 'Employees';
        PERFORM im_grant_permission(v_plugin_id, v_employees, 'read');

        return 0;

end;$BODY$ LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();


-- Statistics
CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count               integer;
        v_plugin_id           integer;
        v_hr_managers         integer;
begin
        SELECT  im_component_plugin__new (
                null,                           -- plugin_id
                'acs_object',                   -- object_type
                now(),                          -- creation_date
                null,                           -- creation_user
                null,                           -- creation_ip
                null,                           -- context_id
                'Progress', -- plugin_name
                'intranet-employee-evaluation', -- package_name
                'right',                        -- location
                '/intranet-employee-evaluation/index',         -- page_url
                null,                           -- view_name
                5,                              -- sort_order
                'im_employee_evaluation_statistics_current_project $current_user_id' -- component_tcl
        ) into v_plugin_id;

        select group_id into v_hr_managers from groups where group_name = 'HR Managers';
        PERFORM im_grant_permission(v_plugin_id, v_hr_managers, 'read');

        return 0;

end;$BODY$ LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();



-- --------------------------------------------------------------
-- Create Menu
-- --------------------------------------------------------------

create or replace function inline_1 ()
returns integer as $BODY$
declare
        v_menu                  integer;
        v_parent_menu           integer;
        v_employees             integer;
begin
        select group_id into v_employees from groups where group_name = 'Employees';
        select menu_id into v_parent_menu from im_menus where label = 'main';
 
        v_menu := im_menu__new (
                null,                                   -- p_menu_id
                'im_menu',                              -- object_type
                now(),                                  -- creation_date
                null,                                   -- creation_user
                null,                                   -- creation_ip
                null,                                   -- context_id
                'intranet-employee-evaluation',   	-- package_name
                'employee-evaluation',			-- label
                'Employee Evaluation',			-- name
                '/intranet-employee-evaluation',   	-- url
                500,                                    -- sort_order
                v_parent_menu,                          -- parent_menu_id
                null                                    -- p_visible_tcl
        );
 
        PERFORM acs_permission__grant_permission(v_menu, v_employees, 'read');

        return 0;
end;$BODY$ language 'plpgsql';
select inline_1 ();
drop function inline_1();
