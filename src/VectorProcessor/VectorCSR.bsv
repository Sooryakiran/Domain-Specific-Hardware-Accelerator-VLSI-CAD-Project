package VectorCSR;
    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;
    import VectorDefines::*;
    import Bus::*;

    export VectorUnaryCSR (..);
    export mkVectorUnaryCSR;

    interface VectorUnaryCSR #(numeric type datasize, numeric type busdatasize, numeric type busaddrsize, numeric type granularity);
        // Towards host/bus
        interface Put #(Chunk #(busdatasize, busaddrsize, granularity)) put_requests;
        interface Get #(Chunk #(busdatasize, busaddrsize, granularity)) get_responses;

        // Towards device
        interface Get #(VectorUnaryInstruction #(datasize)) get_instruction;
        interface Put #(Bool) put_reset_csr;
    endinterface

    instance Connectable #(VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity), BusSlave #(busdatasize, busaddrsize, granularity));
        module mkConnection #(VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity) csr, 
                              BusSlave #(busdatasize, busaddrsize, granularity) bus_slave) (Empty);
            mkConnection (csr.put_requests, bus_slave.job_recieve);
            mkConnection (csr.get_responses, bus_slave.job_done);
        endmodule
    endinstance


    module mkVectorUnaryCSR #(Bit #(busaddrsize) address) (VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity))
        provisos (Add #(na, datasize, busdatasize), // datasize lte buswidth
                  Add #(nb, 1,        busdatasize), // buswidth >= 1
                  Add #(nc, SizeOf #(Opcode), busdatasize)); // opcodesize lte buswidth

        Reg #(Bit #(1)) csr_start <- mkReg(0);              // address      write only
        Reg #(Bit #(datasize)) csr_src <- mkRegU;           // address + 1  write only
        Reg #(Bit #(datasize)) csr_block_sz <- mkRegU;      // address + 2  write only
        Reg #(Bit #(datasize)) csr_dst <- mkRegU;           // address + 3  write only
        Reg #(Opcode) csr_opcode <- mkRegU;                 // address + 4  write only
        Reg #(Bit #(1)) csr_idle <- mkReg(1);               // address + 5  read  only
        Reg #(Bit #(datasize)) csr_aux <- mkRegU;           // address + 6

        FIFOF #(Chunk #(busdatasize, busaddrsize, granularity)) responses <- mkPipelineFIFOF;
        FIFOF #(VectorUnaryInstruction #(datasize)) instructions <- mkBypassFIFOF;

        FIFOF #(Bool) reset_csr <- mkBypassFIFOF;

        rule reset_status;
            let x = reset_csr.first(); reset_csr.deq();
            if (x) 
            begin
                csr_idle <= 1;
            end
        endrule

        rule send_instruction (csr_start == 1);
            csr_start <= 0;
            VectorUnaryInstruction #(datasize) instr = VectorUnaryInstruction {
                                                                    code : csr_opcode,
                                                                    src1 : csr_src,
                                                                    blocksize : csr_block_sz,
                                                                    dst : csr_dst,
                                                                    aux : csr_aux
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
                    if(x.addr == address + 6) csr_aux <= unpack(truncate(x.data));

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
        interface Put put_reset_csr = toPut(reset_csr);
    endmodule

endpackage