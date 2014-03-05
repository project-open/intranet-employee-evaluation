-- /packages/intranet-employee-evaluation/sql/postgresql/intranet-employee-evaluation-drop.sql
--
-- Copyright (c) 2003-now ]project-open[
--
-- All rights reserved. Please check
-- http://www.project-open.com/license/ for details.
--
-- @author klaus.hofeditz@project-open.com

-- --------------------------------------------------------------
-- Tables 
-- --------------------------------------------------------------

-- Drop sequences 

drop sequence im_employee_evaluation_questions_tree_seq;
drop sequence im_employee_evaluation_groups_seq;
drop sequence im_employee_evaluation_group_questions_map_seq;
drop sequence im_employee_evaluation_config_seq;
drop sequence im_employee_evaluation_panel_group_map_seq;

delete from im_employee_evaluation_config;
drop table im_employee_evaluation_config;

delete from im_employee_evaluation_panel_group_map;
drop table im_employee_evaluation_panel_group_map;

delete from im_employee_evaluation_group_questions_map;
drop table im_employee_evaluation_group_questions_map;

delete from im_employee_evaluation_questions_tree;
drop table im_employee_evaluation_questions_tree;

delete from im_employee_evaluation_groups;
drop table im_employee_evaluation_groups;

delete from im_employee_evaluations;
drop table im_employee_evaluations;

delete from acs_objects where object_type = 'im_employee_evaluation';
delete from acs_object_type_tables where object_type = 'im_employee_evaluation';
delete from acs_object_types where object_type = 'im_employee_evaluation';


CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count                 integer;
        v_survey_id             integer;
        v_package_id            integer;
	r                       record;
	s                       record;		
begin

        select package_id into v_package_id from apm_packages where package_key = 'intranet-employee-evaluation';
        select count(*) into v_count from survsimp_surveys where package_id = v_package_id;

        IF 0 <> v_count THEN
                FOR r IN select survey_id from survsimp_surveys where package_id = v_package_id
                LOOP
                        FOR s IN select question_id from survsimp_questions where survey_id = r.survey_id
                        LOOP
                                delete from survsimp_question_choices where question_id = s.question_id;
                        END LOOP;

                        delete from survsimp_responses where survey_id = r.survey_id;
                        delete from survsimp_questions where survey_id = r.survey_id;
                        delete from survsimp_logic_surveys_map where survey_id = r.survey_id;
                        -- todo: survsimp_variables_surveys_map, survsimp_variables

                        delete from survsimp_surveys where survey_id = r.survey_id;

                END LOOP;
        END IF;
        return 0;

end;$BODY$ LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();



