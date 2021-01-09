////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : Exec unit for VX
////////////////////////////////////////////////////////////////////////////////

package VectorExec;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import GetPut::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;
import FloatingPoint::*;
import Bus::*;
import VectorDefines::*;
import VectorUnaryFetch::*;
import VectorMemoryController::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

export VectorExec (..);
export mkVectorExec;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// Interface for the vector exec unit
// Param datasize       : Datasize of the Registers
// Param vectordatasize : Number of bits that can be parallelly operated upon
// Param busdatasize    : Width of the databus
// Param busaddrsize    : Width of the address bus
// Param granularity    : The smallest addressable unit size
interface VectorExec #(numeric type datasize, 
                       numeric type vectordatasize, 
                       numeric type busdatasize, 
                       numeric type busaddrsize, 
                       numeric type granularity);
    interface Put #(BufferChunk #(datasize, vectordatasize, granularity)) put_decoded;
    interface Get #(WriteChunk #(busdatasize, busaddrsize, granularity)) get_to_mcu;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Instances
////////////////////////////////////////////////////////////////////////////////

// Defines the connection between a Vector Unary Fetch and Exec
instance Connectable #(VectorUnaryFetch #(datasize, 
                                          vectordatasize, 
                                          busdatasize, 
                                          busaddrsize, 
                                          granularity),
                       VectorExec #(datasize, 
                                    vectordatasize, 
                                    busdatasize, 
                                    busaddrsize, 
                                    granularity));
    module mkConnection #(VectorUnaryFetch #(datasize, 
                                             vectordatasize, 
                                             busdatasize, 
                                             busaddrsize, 
                                             granularity) fetch,
                          VectorExec #(datasize, 
                                       vectordatasize, 
                                       busdatasize, 
                                       busaddrsize, granularity) exec) (Empty);
        mkConnection (fetch.outgoing_pro_data, exec.put_decoded);
    endmodule
endinstance

// Define the connection between vector Exec and Memory Controller
instance Connectable #(VectorExec #(datasize, 
                                    vectordatasize, 
                                    busdatasize, 
                                    busaddrsize, 
                                    granularity),
                       VectorMemoryController #(busdatasize, 
                                                busaddrsize, 
                                                granularity));
    module mkConnection #(VectorExec #(datasize, 
                                       vectordatasize, 
                                       busdatasize, 
                                       busaddrsize, 
                                       granularity) exec,
                          VectorMemoryController #(busdatasize, 
                                                   busaddrsize, 
                                                   granularity) mcu) (Empty);
        mkConnection (exec.get_to_mcu, mcu.write_req);
    endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Create the vector execute unit
