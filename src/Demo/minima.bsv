package Tb;
	import Vector::*;
	import FIFO::*;
	import StmtFSM::*;

	interface Tbifc #(numeric type num);
	endinterface
	module mkTb (Tbifc #(num));

		// Integer size = 16; // Int datatype size in bits
		// Integer num = 10; //number of elements to store in vector


		function Int#(8) initVals8(Integer i); // function to initialise the vector
			Int #(8) temp_int = fromInteger(i)*8 + 1;
			// $display(temp_int);
			return temp_int;
		endfunction 
		function Int#(16) initVals16(Integer i); // function to initialise the vector
			return fromInteger(i * 13 +1);
		endfunction 

		function Int#(32) initVals32(Integer i); // function to initialise the vector
			return fromInteger(i * 13 +1);
		endfunction 

		/*Vector#(num, Int#(size)) temp = map(initVals, genVector); // initialising the vector

		Int#(size) mini = temp[0];
		for (Integer i=1; i < num; i=i+1)
			mini = min(temp[i], mini);
		 */
		
	
		function Int #(8) int_8();
			Vector#(num, Int#(8)) temp = map(initVals8, genVector); // initialising the vector
			
			//Int#(8) mini_8 = temp[0];
			Integer p = 1;
			Integer t = (valueOf(num) / 2) - 1;
			while(t>0)
				begin
					Integer ind = 2**p; 
					for(Integer i=0; i < valueOf(num); i=i+1)
						begin
							temp[i] = min(temp[i], temp[i+ind]);
							i=i+ind;
						end 
					t = log2(t); 
					p=p+1;
				end
			return temp[0];
		endfunction

		function ActionValue #(Int #(16)) int_16();
			actionvalue
			Vector#(num, Int#(16)) temp = map(initVals16, genVector); // initialising the vector

			Int#(16) mini_16 = temp[0];
			for (Integer i=1; i < valueOf(num); i=i+1)
				mini_16 = min(temp[i], mini_16);

			for( Integer i=0;i<valueOf(num);i=i+1)
				$display(i,temp[i]);
			$display(mini_16);

			return mini_16;
			endactionvalue
		endfunction

		function int_32();
			Vector#(num, Int#(32)) temp = map(initVals32, genVector); // initialising the vector

			Int#(32) mini_32 = temp[0];
			for (Integer i=1; i < valueOf(num); i=i+1)
				mini_32 = min(temp[i], mini_32);
			return mini_32;
		endfunction

	/*	rule displayVec;
			for (Integer i= 0; i < num; i=i+1)
				$display("temp[%d] = %d", i, temp[i]);
			$display("mini= %d",mini);
		endrule  */


		rule finish;
			
			
		endrule 
		
		Reg #(Int #(8)) test1 <- mkRegU;
		Stmt tests = seq
			test1 <= int_8();
			$display(test1);
			endseq;
		mkAutoFSM(tests);
	endmodule

	module test (Empty);
		Tbifc #(20) tb_name <- mkTb;
	endmodule
endpackage
