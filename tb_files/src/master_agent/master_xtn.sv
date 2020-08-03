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
//   Use of Include Guards
//`ifndef _master_xtn_INCLUDED_
//`define _master_xtn_INCLUDED_

// Parity Type Control knob
typedef enum bit {GOOD_PARITY, BAD_PARITY} parity_e;

class master_xtn extends uvm_sequence_item;

//Factory Method in UVM enables us to register a class, object and variables inside the factory
 // uvc 	`uvm_object_utils(master_xtn)

  // uvc  	rand bit tx_valid_i; //tx_valid_i;
  // uvc	rand bit [7:0] da; //visali

	// UART Frame
  rand bit start_bit;
  rand bit [7:0] payload;
  bit parity;
  rand bit [1:0] stop_bits;
  rand bit [3:0] error_bits;
 
  // Control Knobs
  rand parity_e parity_type;
  rand int delay;

  // Default constraints  //lab1_note2
  constraint default_delay {delay >= 0; delay < 20;}
  constraint default_start_bit { start_bit == 1'b0;}
  constraint default_stop_bits { stop_bits == 2'b11;}
  constraint default_parity_type { parity_type==GOOD_PARITY;}
  constraint default_error_bits { error_bits == 4'b0000;}
	
  // These declarations implement the create() and get_type_name() 
  // and enable automation of the uart_frame's fields     
  `uvm_object_utils_begin(master_xtn)   
    `uvm_field_int(start_bit, UVM_DEFAULT)
    `uvm_field_int(payload, UVM_DEFAULT)  
    `uvm_field_int(parity, UVM_DEFAULT)  
    `uvm_field_int(stop_bits, UVM_DEFAULT)
    `uvm_field_int(error_bits, UVM_DEFAULT)
    `uvm_field_enum(parity_e,parity_type, UVM_DEFAULT + UVM_NOCOMPARE) 
    `uvm_field_int(delay, UVM_DEFAULT + UVM_DEC + UVM_NOCOMPARE + UVM_NOCOPY)
  `uvm_object_utils_end

//---------------------------------------------------------------------------------------------
//Defining external tasks and functions
   	extern function new(string name = "master_xtn");
   	extern function void do_print(uvm_printer printer);
	extern function bit calc_parity(int unsigned num_of_data_bits=8,bit[1:0] ParityMode=0);
	extern function void post_randomize();
endclass:master_xtn


//------------------------------------------------------------------------------------------------
//new:constructor
//The new function is called as class constructor. On calling the new method it allocates the 
//memory and returns the address to the class handle. For the component class two arguments to be 
//passed.
//-----------------------------------------------------------------------------------------------
function master_xtn::new(string name="master_xtn");
	super.new(name);
endfunction:new

// This method calculates the parity
  function bit master_xtn :: calc_parity(int unsigned num_of_data_bits=8,
                           bit[1:0] ParityMode=0);
    bit temp_parity;

    if (num_of_data_bits == 6)
      temp_parity = ^payload[5:0];  
    else if (num_of_data_bits == 7)
      temp_parity = ^payload[6:0];  
    else
      temp_parity = ^payload;  

    case(ParityMode[0])
      0: temp_parity = ~temp_parity;
      1: temp_parity = temp_parity;
    endcase
    case(ParityMode[1])
      0: temp_parity = temp_parity;
      1: temp_parity = ~ParityMode[0];
    endcase
    if (parity_type == BAD_PARITY)
      calc_parity = ~temp_parity;
    else 
      calc_parity = temp_parity;
  endfunction : calc_parity 

  // Parity is calculated in the post_randomize() method   //lab1_note5
  function void master_xtn ::post_randomize();
   parity = calc_parity();
  endfunction : post_randomize
//Do_Print method
function void  master_xtn::do_print (uvm_printer printer);
  	super.do_print(printer);
	//printer.print_field("tx_valid_i",this.tx_valid_i, 8,UVM_BIN);
	//printer.print_field("da",this.da, 8, UVM_BIN);
// string name bitstream value size radix for printing 
endfunction:do_print



    

  

