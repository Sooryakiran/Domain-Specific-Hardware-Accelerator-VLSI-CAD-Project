package VectorExec;
    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;
    import FloatingPoint::*;

    import Bus::*;

    import VectorDefines::*;
    import VectorUniaryFetch::*;
    import VectorMemoryController::*;

    export VectorExec (..);
    export mkVectorExec;
    
    interface VectorExec #(numeric type datasize, 
                              numeric type vectordatasize, 
                              numeric type busdatasize, 
                              numeric type busaddrsize, 
                              numeric type granularity);
        interface Put #(BufferChunk #(datasize, vectordatasize, granularity)) put_decoded;
        interface Get #(WriteChunk #(busdatasize, busaddrsize, granularity)) get_to_mcu;
    endinterface

    instance Connectable #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity),
                           VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorUniaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) fetch,
                              VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) exec) (Empty);
            mkConnection (fetch.outgoing_pro_data, exec.put_decoded);
        endmodule
    endinstance

    instance Connectable #(VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity),
                           VectorMemoryController #(busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) exec,
                              VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu) (Empty);
            mkConnection (exec.get_to_mcu, mcu.write_req);
        endmodule
    endinstance

    module mkVectorExec (VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity))
        provisos (Add #(na, 8, vectordatasize),
                  Add #(nb, PresentSize #(vectordatasize, granularity), PresentSize #(busdatasize, granularity)),
                  Add #(nc, vectordatasize, busdatasize),
                  Add #(nd, 16, vectordatasize),
                  Add #(ne, 32, vectordatasize));
        FIFOF #(BufferChunk #(datasize, vectordatasize, granularity)) decoded <- mkPipelineFIFOF;
        FIFOF #(WriteChunk #(busdatasize, busaddrsize, granularity)) to_mcu <-mkBypassFIFOF;

        Integer num_vectorsize = valueOf (vectordatasize);
        Integer num_granularity = valueOf (granularity);
        Reg #(Bit #(datasize)) current_block <- mkReg(0);

        function negi8 (BufferChunk #(datasize, vectordatasize, granularity) x);
            action
                Bit #(vectordatasize) values = x.vector_data;
                Bit #(vectordatasize) outs[num_vectorsize/8];

                Int #(8) slice_curr = -unpack(values[7 : 0]);
                outs[0] = extend(pack(slice_curr));

                // This wil get unrolled yaay!
                for (Integer i=8; i < num_vectorsize; i = i + 8)
                begin
                    Int #(8) slice = -unpack(values[i+7 : i]);
                    outs[i/8] = outs[i/8 - 1] + (extend(pack(slice)) << i);
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
                    // Reset and stuff
                    current_block <= 0;
                end
                to_mcu.enq(write_back);
                // $display (fshow(write_back));
            endaction
        endfunction

        function negi16 (BufferChunk #(datasize, vectordatasize, granularity) x);
            action
                // $display ("hey");
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
                    // Reset and stuff
                    current_block <= 0;
                    // TODO reset csr
                end
                to_mcu.enq(write_back);
                // $display (fshow(write_back));
            endaction
        endfunction

        function negi32 (BufferChunk #(datasize, vectordatasize, granularity) x);
            action
                // $display ("hey");
                Bit #(vectordatasize) values = x.vector_data;
                Bit #(vectordatasize) outs[num_vectorsize/32];

                Int #(32) slice_curr = -unpack(values[31 : 0]);
                outs[0] = extend(pack(slice_curr));

                // This wil get unrolled yaay!
                // $display ("INP %b", values);
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
                    // Reset and stuff
                    current_block <= 0;
                    // TODO reset csr
                end

                // $display ("OUT %b", outputs);
                to_mcu.enq(write_back);
                // $display (fshow(write_back));
            endaction
        endfunction

        function negf32 (BufferChunk #(datasize, vectordatasize, granularity) x);
            action
                // $display ("hey");
                Bit #(vectordatasize) values = x.vector_data;
                Bit #(vectordatasize) outs[num_vectorsize/32];

                Float slice_curr = -unpack(values[31 : 0]);
                outs[0] = extend(pack(slice_curr));

                // This wil get unrolled yaay!
                // $display ("INP %b", values);
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
                    // Reset and stuff
                    current_block <= 0;
                    // TODO reset csr
                end

                // $display ("OUT %b", outputs);
                to_mcu.enq(write_back);
                // $display (fshow(write_back));
            endaction
        endfunction


        rule exec_master;
            let x = decoded.first(); decoded.deq();
            // $display (fshow(x));
            if(x.code == VEC_NEG_I8)  negi8(x);
            if(x.code == VEC_NEG_I16) negi16(x);
            if(x.code == VEC_NEG_I32) negi32(x);
            if(x.code == VEC_NEG_F32) negf32(x);
            
        endrule

        interface put_decoded = toPut (decoded);
        interface get_to_mcu = toGet(to_mcu);
    endmodule

endpackage