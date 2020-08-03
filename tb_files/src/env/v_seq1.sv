
//Virtual sequence for uart TX


class v_seq1 extends vbase_seq;

	`uvm_object_utils(v_seq1)
	master_seqs uart_seq;
	function new(string name= "v_seq1");
	super.new(name);
	endfunction

virtual task body();

	super.body();
	uart_seq=master_seqs::type_id::create("uart_seq");
	`uvm_info("v_seq1","Executing sequence",UVM_LOW)
	//`uvm_do_on(uart_seq,vseqrh)
	uart_seq.start(master_seqrh[0]);
	`uvm_info("v_seq1","sequence Complete",UVM_LOW)
endtask

endclass:v_seq1
