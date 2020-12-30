package VectorCSR;
    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;
    import VectorDefines::*;
    import Bus::*;

    interface VectorUniaryCSR #(numeric type datasize, numeric type busdatasize, numeric type busaddrsize, numeric type granularity);
        // Towards host/bus
        interface Put #(Chunk #(busdatasize, busaddrsize, granularity)) put_requests;
        interface Get #(Chunk #(busdatasize, busaddrsize, granularity)) get_responses;

        // Towards device
        interface Get #(VectorUniaryInstruction #(datasize)) get_instruction;
    endinterface

    instance Connectable #(VectorUniaryCSR #(datasize, busdatasize, busaddrsize, granularity), BusSlave #(busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorUniaryCSR #(datasize, busdatasize, busaddrsize, granularity) csr, 
                              BusSlave #(busdatasize, busaddrsize, granularity) bus_slave) (Empty);
            mkConnection (csr.put_requests, bus_slave.jobs_recieve);
            mkConnection (csr.get_responses, bus_slave.jobs_done);
        endmodule
    endinstance


    module mkVectorUniaryCSR #(Bit #(busaddrsize) address) (VectorUniaryCSR #(datasize, busdatasize, busaddrsize, granularity))
        provisos (Add #(na, datasize, busdatasize), // datasize lte buswidth
                  Add #(nb, 1,        busdatasize), // buswidth >= 1
                  Add #(nc, SizeOf #(Opcode), busdatasize)); // opcodesize lte buswidth

        Reg #(Bit #(1)) csr_start <- mkReg(0);              // address      write only
        Reg #(Bit #(datasize)) csr_src <- mkRegU;           // address + 1  write only
        Reg #(Bit #(datasize)) csr_block_sz <- mkRegU;      // address + 2  write only
        Reg #(Bit #(datasize)) csr_dst <- mkRegU;           // address + 3  write only
        Reg #(Opcode) csr_opcode <- mkRegU;                 // address + 4  write only
        Reg #(Bit #(1)) csr_idle <- mkReg(1);               // address + 5  read  only

        FIFOF #(Chunk #(busdatasize, busaddrsize, granularity)) responses <- mkPipelineFIFOF;
        FIFOF #(VectorUniaryInstruction #(datasize)) instructions <- mkBypassFIFOF;

        rule send_instruction (csr_start == 1);
            csr_start <= 0;
            VectorUniaryInstruction #(datasize) instr = VectorUniaryInstruction {
                                                                    code : csr_opcode,
                                                                    src1 : csr_src,
                                                                    blocksize : csr_block_sz,
                                                                    dst : csr_dst
                                                                };
            instructions.enq(instr);
            csr_idle <= 0;
        endrule

        function Action fn_put_requests (Chunk #(busdatasize, busaddrsize, granularity) x);
            action
                if (x.control == Read)
                begin
                    Chunk #(busdatasize, busaddrsize, granularity) res = Chunk {
                                                                            control : Response,
                                                                            data : extend(csr_idle),
                                                                            addr : ?,
                                                                            present : 1};
                    responses.enq(res);
                end
                else if (x.control == Write)
                begin
                    // $display ("CSR GOT WRITE ", fshow(x));
                    if(x.addr == address) csr_start <= truncate(x.data);
                    if(x.addr == address + 1) csr_src <= truncate(x.data);
                    if(x.addr == address + 2) csr_block_sz <= truncate(x.data);
                    if(x.addr == address + 3) csr_dst <= truncate(x.data);
                    if(x.addr == address + 4) csr_opcode <= unpack(truncate(x.data));

                    Chunk #(busdatasize, busaddrsize, granularity) res = Chunk {
                                                    control : Response,
                                                    data : ?,
                                                    addr : ?,
                                                    present : ?};
                    
                    responses.enq(res);
                end
            endaction
        endfunction

        // Bus side interface
        interface Put put_requests = toPut (fn_put_requests);
        interface Get get_responses = toGet (responses);

        // Home side interface
        interface Get get_instruction = toGet(instructions);
    endmodule

endpackage