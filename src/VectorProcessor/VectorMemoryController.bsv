package VectorMemoryController;
    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;
    import Bus::*;
    import VectorDefines::*;
    import VectorCSR::*;

    export VectorMemoryController (..);
    export mkVectorMemoryController;

    interface VectorMemoryController #(numeric type busdatasize, 
                                       numeric type busaddrsize,
                                       numeric type granularity);

        // Bus side
        interface Put #(Chunk #(busdatasize, busaddrsize, granularity)) put_responses;
        interface Get #(Chunk #(busdatasize, busaddrsize, granularity)) get_requests;
        
        // VPU side
        interface Put #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_req;
        interface Put #(WriteChunk #(busdatasize, busaddrsize, granularity)) write_req;
        interface Get #(DataChunk #(busdatasize, granularity)) read_res;

        // CSR side
        interface Get #(Bool) get_reset_csr;
    endinterface

    instance Connectable #(VectorMemoryController #(busdatasize, busaddrsize, granularity),
                           VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu,
                              VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity) csr) (Empty);
            mkConnection (mcu.get_reset_csr, csr.put_reset_csr);
        endmodule
    endinstance

    instance Connectable #(VectorMemoryController #(busdatasize, busaddrsize, granularity),
                           BusMaster #(busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu,
                              BusMaster #(busdatasize, busaddrsize, granularity) master) (Empty);
            mkConnection (mcu.get_requests, master.job_send);
            mkConnection (mcu.put_responses, master.job_done);
        endmodule
    endinstance

    module mkVectorMemoryController (VectorMemoryController #(busdatasize, busaddrsize, granularity));
        // provisos (Log#(TAdd#(TDiv#(busdatasize, granularity), 1), TLog#(TDiv#(busdatasize,
        // granularity))));
        
        FIFOF #(AddrChunk #(busdatasize, busaddrsize, granularity)) read_reqests <- mkBypassFIFOF;
        FIFOF #(WriteChunk #(busdatasize, busaddrsize, granularity)) write_reqests <- mkBypassFIFOF;
        FIFOF #(DataChunk #(busdatasize, granularity)) read_responses <- mkBypassFIFOF;

        FIFOF #(Chunk #(busdatasize, busaddrsize, granularity)) job_requests <- mkBypassFIFOF;
        FIFOF #(Chunk #(busdatasize, busaddrsize, granularity)) job_responses <- mkBypassFIFOF;

        PulseWire write_need <- mkPulseWire;
        PulseWire read_need <- mkPulseWire;

        PulseWire reset_csr <- mkPulseWire;

        Reg #(Bool) read_req_sent <- mkReg(False);
        Reg #(Bool) write_priority <- mkReg(True);

        rule scheduler;
            if (read_reqests.notEmpty() && write_reqests.notEmpty())
            begin
                if(write_priority)
                begin
                    write_priority <= False;
                    write_need.send();
                end
                else
                begin
                    write_priority <= True;
                    read_need.send();
                end
            end
            else if(read_reqests.notEmpty())
            begin
                read_need.send();
                write_priority <= True;
            end
            else if(write_reqests.notEmpty())
            begin
                write_priority <= False;
                write_need.send();
            end
        endrule
        rule process_write_req (write_need);
            let x = write_reqests.first();
            Chunk #(busdatasize, busaddrsize, granularity) y = Chunk {
                                                            control : Write,
                                                            data    : x.data,
                                                            addr    : x.addr,
                                                            present : x.present
                                                        };
            if (x.signal == Break) reset_csr.send();
            job_requests.enq(y);
            write_reqests.deq();
            // $display ("MCU ", fshow(x));
        endrule

        rule process_read_req (read_need);
            let x = read_reqests.first();
            // $display ("MCU ", fshow(x));
            Chunk #(busdatasize, busaddrsize, granularity) y = Chunk {
                                                            control : Read,
                                                            data : ?,
                                                            addr : x.addr,
                                                            present : x.present
                                                        };
            job_requests.enq(y);
            read_reqests.deq();
            // read_req_sent <= True;
        endrule

        rule process_responses;
            let x = job_responses.first();
            // $display ("MCU GOT RESPONSE", fshow(x));
            DataChunk #(busdatasize, granularity) y = DataChunk {
                                                data : x.data,
                                                present : x.present
                                            };
            read_responses.enq(y);
            job_responses.deq();
        endrule

        // Bus side
        interface Get get_requests = toGet (job_requests);
        interface Put put_responses = toPut (job_responses);
        
        // VX side
        interface Put read_req = toPut (read_reqests);
        interface Put write_req = toPut (write_reqests);
        interface Get read_res = toGet (read_responses);
    
        // CSR side
        interface Get get_reset_csr = toGet (reset_csr);

    endmodule

endpackage