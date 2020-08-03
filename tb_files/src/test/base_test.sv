// License copy
//  ###########################################################################
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
//  ###########################################################################

// Use of Include Guards
//`ifndef _base_test_INCLUDED_
//`define _base_test_INCLUDED_


//-----------------------------------------------------------------------------------------------
//class:base_test
//In this we provide information about setting env_config and starting the base test
//------------------------------------------------------------------------------------------------
class base_test extends uvm_test;
	`uvm_component_utils(base_test)

//Declaring handles for different components
    	 tb envh;
       	 env_config e_cfg;
	 uart_config cfg;
	 master_agent_config w_cfg[];
	 slave_agent_config r_cfg[];
	 v_seq1 vseq;

         int no_of_ragent = 1;
 	 int no_of_wagent=1;
         int has_ragent = 1;
         int has_wagent = 1;
  //---------------------------------------------
  // Externally defined tasks and functions
  //---------------------------------------------
	extern function new(string name = "base_test" , uvm_component parent);
	extern function void configuration();
	extern function void build_phase(uvm_phase phase);
	extern task reset_phase(uvm_phase phase);
	extern task pre_reset_phase(uvm_phase phase);
  	extern task run_phase(uvm_phase phase);
endclass:base_test


//-----------------------------------------------------------------------------
// Constructor: new
// Initializes the config_template class object
//
// Parameters:
//  name - instance name of the config_template
//  parent - parent under which this component is created
//--------------


//---------------------------------------------------------------
function base_test::new(string name = "base_test" , uvm_component parent);
	super.new(name,parent);
endfunction:new


//------------------------------------------------------------------------------------------------
//function:configuration()
//This gives information about creating a component abd regestring the id to factory
//--------------------------------------------------------------------------------------------------
function void base_test::configuration();
 	 e_cfg.w_cfg=new[no_of_wagent];
         e_cfg.r_cfg=new[no_of_ragent];

	 if (has_wagent) 
	 begin
         w_cfg = new[no_of_wagent];
	 foreach(w_cfg[i]) 
	 	begin
         	w_cfg[i]=master_agent_config::type_id::create($sformatf("w_cfg[%0d]", i));
	  	if(!uvm_config_db #(virtual uart_if)::get(this,"","vif_0",w_cfg[i].vif))
	  	`uvm_fatal("VIF CONFIG","cannot get()interface vif from uvm_config_db. Have you set() it?") 
	  	w_cfg[i].is_active = UVM_ACTIVE;
          	e_cfg.w_cfg[i] = w_cfg[i];
          	end
          end
	
         if (has_ragent) 
	 begin
         r_cfg=new[no_of_ragent];
	 foreach(r_cfg[i]) 
	 	begin
         	r_cfg[i]=slave_agent_config::type_id::create($sformatf("r_cfg[%0d]",i));
	 	if(!uvm_config_db #(virtual uart_if)::get(this,"","vif_0",r_cfg[i].vif))
	 	`uvm_fatal("VIF CONFIG","cannot get() interface vif from uvm_config_db. Have you set() it?")
	 	r_cfg[i].is_active = UVM_ACTIVE;
	 	e_cfg.r_cfg[i]=r_cfg[i]; 
         	end
	 end	
         e_cfg.no_of_ragent = no_of_ragent;
         e_cfg.no_of_wagent = no_of_wagent;
									 
         e_cfg.has_ragent = has_ragent;
         e_cfg.has_wagent = has_wagent;
  endfunction: configuration


//-----------------------------------------------------------------------------
// Function: build_phase
// Creates the required ports
//
// Parameters:
//  phase - stores the current phase 
//-----------------------------------------------------------------------------
function void base_test::build_phase(uvm_phase phase);
	e_cfg=env_config::type_id::create("e_cfg");
        cfg=uart_config::type_id::create("cfg");
        if (!cfg.randomize())
         `uvm_error("RNDFAIL", "Could not randomize uart_config using default values")
      `uvm_info(get_type_name(), {"Printing cfg:\n", cfg.sprint()}, UVM_MEDIUM)
 
	if(has_wagent)
        e_cfg.w_cfg = new[no_of_wagent];
          
	if(has_ragent)
        e_cfg.r_cfg = new[no_of_ragent];


    	configuration();
	uvm_config_db #(env_config)::set(this,"*","env_config",e_cfg);
	uvm_config_db #(uart_config)::set(this,"*","cfg",cfg);
        super.build_phase(phase);
	envh=tb::type_id::create("envh", this);
endfunction:build_phase

  //--------------------------------------------------------------------------------
  //Task:run_phase
  //--------------------------------------------------------------------------------
task base_test::pre_reset_phase(uvm_phase phase);
	`uvm_info("","BASE TEST PRE RESET PHASE",UVM_LOW)
endtask

task base_test::reset_phase(uvm_phase phase);
	`uvm_info("","BASE TEST RESET PHASE",UVM_LOW)
endtask

task base_test::run_phase(uvm_phase phase);
	v_seq1 vseq = v_seq1::type_id::create("vseq");
	vseq.print();
     `uvm_info(get_type_name(),"BASE TEST RUN PHASE",UVM_LOW)
      phase.raise_objection(this);
      `uvm_info(get_type_name(),"TEST STARTED",UVM_LOW)
      vseq.start(envh.v_seqrh);
      #10;
      phase.drop_objection(this);
endtask