module mkVectorExec (VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity))
    provisos (Add #(na, 8, vectordatasize),
              Add #(nb, PresentSize #(vectordatasize, granularity), PresentSize #(busdatasize, granularity)),
              Add #(nc, vectordatasize, busdatasize),
              Add #(nd, 16, vectordatasize),
              Add #(ne, 32, vectordatasize),
              Add #(nf, 8,  busdatasize),
              Add #(ng, 16, busdatasize),
              Add #(nh, 32, busdatasize));
    FIFOF #(BufferChunk #(datasize, vectordatasize, granularity)) decoded <- mkPipelineFIFOF;
    FIFOF #(WriteChunk #(busdatasize, busaddrsize, granularity)) to_mcu <-mkBypassFIFOF;

    Integer num_vectorsize  = valueOf (vectordatasize);
    Integer num_granularity = valueOf (granularity);

    Reg #(Bit #(datasize))  current_block        <- mkReg(0);
    Reg #(Int #(8))         mini8_state          <- mkRegU;
    Reg #(Int #(32))        mini8_p_index        <- mkRegU;
    Reg #(Bool)             mini8_state_present  <- mkReg(False);
    Reg #(Bit #(datasize))  mini8_pindex_addr    <- mkRegU;
    Reg #(Bool)             mini8_done           <- mkReg(False);
    Reg #(Int #(16))        mini16_state         <- mkRegU;
    Reg #(Int #(32))        mini16_p_index       <- mkRegU;
    Reg #(Bool)             mini16_state_present <- mkReg(False);
    Reg #(Bit #(datasize))  mini16_pindex_addr   <- mkRegU;
    Reg #(Bool)             mini16_done          <- mkReg(False);
    Reg #(Int #(32))        mini32_state         <- mkRegU;
    Reg #(Int #(32))        mini32_p_index       <- mkRegU;
    Reg #(Bool)             mini32_state_present <- mkReg(False);
    Reg #(Bit #(datasize))  mini32_pindex_addr   <- mkRegU;
    Reg #(Bool)             mini32_done          <- mkReg(False);
    Reg #(Float)            minf32_state         <- mkRegU;
    Reg #(Int #(32))        minf32_p_index       <- mkRegU;
    Reg #(Bool)             minf32_state_present <- mkReg(False);
    Reg #(Bit #(datasize))  minf32_pindex_addr   <- mkRegU;
    Reg #(Bool)             minf32_done          <- mkReg(False);

    // Implementatino of vector negation int 8
    function Action negi8 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
            Bit #(vectordatasize) values = x.vector_data;
            Bit #(vectordatasize) outs[num_vectorsize/8];
            Int #(8) slice_curr          = -unpack(values[7 : 0]);
            outs[0] = extend(pack(slice_curr));

            // This wil get unrolled yaay!
            for (Integer i=8; i < num_vectorsize; i = i + 8)
            begin
                Int #(8) slice = -unpack(values[i+7 : i]);
                outs[i/8]      = outs[i/8 - 1] + (extend(pack(slice)) << i);
            end

            Bit #(busdatasize) outputs = extend(outs[num_vectorsize/8 -1]);
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst + current_block * fromInteger(num_vectorsize/num_granularity));
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : x.signal,
                                                                        data : outputs,
                                                                        addr : truncate(temp_address),
                                                                        present : extend(x.present)
                                                                    };
            if (x.signal == Continue) current_block <= current_block + 1;
            else 
            begin
                current_block <= 0;
            end
            to_mcu.enq(write_back);
        endaction
    endfunction

    // Implementation of vection negation int 16
    function Action negi16 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
            Bit #(vectordatasize) values = x.vector_data;
            Bit #(vectordatasize) outs[num_vectorsize/16];
            Int #(16) slice_curr = -unpack(values[15 : 0]);
            outs[0] = extend(pack(slice_curr));

            // This wil get unrolled yaay!
            for (Integer i=16; i < num_vectorsize; i = i + 16)
            begin
                Int #(16) slice = -unpack(values[i+15 : i]);
                outs[i/16] = outs[i/16 - 1] + (extend(pack(slice)) << i);
            end

            Bit #(busdatasize) outputs = extend(outs[num_vectorsize/16 -1]);
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst + current_block * fromInteger(num_vectorsize/num_granularity));
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : x.signal,
                                                                        data : outputs,
                                                                        addr : truncate(temp_address),
                                                                        present : extend(x.present)
                                                                    };
            if (x.signal == Continue) current_block <= current_block + 1;
            else 
            begin
                current_block <= 0;
            end
            to_mcu.enq(write_back);
        endaction
    endfunction

    // Implementation of vector negation int 32
    function Action negi32 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
            Bit #(vectordatasize) values = x.vector_data;
            Bit #(vectordatasize) outs[num_vectorsize/32];
            Int #(32) slice_curr = -unpack(values[31 : 0]);
            outs[0] = extend(pack(slice_curr));

            for (Integer i=32; i < num_vectorsize; i = i + 32)
            begin
                Int #(32) slice = -unpack(values[i+31 : i]);
                outs[i/32] = outs[i/32 - 1] + (extend(pack(slice)) << i);
            end

            Bit #(busdatasize) outputs = extend(outs[num_vectorsize/32 -1]);
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst + current_block * fromInteger(num_vectorsize/num_granularity));
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : x.signal,
                                                                        data : outputs,
                                                                        addr : truncate(temp_address),
                                                                        present : extend(x.present)
                                                                    };
            if (x.signal == Continue) current_block <= current_block + 1;
            else 
            begin
                current_block <= 0;
            end
            to_mcu.enq(write_back);
        endaction
    endfunction

    // Implementation of vector negation float32
    function Action negf32 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action

            Bit #(vectordatasize) values = x.vector_data;
            Bit #(vectordatasize) outs[num_vectorsize/32];

            Float slice_curr = -unpack(values[31 : 0]);
            outs[0] = extend(pack(slice_curr));

            for (Integer i=32; i < num_vectorsize; i = i + 32)
            begin
                Float slice = -unpack(values[i+31 : i]);
                outs[i/32] = outs[i/32 - 1] + (extend(pack(slice)) << i);
            end

            Bit #(busdatasize) outputs = extend(outs[num_vectorsize/32 -1]);
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst + current_block * fromInteger(num_vectorsize/num_granularity));
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : x.signal,
                                                                        data : outputs,
                                                                        addr : truncate(temp_address),
                                                                        present : extend(x.present)
                                                                    };
            if (x.signal == Continue) current_block <= current_block + 1;
            else 
            begin
                current_block <= 0;
            end
            to_mcu.enq(write_back);
        endaction
    endfunction

    // Implementation of statistics minima int 8
    function Action mini8 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
        Bit #(vectordatasize) values = x.vector_data;
        Int #(8)    temp[num_vectorsize/8];
        Int #(32)   p_index[num_vectorsize/8];
        Int #(8)    big_num = 127;
        
        for (Integer i =0; i < num_vectorsize/8; i = i +1 )
        begin
            if (fromInteger(i*8/num_granularity) < x.present) temp[i] = unpack(values[(i+1)*8-1:i*8]);
            else temp[i] = big_num;
            Int #(TAdd #(datasize, 32)) temp_val = fromInteger(i) + extend(unpack(current_block))*fromInteger(num_vectorsize/16);
            p_index[i] = truncate(temp_val);
        end

        Integer p = 0;
        Integer t = num_vectorsize/8; 

        while(t>0)
        begin
            Integer ind = 2**p; 
            for(Integer i=0; i < num_vectorsize/8-ind; i=i+2*ind)
                begin
                    p_index[i] = (temp[i] <= temp[i+ind])? p_index[i] : p_index[i+ind];
                    temp[i]    = min(temp[i], temp[i+ind]);
                end 
            t = t/2; 
            p = p+1;
        end

        if (mini8_state_present)
        begin
            p_index[0] = (temp[0] < mini8_state)? p_index[0] : mini8_p_index;
            temp[0] = min(temp[0], mini8_state);
        end
        mini8_state     <= temp[0];
        mini8_p_index   <= p_index[0];

        if (x.signal == Continue) 
        begin
            current_block       <= current_block + 1;
            mini8_state_present <= True;
        end
        else 
        begin
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst);
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Continue,
                                                                        data : extend(pack(temp[0])),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(8/num_granularity)
                                                                    };
            to_mcu.enq(write_back);
            mini8_pindex_addr   <= x.aux;
            mini8_done          <= True;
            mini8_state_present <= False;
            current_block       <= 0;
        end
        
        endaction
    endfunction

    // Final cleanups for statistics minima int 8
    rule mini8_done_vec (mini8_done);
        mini8_done <= False;
        Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(mini8_pindex_addr);
        WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Break,
                                                                        data : extend(pack(mini8_p_index)),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
        to_mcu.enq(write_back);
    endrule

    // Implementation of statistics minima int 16
    function Action mini16 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
        Bit #(vectordatasize) values = x.vector_data;
        Int #(16)    temp[num_vectorsize/16];
        Int #(32)    p_index[num_vectorsize/16];
        Int #(16)    big_num = 32767;
        
        for (Integer i =0; i < num_vectorsize/16; i = i +1 )
        begin
            if (fromInteger(i*16/num_granularity) < x.present) temp[i] = unpack(values[(i+1)*16-1:i*16]);
            else temp[i] = big_num;
            Int #(TAdd #(datasize, 32)) temp_val = fromInteger(i) + extend(unpack(current_block))*fromInteger(num_vectorsize/16);
            p_index[i] = truncate(temp_val);
        end

        Integer p = 0;
        Integer t = num_vectorsize/16; 

        while(t>0)
        begin
            Integer ind = 2**p; 
            for(Integer i=0; i < num_vectorsize/16-ind; i=i+2*ind)
                begin
                    p_index[i] = (temp[i] <= temp[i+ind])? p_index[i] : p_index[i+ind];
                    temp[i]    = min(temp[i], temp[i+ind]);
                end 
            t = t/2; 
            p = p+1;
        end

        if (mini16_state_present)
        begin
            p_index[0] = (temp[0] < mini16_state)? p_index[0] : mini16_p_index;
            temp[0] = min(temp[0], mini16_state);
        end
        mini16_state     <= temp[0];
        mini16_p_index   <= p_index[0];

        if (x.signal == Continue) 
        begin
            current_block       <= current_block + 1;
            mini16_state_present <= True;
        end
        else 
        begin
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst);
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Continue,
                                                                        data : extend(pack(temp[0])),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(16/num_granularity)
                                                                    };
            to_mcu.enq(write_back);
            mini16_pindex_addr   <= x.aux;
            mini16_done          <= True;
            mini16_state_present <= False;
            current_block        <= 0;
        end
        
        endaction
    endfunction

    // Final clean ups for statistics minima int 16
    rule mini16_done_vec (mini16_done);
        mini16_done <= False;
        Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(mini16_pindex_addr);
        WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Break,
                                                                        data : extend(pack(mini16_p_index)),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
        to_mcu.enq(write_back);
    endrule

    // Implementation of statistics minima int 32
    function Action mini32 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
        Bit #(vectordatasize) values = x.vector_data;
        Int #(32)    temp[num_vectorsize/32];
        Int #(32)    p_index[num_vectorsize/32];
        Int #(32)    big_num = 2147483647;
        
        for (Integer i =0; i < num_vectorsize/32; i = i +1 )
        begin
            if (fromInteger(i*32/num_granularity) < x.present) temp[i] = unpack(values[(i+1)*32-1:i*32]);
            else temp[i] = big_num;
            Int #(TAdd #(datasize, 32)) temp_val = fromInteger(i) + extend(unpack(current_block))*fromInteger(num_vectorsize/32);
            p_index[i] = truncate(temp_val);
        end

        Integer p = 0;
        Integer t = num_vectorsize/32; 

        while(t>0)
        begin
            Integer ind = 2**p; 
            for(Integer i=0; i < num_vectorsize/32-ind; i=i+2*ind)
                begin
                    p_index[i] = (temp[i] <= temp[i+ind])? p_index[i] : p_index[i+ind];
                    temp[i]    = min(temp[i], temp[i+ind]);
                end 
            t = t/2; 
            p = p+1;
        end

        if (mini32_state_present)
        begin
            p_index[0] = (temp[0] < mini32_state)? p_index[0] : mini32_p_index;
            temp[0] = min(temp[0], mini32_state);
        end
        mini32_state     <= temp[0];
        mini32_p_index   <= p_index[0];

        if (x.signal == Continue) 
        begin
            current_block       <= current_block + 1;
            mini32_state_present <= True;
        end
        else 
        begin
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst);
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Continue,
                                                                        data : extend(pack(temp[0])),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
            to_mcu.enq(write_back);
            mini32_pindex_addr   <= x.aux;
            mini32_done          <= True;
            mini32_state_present <= False;
            current_block        <= 0;
        end
        
        endaction
    endfunction

    // Final clean ups for statitics minima int 32
    rule mini32_done_vec (mini32_done);
        mini32_done <= False;
        Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(mini32_pindex_addr);
        WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Break,
                                                                        data : extend(pack(mini32_p_index)),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
        to_mcu.enq(write_back);
    endrule

    // Implementatino of statistics minima float32
    function Action minf32 (BufferChunk #(datasize, vectordatasize, granularity) x);
        action
        Bit #(vectordatasize) values = x.vector_data;
        Float    temp[num_vectorsize/32];
        Int #(32)    p_index[num_vectorsize/32];
        Float    big_num = infinity(False);
        
        for (Integer i =0; i < num_vectorsize/32; i = i + 1 )
        begin
            Int #(TAdd #(datasize, 32)) temp_val = fromInteger(i) + extend(unpack(current_block))*fromInteger(num_vectorsize/32);
            p_index[i] = truncate(temp_val);

            if (fromInteger(i*32/num_granularity) < x.present) temp[i] = unpack(values[(i+1)*32-1:i*32]);
            else  temp[i] = big_num;
            
        end
        Integer p = 0;
        Integer t = num_vectorsize/32; 
        while(t>0)
        begin
            Integer ind = 2**p; 
            for(Integer i=0; i < num_vectorsize/32-ind; i=i+2*ind)
                begin
                    let c = compareFP(temp[i], temp[i+ind]);
                    if (c == GT)
                    begin
                        temp[i] = temp[i+ind];
                        p_index[i] = p_index[i+ind];
                    end
                end 
            t = t/2; 
            p = p+1;
        end

        if (minf32_state_present)
        begin
            let c = compareFP (temp[0], minf32_state);
            if (c == GT || c == EQ)
            begin
                p_index[0] = minf32_p_index;
                temp[0] = minf32_state;
            end
        end

        minf32_state     <= temp[0];
        minf32_p_index   <= p_index[0];
        if (x.signal == Continue) 
        begin
            current_block       <= current_block + 1;
            minf32_state_present <= True;
        end
        else 
        begin
            Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(x.dst);
            WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Continue,
                                                                        data : extend(pack(temp[0])),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
            to_mcu.enq(write_back);
            minf32_pindex_addr   <= x.aux;
            minf32_done          <= True;
            minf32_state_present <= False;
            current_block        <= 0;
        end
        
        endaction
    endfunction

    // Final cleanups for statistics minima float 32
    rule minf32_done_vec (minf32_done);
        minf32_done <= False;
        Bit #(TAdd #(busaddrsize, datasize)) temp_address = extend(minf32_pindex_addr);
        WriteChunk #(busdatasize, busaddrsize, granularity) write_back = WriteChunk {
                                                                        signal : Break,
                                                                        data : extend(pack(minf32_p_index)),
                                                                        addr : truncate(temp_address),
                                                                        present : fromInteger(32/num_granularity)
                                                                    };
        to_mcu.enq(write_back);
    endrule

    // The master execute rule to send data to the right units 
    rule exec_master ;
        let x = decoded.first(); decoded.deq();
        if(x.code == VEC_NEG_I8)  negi8(x);
        if(x.code == VEC_NEG_I16) negi16(x);
        if(x.code == VEC_NEG_I32) negi32(x);
        if(x.code == VEC_NEG_F32) negf32(x);
        if(x.code == VEC_MIN_I8)  mini8(x);
        if(x.code == VEC_MIN_I16) mini16(x);
        if(x.code == VEC_MIN_I32) mini32(x);
        if(x.code == VEC_MIN_F32) minf32(x);
    endrule
    interface put_decoded = toPut (decoded);
    interface get_to_mcu = toGet(to_mcu);
endmodule

endpackage