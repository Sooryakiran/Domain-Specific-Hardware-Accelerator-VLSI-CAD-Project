package CPU;

    import StmtFSM::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import Connectable::*;

    import InstructionMemory::*;

    `include <config.bsv>

    typedef enum {NOP,

                  ASG_8,    
                  ASG_16,
                  ASG_32,   // 64 Bits long 
                  MOV,

                  ADD_I8,
                  ADD_I16,
                  ADD_I32,
                  ADD_F32,

                  SUB_I8,
                  SUB_I16,
                  SUB_I32,
                  SUB_F32,

                  IS_EQ,
                  
                  JMP, 
                  LOAD_8,
                  LOAD_16,
                  LOAD_32,

                  STORE_8,
                  STORE_16,
                  STORE_32,

                  VEC_NEG_I8,
                  VEC_NEG_I16,
                  VEC_NEG_I32,
                  VEC_NEG_F32,

                  VEC_MIN_I8,
                  VEC_MIN_I16,
                  VEC_MIN_I32,
                  VEC_MIN_F32
                  }
                  Opcode deriving (Bits, Eq, FShow);

    typedef enum {R0, R1, R2, R3, R4, R5, R6, R7, NO} Regname deriving (Bits, Eq, FShow);

    typedef struct {
        Opcode code;    //5 bits
        Regname src1;   //4 bits
        Regname src2;   //4 bits
        Regname aux;    //4 bits
        Regname dst;    //4 bits
        Bit #(TSub #(`WORD_LENGTH, 21)) pad; // Upto 32 bits
    } Instruction deriving(Bits);

    typedef struct {
        Opcode code;
        Bit #(`DATA_LENGTH) src1;
        Bit #(`DATA_LENGTH) src2;
        Bit #(`DATA_LENGTH) aux;
        Regname dst;
    }  DecodedInstruction deriving(Bits);




    interface Registors;
        method Bit #(`DATA_LENGTH) load(Regname name);
        method Action store (Bit #(`DATA_LENGTH) data, Regname name);
    endinterface

    interface Fetch;
        method Action store (Bit #(`DATA_LENGTH) data, Regname name);
        method Action flush;
        interface Client #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH)) imem_client; 
        interface Server #(Bit #(1), DecodedInstruction) exec_server; 
    endinterface

    module mkRegistors (Registors);
        Vector #(8, Reg #(Bit #(`DATA_LENGTH))) regs <- replicateM(mkRegU);

        method Bit #(`DATA_LENGTH) load(Regname name);
            let x = pack(name);
            return ((x<8)? regs[x] : 0);
        endmethod

        method Action store (Bit #(`DATA_LENGTH) data, Regname name);
            action
                let x = pack(name);
                if (x < 8)
                    regs[x] <= data;
            endaction
        endmethod
    endmodule : mkRegistors

    module mkFetch (Fetch);
        FIFOF #(Instruction) instructions <- mkBypassFIFOF;
        FIFOF #(DecodedInstruction) decoded <- mkPipelineFIFOF;

        Reg #(Bit #(`PC_SIZE)) pc <- mkReg(0);
        

        Reg #(Bit #(32)) debug_clk <- mkReg(0);

        Registors regs <- mkRegistors;

        Reg #(Bit #(1)) wait_for_next_half <- mkReg(0);
        Reg #(Regname) waiting_address <- mkRegU;

        Reg #(Regname) future <- mkReg(NO);
     
        PulseWire got_instruction <- mkPulseWire();
        PulseWire wait_instruction <- mkPulseWire();

        function Bit #(`DATA_LENGTH) check_load (Regname r) ;
            if (r == NO)
            begin
                return 0;
            end
            else
            begin
                return regs.load(r);
            end
        endfunction
        
        function Action put_instructions (Bit #(`WORD_LENGTH) new_stuff);
            action
                Instruction ins = unpack(new_stuff);
                
                Instruction nop = Instruction {
                                    code : NOP,
                                    src1 : NO,
                                    src2 : NO,
                                    aux  : NO,
                                    dst  : NO
                };

                if (future != NO && (future == ins.src1 || future == ins.src2) && wait_for_next_half == 0)
                begin
                    instructions.enq(nop);
                    future <= NO;
                end
                else
                begin
                    instructions.enq(ins);
                    future <= ins.dst;
                    got_instruction.send();

                end
            endaction
        endfunction

        `ifndef SMALL_WIDTH
        rule master_heavy (`WORD_LENGTH >= 64);
            let x = instructions.first();
            $display(debug_clk ,":", fshow(instructions.first().code));

            if (x.code == ASG_8 || x.code == ASG_16 || x.code == ASG_32)
            begin
                regs.store(extend(pack(x)[41:10]), x.src1);
                
            end
            else
            begin
                DecodedInstruction current = DecodedInstruction {
                                            code : x.code,
                                            src1 : check_load(x.src1),
                                            src2 : check_load(x.src2),  
                                            aux  : check_load(x.aux),
                                            dst  : x.dst   
                                            };   
                
                decoded.enq(current);
            end
                
            instructions.deq();
        endrule
        `endif

        rule slave_32_bit (`WORD_LENGTH < 64 && wait_for_next_half == 1);
            let x = instructions.first();
            $display(debug_clk ,":", "ASG_32_Continue");
            regs.store(extend(pack(x)), x.src1);
            wait_for_next_half <= 0;
            instructions.deq();
        endrule

        rule master_32_bit (`WORD_LENGTH < 64 && wait_for_next_half == 0);
            let x = instructions.first();
            $display(debug_clk ,":", fshow(instructions.first().code));
            if(x.code == ASG_32)
            begin
                wait_for_next_half <= 1;
                waiting_address <= x.src1;
            end
            else
            begin
                if (x.code == ASG_8 || x.code == ASG_16)
                begin
                    regs.store(extend(pack(x)[25:10]), x.src1);
                end
                else
                begin
                    DecodedInstruction current = DecodedInstruction {
                                                code : x.code,
                                                src1 : check_load(x.src1),
                                                src2 : check_load(x.src2),  
                                                aux  : check_load(x.aux),
                                                dst  : x.dst   
                                                };   
                    
                    decoded.enq(current);
                end
            end


            instructions.deq();


        endrule

        rule debug;
            decoded.deq();
            
        endrule

        rule debug_clk_upd;
            debug_clk <= debug_clk + 1;
            if (debug_clk > 40) $finish();
        endrule

    
        rule increment_pc (got_instruction);
            pc <= pc + 1;
        endrule

        method Action flush;
            action
                decoded.clear;
            endaction
        endmethod

        interface store = regs.store;

        interface Client imem_client;
            interface Get request = toGet(pc);
            interface Put response = toPut(put_instructions);
        endinterface
    endmodule : mkFetch

    module tests(Empty);


        // Registors r <- mkRegistors;
        Fetch f <- mkFetch;
        Imem i <-mkImem("../asm/random");
        mkConnection(i, f.imem_client);

    endmodule


endpackage : CPU