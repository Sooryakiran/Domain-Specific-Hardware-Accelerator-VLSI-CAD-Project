package VectorUniaryFetch;

    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;

    import VectorMemoryController::*;
    import VectorDefines::*;
    import VectorCSR::*;

    interface VectorUniaryFetch #(numeric type datasize, 
                                  numeric type vectordatasize,
                                  numeric type busdatasize, 
                                  numeric type busaddrsize,
                                  numeric type granularity);
    
        // with csr
        interface Put #(VectorUniaryInstruction #(datasize)) put_instruction;
        
        // with memory controller
        interface Get #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_req;
        interface Put #(DataChunk #(busdatasize, granularity)) incoming_raw_data;

        // with exec
        interface Get #(BufferChunk #(datasize, vectordatasize, granularity)) outgoing_pro_data;

    endinterface

    instance Connectable #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity),
                           VectorMemoryController #(busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) fetch,
                             VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu) (Empty);
            mkConnection (fetch.read_req, mcu.read_req);
            mkConnection (fetch.incoming_raw_data, mcu.read_res);
        endmodule
    endinstance

    instance Connectable #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity),
                           VectorUniaryCSR #(datasize, busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) fetch,
                              VectorUniaryCSR #(datasize, busdatasize, busaddrsize, granularity) csr) (Empty);
            mkConnection (fetch.put_instruction, csr.get_instruction);
        endmodule
    endinstance

    module mkVectorUniaryFetch #(Integer temp_storage_size) (VectorUniaryFetch #(datasize, 
                                                    vectordatasize,
                                                    busdatasize,
                                                    busaddrsize,
                                                    granularity))
            provisos (Add #(na, vectordatasize, busdatasize),
                      Mul #(nb, granularity, vectordatasize),
                      Add #(nc, PresentSize #(vectordatasize, granularity), PresentSize #(busdatasize, granularity)));

        Integer num_vectordatasize = valueOf(vectordatasize);
        Integer num_granularity = valueOf(granularity);
                                                   
        FIFOF #(VectorUniaryInstruction #(datasize)) instructions <- mkPipelineFIFOF;
        FIFOF #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_requests <- mkBypassFIFOF;
        FIFOF #(DataChunk #(busdatasize, granularity)) read_responses <- mkBypassFIFOF;
        FIFOF #(BufferChunk #(datasize, vectordatasize, granularity)) decoded_instrutions <- mkSizedBypassFIFOF (temp_storage_size);
        Reg #(Bit #(datasize)) current_block <- mkReg(0);
        Reg #(Bit #(datasize)) block_count <- mkReg(0);
        Reg #(Bool) is_busy <- mkReg(False);
        Reg #(VectorUniaryInstruction #(datasize)) current_instruction <- mkRegU;

        function Action bitfetch (Bit #(datasize) start, Bit #(datasize) blocksize, Bit #(datasize) dst, Integer n);
            action
                // $display ("ADDRESS FETCH: ", start + current_block * fromInteger (n)/ fromInteger(num_granularity));
                // $display (blocksize * fromInteger(n) /fromInteger(num_vectordatasize) + 1);
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

                    // $display(fshow(r));
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
                    // $display (fshow(r));
                end
            endaction


        endfunction

        function Action bitdecode (DataChunk #(busdatasize, granularity) x, Integer n);
            action
                let y = current_instruction;
                Bit #(datasize) count_plus = block_count + fromInteger(num_vectordatasize/n);
                
                if (count_plus < y.blocksize)
                begin
                    // Normal enq
                    // $display (x.present);
                    Bit #(PresentSize #(vectordatasize, granularity)) temp_present = truncate(x.present);
                    // $display (temp_present);
                    BufferChunk #(datasize, vectordatasize, granularity) to_exec = BufferChunk {
                                                                                signal : Continue,
                                                                                code : y.code,
                                                                                dst : y.dst,
                                                                                vector_data : truncate(x.data),
                                                                                present : truncate(x.present)
                                                                                };
                    decoded_instrutions.enq(to_exec);
                    block_count <= count_plus;
                    // $display (fshow(to_exec));
                end
                else
                begin
                    // END enq

                    BufferChunk #(datasize, vectordatasize, granularity) to_exec = BufferChunk {
                                                                                signal : Break,
                                                                                code : y.code,
                                                                                dst : y.dst,
                                                                                vector_data : truncate(x.data),
                                                                                present : truncate(x.present)
                                                                                };
                    
                    decoded_instrutions.enq(to_exec);
                    // $display (fshow(to_exec));
                    block_count <= 0;
                    is_busy <= False;
                    // Reset is_busy, block_count
                end

                // $display(count_plus, y.blocksize);

                // block_count <= count_plus;

            endaction
        endfunction

        rule fetch_main (!is_busy);
            let x = instructions.first();
            current_instruction <= x;
            // $display ("FROM FETCH ", fshow(x));
            if (x.code == VEC_NEG_I8) bitfetch (x.src1, x.blocksize, x.dst, 8);
            if (x.code == VEC_NEG_I16) bitfetch (x.src1, x.blocksize, x.dst, 16);
            if (x.code == VEC_NEG_I32) bitfetch (x.src1, x.blocksize, x.dst, 32);
            if (x.code == VEC_NEG_F32) bitfetch (x.src1, x.blocksize, x.dst, 32);
            if (x.code == VEC_MIN_I8) bitfetch (x.src1, x.blocksize, x.dst, 8);
            if (x.code == VEC_MIN_I16) bitfetch (x.src1, x.blocksize, x.dst, 16);
            if (x.code == VEC_MIN_I32) bitfetch (x.src1, x.blocksize, x.dst, 32);
            if (x.code == VEC_MIN_F32) bitfetch (x.src1, x.blocksize, x.dst, 32);
        endrule

        rule decode;
            let x = read_responses.first(); read_responses.deq();
            let y = current_instruction;
            if (y.code == VEC_NEG_I8 || y.code == VEC_MIN_I8) bitdecode(x, 8);
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