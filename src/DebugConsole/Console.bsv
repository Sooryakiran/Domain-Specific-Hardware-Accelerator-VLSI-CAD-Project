package Console;
    import StmtFSM::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Connectable::*;

    import Bus::*;

    export Console (..);
    export ConsoleCore (..);
    export mkConsole;
    export mkConsoleCore;

    interface ConsoleCore #(numeric type datalen, numeric type addrlen, numeric type granularity);
        interface Put #(Chunk #(datalen, addrlen, granularity)) put_data;
        interface Get #(Chunk #(datalen, addrlen, granularity)) get_data;
    endinterface

    interface Console #(numeric type datalen, numeric type addrlen, numeric type granularity);
        interface BusSlave #(datalen, addrlen, granularity) bus_slave;
    endinterface

    instance Connectable #(ConsoleCore #(datalen, addrlen, granularity), BusSlave #(datalen, addrlen, granularity));
        module mkConnection #(ConsoleCore #(datalen, addrlen, granularity) c, BusSlave #(datalen, addrlen, granularity) b) (Empty);
            mkConnection (c.put_data, b.jobs_recieve);
            mkConnection (c.get_data, b.jobs_done);
        endmodule
    endinstance

    module mkConsole #(Integer id, Bit #(addrlen) address) (Console #(datalen, addrlen, granularity));
        ConsoleCore #(datalen, addrlen, granularity) console_core   <- mkConsoleCore;
        BusSlave    #(datalen, addrlen, granularity) bus_slave_c    <- mkBusSlave (address, address, id);
        mkConnection (console_core, bus_slave_c);

        interface bus_slave = bus_slave_c;
    endmodule

    module mkConsoleCore (ConsoleCore #(datalen, addrlen, granularity));
        FIFOF #(Chunk #(datalen, addrlen, granularity)) in_data <- mkBypassFIFOF;
        FIFOF #(Chunk #(datalen, addrlen, granularity)) out_data <- mkBypassFIFOF;

        rule put_to_console;
            let x = in_data.first();
            in_data.deq();
            if (x.control == Write)
            begin
                Bit #(TAdd #(32, datalen)) data = extend(x.data);

                if (x.present == 1)
                begin
                    Bit #(8) data_small = truncate(data);
                    $display ("CONSOLE %h | %d", data_small, data_small);
                end
                else if (x.present == 2)
                begin
                    Bit #(16) data_medium = truncate(data);
                    $display ("CONSOLE %h | %d", data_medium, data_medium);
                end
                else if (x.present == 4)
                begin
                    Bit #(32) data_big = truncate(data);
                    $display ("CONSOLE %h | %d | %f", data_big, data_big, data_big);
                end
            end
            Chunk #(datalen, addrlen, granularity) out_stuff = Chunk {
                                                                control : Response,
                                                                data : ?,
                                                                addr : ?,
                                                                present : ?};
            
            out_data.enq(out_stuff);
        endrule

        interface Put put_data = toPut(in_data);
        interface Get get_data = toGet(out_data);
    endmodule




    module test (Empty);
        // Stmt lol = seq

        // $display ("All tests done!");
        // endseq;

        // mkAutoFSM(lol);
    endmodule

endpackage