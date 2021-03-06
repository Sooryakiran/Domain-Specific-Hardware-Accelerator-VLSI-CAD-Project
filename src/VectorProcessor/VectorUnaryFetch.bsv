////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : The fetch unit for unary vector ops
////////////////////////////////////////////////////////////////////////////////

package VectorUnaryFetch;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import GetPut::*;
import FIFOF::*;
import SpecialFIFOs::*;
import Connectable::*;
import VectorMemoryController::*;
import VectorDefines::*;
import VectorCSR::*;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// Interface of the unary fetch
// Param datasize       : Datasize of the Registers
// Param vectordatasize : Number of bits that can be parallelly operated upon
// Param busdatasize    : Width of the databus
// Param busaddrsize    : Width of the address bus
// Param granularity    : The smallest addressable unit size
interface VectorUnaryFetch #(numeric type datasize, 
                             numeric type vectordatasize,
                             numeric type busdatasize, 
                             numeric type busaddrsize,
                             numeric type granularity);

    // with csr
    interface Put #(VectorUnaryInstruction #(datasize)) put_instruction;
    
    // with memory controller
    interface Get #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_req;
    interface Put #(DataChunk #(busdatasize, granularity)) incoming_raw_data;

    // with exec
    interface Get #(BufferChunk #(datasize, vectordatasize, granularity)) outgoing_pro_data;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Instances
////////////////////////////////////////////////////////////////////////////////

// Define the connection between a vector fetch and a memory controller
instance Connectable #(VectorUnaryFetch #(datasize, 
                                          vectordatasize, 
                                          busdatasize, 
                                          busaddrsize, 
                                          granularity),
                       VectorMemoryController #(busdatasize, 
                                                busaddrsize, 
                                                granularity));
    module mkConnection #(VectorUnaryFetch #(datasize, 
                                             vectordatasize, 
                                             busdatasize, 
                                             busaddrsize, 
                                             granularity) fetch,
                          VectorMemoryController #(busdatasize, 
                                                   busaddrsize, 
                                                   granularity) mcu) (Empty);
        mkConnection (fetch.read_req, mcu.read_req);
        mkConnection (fetch.incoming_raw_data, mcu.read_res);
    endmodule
endinstance

// Define the connection between a vector fetch and a CSR
instance Connectable #(VectorUnaryFetch #(datasize, 
                                          vectordatasize, 
                                          busdatasize, 
                                          busaddrsize, 
                                          granularity),
                       VectorUnaryCSR #(datasize, 
                                        busdatasize, 
                                        busaddrsize, 
                                        granularity));
    module mkConnection #(VectorUnaryFetch #(datasize, 
                                             vectordatasize, 
                                             busdatasize, 
                                             busaddrsize, 
                                             granularity) fetch,
                          VectorUnaryCSR #(datasize, 
                                           busdatasize, 
                                           busaddrsize, 
                                           granularity) csr) (Empty);
        mkConnection (fetch.put_instruction, csr.get_instruction);
    endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates vector unary fetch
