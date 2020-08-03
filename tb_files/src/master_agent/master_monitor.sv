//  ################################################################################################
//
//  Licensed to the Apache Software Foundation (ASF) under one or more contributor license 
//  agreements. See the NOTICE file distributed with this work for additional information
//  regarding copyright ownership. The ASF licenses this file to you under the Apache License,
//  Version 2.0 (the"License"); you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software distributed under the 
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
//  either express or implied. See the License for the specific language governing permissions and 
//  limitations under the License.
//
//  ################################################################################################
// Use of Include Guards
//`ifndef _master_monitor_INCLUDED_
//`define _master_monitor_INCLUDED_


//------------------------------------------------------------------------------------------------//
//  Class: master_monitor
//  The user-defined monitor is extended from uvm_monitor, uvm_monitor is inherited by uvm_component.
//  A monitor is a passive entity that samples the DUT signals through the virtual interface and 
//  converts the signal level activity to the transaction level. Monitor samples DUT signals but 
//  does not drive them.
//------------------------------------------------------------------------------------------------//
class master_monitor extends uvm_monitor;

//  Factory Method in UVM enables us to register a class, object and variables inside the factory 
  	`uvm_component_utils(master_monitor)

//  Virtual interface holds the pointer to the Interface.  
	virtual uart_if vif;

//  w_cfg is the handle of master_agent_config which is extended from the configuration class    
  	master_agent_config w_cfg;
  	master_driver m_drv;

//  TLM Port:uvm_analysis port consisting of inbuilt write method
	uvm_analysis_port #(master_xtn) monitor_port;
 // Handle to  a cfg class
  uart_config cfg; 

  int num_frames;
  bit sample_clk;
  bit baud_clk;
  bit [15:0] ua_brgr;
  bit [7:0] ua_bdiv;
  int num_of_bits_rcvd;
  int delay;
  bit sop_detected;
  bit tmp_bit0;
  bit serial_d1;
  bit serial_bit;
  bit serial_b;
  bit [1:0]  msb_lsb_data;

  bit checks_enable = 1;   // enable protocol checking
  bit coverage_enable = 1; // control coverage in the monitor
  master_xtn cur_frame;

`uvm_field_utils_begin(master_monitor)
      `uvm_field_object(cfg, UVM_DEFAULT | UVM_REFERENCE)
      `uvm_field_int(checks_enable, UVM_DEFAULT)
      `uvm_field_int(coverage_enable, UVM_DEFAULT)
      `uvm_field_object(cur_frame, UVM_DEFAULT | UVM_NOPRINT)
  `uvm_field_utils_end

  covergroup uart_trans_frame_cg;
    NUM_STOP_BITS : coverpoint cfg.nbstop {
      bins ONE = {0};
      bins TWO = {1};
    }
    DATA_LENGTH : coverpoint cfg.char_length {
      bins EIGHT = {0,1};
      bins SEVEN = {2};
      bins SIX = {3};
    }
    PARITY_MODE : coverpoint cfg.parity_mode {
      bins EVEN  = {0};
      bins ODD   = {1};
      bins SPACE = {2};
      bins MARK  = {3};
    }
    PARITY_ERROR: coverpoint cur_frame.error_bits[1]
      {
        bins good = { 0 };
        bins bad = { 1 };
      }

    DATA_LENGTH_x_PARITY_MODE: cross DATA_LENGTH, PARITY_MODE;
    PARITY_ERROR_x_PARITY_MODE: cross PARITY_ERROR, PARITY_MODE;

  endgroup
//------------------------------------------------------------------------------------------------//
//  The extern qualifier indicates that the body of the method (its implementation) is to be found 
//  outside the declaration.
//------------------------------------------------------------------------------------------------//
	extern function new(string name = "master_monitor", uvm_component parent);
	extern function void build_phase(uvm_phase phase);
	extern function void connect_phase (uvm_phase phase);
	extern task run_phase(uvm_phase phase);
	extern virtual task gen_sample_rate(ref bit [15:0] ua_brgr, ref bit sample_clk, ref bit sop_detected);
  	extern virtual task start_synchronizer(ref bit serial_d1, ref bit serial_b);
  	extern virtual function void perform_coverage();
  	extern virtual task collect_frame();
  	extern virtual task wait_for_sop(ref bit sop_detected);
  	extern virtual task sample_and_store();
endclass:master_monitor


//------------------------------------------------------------------------------------------------//
//  constructor:new
//  The new function is called as class constructor. On calling the new method it allocates the 
//  memory and returns the address to the class handle. For the component class two arguments to be 
//  passed. 
//------------------------------------------------------------------------------------------------//
function master_monitor :: new(string name ="master_monitor",uvm_component parent);
  	super.new(name, parent);
	uart_trans_frame_cg = new();
        uart_trans_frame_cg.set_inst_name ("uart_trans_frame_cg");
	monitor_port = new("monitor_port", this);
endfunction:new


//-----------------------------------------------------------------------------------------------//
//  phase:Build
//  The build phases are executed at the start of the UVM Testbench simulation and their overall 
//  purpose is to construct, configure and connect the Testbench component hierarchy.
//  All the build phase methods are functions and therefore execute in zero simulation time.	
//------------------------------------------------------------------------------------------------//
function void master_monitor::build_phase(uvm_phase phase);
	super.build_phase(phase);
	if(!uvm_config_db #(master_agent_config)::get(this,"","master_agent_config",w_cfg))
	`uvm_fatal("CONFIG","Cannot get() w_cfg from uvm_config_db. Have you set() it?")
	 if(cfg == null)
	      if (!uvm_config_db#(uart_config)::get(this, "", "cfg", cfg))
       `uvm_info(get_type_name(), "uart_config not set for this component",UVM_LOW)

endfunction:build_phase


//------------------------------------------------------------------------------------------------//
//  phase:connect
//  The connect phase is used to make TLM connections between components or to assign handles to 
//  testbench resources. It has to occur after the build method so that Testbench component 
//  hierarchy could be in place and it works from the bottom-up of the hierarchy upwards.
//------------------------------------------------------------------------------------------------//
function void master_monitor::connect_phase(uvm_phase phase);
	 vif = w_cfg.vif;
endfunction:connect_phase

task master_monitor::run_phase(uvm_phase phase);
 `uvm_info(get_type_name(),"Start Running", UVM_LOW)
  @(negedge vif.reset); 
  wait (vif.reset);
  `uvm_info(get_type_name(), "Detected Reset Done", UVM_LOW)
  num_frames = 0;
  cur_frame = master_xtn::type_id::create("cur_frame", this);

  fork
    gen_sample_rate(ua_brgr, sample_clk, sop_detected);
    start_synchronizer(serial_d1, serial_b);
    sample_and_store();
  join
endtask : run_phase

task master_monitor::gen_sample_rate(ref bit [15:0] ua_brgr, ref bit sample_clk, ref bit sop_detected);
    forever begin
      @(posedge vif.clock);
      if ((!vif.reset) || (sop_detected)) begin
        `uvm_info(get_type_name(), "sample_clk- resetting ua_brgr", UVM_HIGH)
        ua_brgr = 0;
        sample_clk = 0;
        sop_detected = 0;
      end else begin
        if ( ua_brgr == ({cfg.baud_rate_div, cfg.baud_rate_gen})) begin
          ua_brgr = 0;
          sample_clk = 1;
        end else begin
          sample_clk = 0;
          ua_brgr++;
        end
      end
    end
endtask

task master_monitor::start_synchronizer(ref bit serial_d1, ref bit serial_b);

forever begin
    @(posedge vif.clock);
    if (!vif.reset) begin
      serial_d1 = 1;
      serial_b = 1;
    end else begin
      serial_d1 = serial_b;
      serial_b = vif.txd;
    end
  end
endtask

task master_monitor::sample_and_store();
  forever begin
    wait_for_sop(sop_detected);
    collect_frame();
  end
endtask : sample_and_store

task master_monitor::wait_for_sop(ref bit sop_detected);
    delay = 0;
    sop_detected = 0;
    while (!sop_detected) begin
      `uvm_info(get_type_name(), "trying to detect SOP", UVM_MEDIUM)
      while (!(serial_d1 == 1 && serial_b == 0)) begin
        @(negedge vif.clock);
        delay++;
      end
      if (serial_b != 0)
        `uvm_info(get_type_name(), "Encountered a glitch in serial during SOP, shall continue", UVM_LOW)
      else
      begin
        sop_detected = 1;
        `uvm_info(get_type_name(), "SOP detected", UVM_MEDIUM)
      end
    end
endtask : wait_for_sop
  

task master_monitor::collect_frame();
  bit [7:0] payload_byte;
  cur_frame = new;
 `uvm_info(get_type_name(), $sformatf("Collecting a frame: %0d", num_frames+1), UVM_HIGH)
   // Begin Transaction Recording
  void'(this.begin_tr(cur_frame, "UART Monitor", , get_full_name()));
  cur_frame.delay = delay;
  cur_frame.start_bit = 1'b0;
  cur_frame.parity_type = GOOD_PARITY;
  num_of_bits_rcvd = 0;

    while (num_of_bits_rcvd < (1 + cfg.char_len_val + cfg.parity_en + cfg.nbstop))
    begin
      @(posedge vif.clock);
      #1;
      if (sample_clk) begin
        num_of_bits_rcvd++;
        if ((num_of_bits_rcvd > 0) && (num_of_bits_rcvd <= cfg.char_len_val)) begin // sending "data bits" 
          cur_frame.payload[num_of_bits_rcvd-1] = serial_b;
          payload_byte = cur_frame.payload[num_of_bits_rcvd-1];
          `uvm_info(get_type_name(), $sformatf("Received a Frame data bit:'b%0b", payload_byte), UVM_HIGH)
        end
        msb_lsb_data[0] =  cur_frame.payload[0] ;
        msb_lsb_data[1] =  cur_frame.payload[cfg.char_len_val-1] ;
        if ((num_of_bits_rcvd == (1 + cfg.char_len_val)) && (cfg.parity_en)) begin // sending "parity bit" if parity is enabled
          cur_frame.parity = serial_b;
          `uvm_info(get_type_name(), $sformatf("Received Parity bit:'b%0b", cur_frame.parity), UVM_HIGH)
          if (serial_b == cur_frame.calc_parity(cfg.char_len_val, cfg.parity_mode))
            `uvm_info(get_type_name(), "Received Parity is same as calculated Parity", UVM_MEDIUM)
          else if (checks_enable)
            `uvm_error(get_type_name(), "####### FAIL :Received Parity doesn't match the calculated Parity  ")
        end
        if (num_of_bits_rcvd == (1 + cfg.char_len_val + cfg.parity_en)) begin // sending "stop/error bits"
          for (int i = 0; i < cfg.nbstop; i++) begin
            wait (sample_clk);
            cur_frame.stop_bits[i] = serial_b;
            `uvm_info(get_type_name(), $sformatf("Received a Stop bit: 'b%0b", cur_frame.stop_bits[i]), UVM_HIGH)
            num_of_bits_rcvd++;
            wait (!sample_clk);
          end
        end
        wait (!sample_clk);
      end
    end
 num_frames++; 
 `uvm_info(get_type_name(), $sformatf("Collected the following Frame No:%0d\n%s", num_frames, cur_frame.sprint()), UVM_MEDIUM)

  if(coverage_enable) perform_coverage();
  monitor_port.write(cur_frame);
  this.end_tr(cur_frame);
endtask : collect_frame

function void master_monitor::perform_coverage();
  uart_trans_frame_cg.sample();
endfunction : perform_coverage


