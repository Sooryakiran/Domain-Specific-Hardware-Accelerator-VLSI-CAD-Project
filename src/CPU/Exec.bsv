////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : The Execute unit of our CPU
////////////////////////////////////////////////////////////////////////////////

package Exec;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import Vector::*;
import ClientServer::*;
import FloatingPoint::*;
import Bus::*;
import CPUDefines::*;

`include <VX_Address.bsv>

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// An interface for our execute units
// Param datalength     : Size of the data registers
// Param busdatalength  : Width of the databus
// Param busaddrlength  : Width of the addressbus
// Param granularity    : Size of the smallest addressable unit
interface Exec #(numeric type datalength,
                    numeric type busdatalength,
                    numeric type busaddrlength,
                    numeric type granularity);

    interface Put #(Bit #(DecodedInstructionSize #(datalength))) put_decoded;  
    interface Get #(Bit #(SizeRegPackets #(datalength)))         send_computed_value;
    interface Get #(Bit #(datalength))                           get_branch;
    interface Put #(Chunk #(busdatalength, busaddrlength, granularity)) put_from_bus;
    interface Get #(Chunk #(busdatalength, busaddrlength, granularity)) get_to_bus;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates the execute unit
module mkExec (Exec #(datalength, busdatalength, busaddrlength, granularity))
    provisos (Add# (na, 32, datalength),     
                Add# (nb, 32, busdatalength),  
                Add# (nc, 16, datalength),
                Add# (nf, 16, busdatalength),
                Add# (nd, 8,  datalength),
                Add# (ne, 8,  busdatalength),
                Add# (nh, 1,  busdatalength),
                Add# (ng, busaddrlength, TAdd#(TMax#(datalength, busaddrlength), 1)));

    FIFOF #(Bit #(DecodedInstructionSize#(datalength))) incoming    <- mkBypassFIFOF;
    FIFOF #(RegPackets #(datalength))                   out_to_regs <- mkBypassFIFOF;
    RWire #(Bit #(datalength))                          branch      <- mkRWire();
    Reg   #(Bit #(datalength))                          wait_count  <- mkReg(0);
    Reg   #(Bit #(32))                                  debug_clk   <- mkReg(0);
    Reg   #(Bool)                                       wait_load   <- mkReg(False);
    Reg   #(Bool)                                       wait_store  <- mkReg(False);
    Reg   #(Bool)                                       wait_vec    <- mkReg(False);
    Reg   #(Regname)                                    wait_reg    <- mkReg(NO);
    FIFOF #(Chunk #(busdatalength, busaddrlength, granularity)) bus_out <- mkBypassFIFOF;
    FIFOF #(Chunk #(busdatalength, busaddrlength, granularity)) bus_in  <- mkBypassFIFOF;

    // If the CPU is waiting for a vec operation to complete, this rule listens for
    // responses if the exec unit has pinged the accelerator for status.
    (* mutually_exclusive = "load_vec_status, load_from_bus" *)
    rule load_vec_status (wait_vec == True);
        let x = bus_in.first(); bus_in.deq();
        Bit #(1) useful_data = truncate(x.data);
        if (useful_data == 1)
        begin
            incoming.deq();
        end
        wait_vec <= False;
    endrule

    // Awaits the response for any Load instruction
    rule load_from_bus (wait_load == True && wait_reg != NO);
        let x = bus_in.first(); bus_in.deq();
        let p = x.present;
        
        if (p == 1)
        begin
            // Load 8
            Bit #(8) r = truncate(x.data);
            Bit #(datalength) value = extend(r);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : value,
                                    register    : wait_reg};
            out_to_regs.enq(packet);
        end
        else if (p == 2)
        begin
            // Load 16
            Bit #(16) r = truncate(x.data);
            Bit #(datalength) value = extend(r);

            RegPackets #(datalength) packet = RegPackets {
                data        : value,
                register    : wait_reg};
            out_to_regs.enq(packet);
        end
        else if (p == 4)
        begin
            // Load 32
            Bit #(32) r = truncate(x.data);
            Bit #(datalength) value = extend(r);

            RegPackets #(datalength) packet = RegPackets {
                data        : value,
                register    : wait_reg};
            out_to_regs.enq(packet);
        end
        wait_load <= False;
        incoming.deq();
    endrule

    // A common function to write the computed value to the registers
    function ActionValue #(Bit #(SizeRegPackets #(datalength))) send_back_to_regs;
        actionvalue
            let x = pack(out_to_regs.first());
            out_to_regs.deq();
            return pack(x);
        endactionvalue
    endfunction

    // Implementation of the MOV instruction
    function Action mov(Bit #(datalength) value, Regname name);
        action
            RegPackets #(datalength) packet = RegPackets {
                                    data        : value,
                                    register    : name};
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer addition 8 bit
    function Action addi8 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(8) int_1          = unpack(truncate(x1));
            Int #(8) int_2          = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 + int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name};
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer addition 16 bit
    function Action addi16 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(16) int_1         = unpack(truncate(x1));
            Int #(16) int_2         = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 + int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer addition 32 bit
    function Action addi32 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(32) int_1         = unpack(truncate(x1));
            Int #(32) int_2         = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 + int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of float addition 32 bit
    function Action addf32 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Bit #(TAdd #(32, datalength)) temp_x1 = extend(x1);
            Bit #(TAdd #(32, datalength)) temp_x2 = extend(x2);

            Float f32_1 = unpack(truncate(temp_x1));
            Float f32_2 = unpack(truncate(temp_x2));
            Float out   = f32_1 + f32_2;

            Bit #(TAdd #(32, datalength)) temp_data = extend(pack(out));

            RegPackets #(datalength) packet = RegPackets {
                                    data        : truncate(temp_data),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer subctration 8 bit
    function Action subi8 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(8) int_1          = unpack(truncate(x1));
            Int #(8) int_2          = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 - int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer subctration 16 bit
    function Action subi16 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(16) int_1         = unpack(truncate(x1));
            Int #(16) int_2         = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 - int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of integer subctration 32 bit
    function Action subi32 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Int #(32) int_1         = unpack(truncate(x1));
            Int #(32) int_2         = unpack(truncate(x2));
            Int #(datalength) out = extend(int_1 - int_2);

            RegPackets #(datalength) packet = RegPackets {
                                    data        : pack(out),
                                    register    : name
                                };
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of float subctraction 32 bit
    function Action subf32 (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Float f32_1 = unpack(truncate(x1));
            Float f32_2 = unpack(truncate(x2));
            Float out = f32_1 - f32_2;

            Bit #(TAdd #(32, datalength)) temp_data = extend(pack(out));

            RegPackets #(datalength) packet = RegPackets {
                                    data : truncate(temp_data),
                                    register : name
                                };
            
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of logical is EQ comparator
    function Action iseq (Bit #(datalength) x1, Bit #(datalength) x2, Regname name);
        action
            Bit #(datalength) out = (x1 == x2)? 1: 0;
            RegPackets #(datalength) packet   = RegPackets {
                                    data        : out,
                                    register    : name
                                };
            
            out_to_regs.enq(packet);
            incoming.deq();
        endaction
    endfunction

    // Implementation of branch instruction
    function Action jmp (Bit #(datalength) dst);
        action
            branch.wset(dst);
            incoming.deq();
        endaction
    endfunction

    // Implementation of a conditional branch
    function Action jmpif (Bit #(datalength) dst, Bit #(datalength) cond);
        action
            if (cond == 1)
            begin
            branch.wset(dst);
            end
            incoming.deq();
        endaction
    endfunction

    // Implementation of the load instruction
    function Action load (Bit #(datalength) addr, 
                            Regname dst, 
                            Bit #(PresentSize #(busdatalength, granularity)) p);
        action
        Bit #(TAdd #(datalength, busaddrlength)) address = extend(addr);
        Chunk #(busdatalength, busaddrlength, granularity) x = Chunk {
                                                                    control : Read,
                                                                    data : ?,
                                                                    addr : truncate(address),
                                                                    present : p
                                                                };
        bus_out.enq(x);
        wait_load <= True;
        wait_reg <= dst;
        endaction
    endfunction

    // Implementation of the store instruction
    function Action store (Bit #(datalength) data, 
                            Bit #(datalength) addr, 
                            Regname dst, 
                            Bit #(PresentSize #(busdatalength, granularity)) p);
        action
        Bit #(TAdd #(datalength, busaddrlength)) address = extend(addr);
        Bit #(TAdd #(datalength, busdatalength)) data_b = extend(data);

        Chunk #(busdatalength, busaddrlength, granularity) x = Chunk {
                                                                    control : Write,
                                                                    data : truncate(data_b),
                                                                    addr : truncate(address),
                                                                    present : p
                                                                };
        bus_out.enq(x);
        incoming.deq();
        endaction
    endfunction

    // Implementation of the vector instruction to send to accelerator. The CPU pings the
    // accelerators at a certain frequency numerically equal to the vector length and listens 
    // for status of the operation.
    function Action vec (Bit #(datalength) src, 
                            Bit #(datalength) blocksize, 
                            Bit #(datalength) dst);
        action
            if (wait_count > blocksize)
            begin
                Chunk #(busdatalength, busaddrlength, granularity) x = Chunk {
                                                                            control : Read,
                                                                            data : ?,
                                                                            addr : `VX_ADDRESS + 5,
                                                                            present : 1
                                                                        };
                bus_out.enq(x);
                wait_count <= 0;
                wait_vec <= True;
            end
            else wait_count <= wait_count + 1;
            
        endaction
    endfunction
    
    // A master rule that sends the instruction to the right units
    rule exec_master (!wait_load && !wait_store && !wait_vec);
        DecodedInstruction #(datalength) x = unpack(incoming.first);
        if (x.code == NOP)      incoming.deq();
        if (x.code == MOV)      mov     (x.src1, x.dst);
        if (x.code == ADD_I8)   addi8   (x.src1, x.src2, x.dst);
        if (x.code == ADD_I16)  addi16  (x.src1, x.src2, x.dst);
        if (x.code == ADD_I32)  addi32  (x.src1, x.src2, x.dst);
        if (x.code == ADD_F32)  addf32  (x.src1, x.src2, x.dst);
        if (x.code == SUB_I8)   subi8   (x.src1, x.src2, x.dst);
        if (x.code == SUB_I16)  subi16  (x.src1, x.src2, x.dst);
        if (x.code == SUB_I32)  subi32  (x.src1, x.src2, x.dst);
        if (x.code == SUB_F32)  subf32  (x.src1, x.src2, x.dst);
        if (x.code == IS_EQ)    iseq    (x.src1, x.src2, x.dst);
        if (x.code == JMP)      jmp     (x.src1);
        if (x.code == JMPIF)    jmpif   (x.src1, x.src2);
        if (x.code == LOAD_8)   load    (x.src1, x.dst, 1);
        if (x.code == LOAD_16)  load    (x.src1, x.dst, 2);
        if (x.code == LOAD_32)  load    (x.src1, x.dst, 4);
        if (x.code == STORE_8)  store   (x.src1, x.src2, x.dst, 1);
        if (x.code == STORE_16) store   (x.src1, x.src2, x.dst, 2);
        if (x.code == STORE_32) store   (x.src1, x.src2, x.dst, 4);
        if (x.code == VEC_NEG_I8)   vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_NEG_I16)  vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_NEG_I32)  vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_NEG_F32)  vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_MIN_I8)   vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_MIN_I16)  vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_MIN_I32)  vec (x.src1, x.src2, x.aux);
        if (x.code == VEC_MIN_F32)  vec (x.src1, x.src2, x.aux);

    endrule

    interface Get get_branch            = toGet(branch);
    interface Put put_decoded           = toPut(incoming);
    interface Get send_computed_value   = toGet(send_back_to_regs()); 
    interface Put put_from_bus          = toPut(bus_in);
    interface Get get_to_bus            = toGet(bus_out);
endmodule

endpackage : Exec