// Param temp_storage_size : Size of the temporary storage units
module mkVectorUnaryFetch #(Integer temp_storage_size) 
                           (VectorUnaryFetch #(datasize, 
                                               vectordatasize,
                                               busdatasize,
                                               busaddrsize,
                                               granularity))
        provisos (Add #(na, vectordatasize, busdatasize),
                  Mul #(nb, granularity, vectordatasize),
                  Add #(nc, PresentSize #(vectordatasize, granularity), 
                            PresentSize #(busdatasize, granularity)));

    Integer num_vectordatasize = valueOf(vectordatasize);
    Integer num_granularity = valueOf(granularity);
                                                
    FIFOF #(VectorUnaryInstruction #(datasize)) instructions <- mkPipelineFIFOF;
    FIFOF #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_requests <- mkBypassFIFOF;
    FIFOF #(DataChunk #(busdatasize, granularity)) read_responses <- mkBypassFIFOF;
    FIFOF #(BufferChunk #(datasize, vectordatasize, granularity)) decoded_instrutions <- mkSizedBypassFIFOF (temp_storage_size);
    Reg #(Bit #(datasize)) current_block <- mkReg(0);
    Reg #(Bit #(datasize)) block_count <- mkReg(0);
    Reg #(Bool) is_busy <- mkReg(False);
    Reg #(VectorUnaryInstruction #(datasize)) current_instruction <- mkRegU;

    // Divides a vector into parts of digesible units and requests the data to the memory
    function Action bitfetch (Bit #(datasize) start, Bit #(datasize) blocksize, Bit #(datasize) dst, Integer n);
        action
            Bit #(datasize) next_block = current_block + fromInteger(num_vectordatasize/n);
            if (next_block < blocksize)
            begin
                current_block <= next_block;
                Bit #(TAdd #(busaddrsize, datasize)) temp_addr = extend(start + current_block * fromInteger (n)/fromInteger (num_granularity));
                Bit #(busaddrsize) address = truncate(temp_addr);
                Bit #(PresentSize #(busdatasize, granularity)) presence = fromInteger(num_vectordatasize/num_granularity);
                AddrChunk #(busdatasize, busaddrsize, granularity) r = AddrChunk {
                                                                        addr : address,
                                                                        present : presence
                                                                    };
                read_requests.enq(r);
            end
            else
            begin
                Bit #(TAdd #(busaddrsize, datasize)) temp_addr = extend(start + current_block * fromInteger (n)/ fromInteger(num_granularity));
                Bit #(busaddrsize) address = truncate(temp_addr);
                Bit #(TAdd #(PresentSize #(busdatasize, granularity), datasize)) temp_presence = extend((fromInteger(num_vectordatasize/n) - next_block + blocksize)*fromInteger(n/num_granularity));
                Bit #(PresentSize #(busdatasize, granularity)) presence = truncate(temp_presence);

                AddrChunk #(busdatasize, busaddrsize, granularity) r = AddrChunk {
                                                                        addr : address,
                                                                        present : presence
                                                                    };
                
                current_block <= 0;
                read_requests.enq(r);
                instructions.deq();
                is_busy <= True;
            end
        endaction
    endfunction

    // Decodes the response from the memory and pushes it to the temp storage
    function Action bitdecode (DataChunk #(busdatasize, granularity) x, Integer n);
        action
            let y = current_instruction;
            Bit #(datasize) count_plus = block_count + fromInteger(num_vectordatasize/n);
            
            if (count_plus < y.blocksize)
            begin
                Bit #(PresentSize #(vectordatasize, granularity)) temp_present = truncate(x.present);
                BufferChunk #(datasize, vectordatasize, granularity) to_exec = BufferChunk {
                                                                            signal : Continue,
                                                                            code : y.code,
                                                                            dst : y.dst,
                                                                            aux : y.aux,
                                                                            vector_data : truncate(x.data),
                                                                            present : truncate(x.present)
                                                                            };
                decoded_instrutions.enq(to_exec);
                block_count <= count_plus;
            end
            else
            begin
                BufferChunk #(datasize, vectordatasize, granularity) to_exec = BufferChunk {
                                                                            signal : Break,
                                                                            code : y.code,
                                                                            dst : y.dst,
                                                                            aux : y.aux,
                                                                            vector_data : truncate(x.data),
                                                                            present : truncate(x.present)
                                                                            };
                
                decoded_instrutions.enq(to_exec);
                block_count <= 0;
                is_busy <= False;
            end
        endaction
    endfunction

    // The fetch master rule
    (* descending_urgency = "decode, fetch_main" *)
    rule fetch_main (!is_busy);
        let x = instructions.first();
        current_instruction <= x;
        if (x.code == VEC_NEG_I8)  bitfetch (x.src1, x.blocksize, x.dst, 8);
        if (x.code == VEC_NEG_I16) bitfetch (x.src1, x.blocksize, x.dst, 16);
        if (x.code == VEC_NEG_I32) bitfetch (x.src1, x.blocksize, x.dst, 32);
        if (x.code == VEC_NEG_F32) bitfetch (x.src1, x.blocksize, x.dst, 32);
        if (x.code == VEC_MIN_I8)  bitfetch (x.src1, x.blocksize, x.dst, 8);
        if (x.code == VEC_MIN_I16) bitfetch (x.src1, x.blocksize, x.dst, 16);
        if (x.code == VEC_MIN_I32) bitfetch (x.src1, x.blocksize, x.dst, 32);
        if (x.code == VEC_MIN_F32) bitfetch (x.src1, x.blocksize, x.dst, 32);
    endrule

    // The decode master rule
    rule decode;
        let x = read_responses.first(); read_responses.deq();
        let y = current_instruction;
        if (y.code == VEC_NEG_I8 || y.code == VEC_MIN_I8)   bitdecode(x, 8);
        if (y.code == VEC_NEG_I16 || y.code == VEC_MIN_I16) bitdecode(x, 16);
        if (y.code == VEC_NEG_I32 || y.code == VEC_MIN_I32) bitdecode(x, 32);
        if (y.code == VEC_NEG_F32 || y.code == VEC_MIN_F32) bitdecode(x, 32);
    endrule

    interface Put put_instruction = toPut (instructions);
    interface Get read_req = toGet (read_requests);
    interface Put incoming_raw_data = toPut (read_responses);
    interface outgoing_pro_data = toGet(decoded_instrutions);
endmodule

endpackage