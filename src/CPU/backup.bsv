Instruction ins = unpack(new_stuff);
                Instruction nop = Instruction {
                                        code : NOP,
                                        src1 : NO,
                                        src2 : NO,
                                        aux  : NO,
                                        dst  : NO
                };

                if (future != NO && (future == ins.src1 || future == ins.src2))
                begin
                    // $display (pc, fshow(ins.code));
                    // $display(fshow(ins.code), fshow(future), fshow(ins.src1), fshow(ins.src2));
                    instructions.enq(nop);
                    future <= NO;
                end
                else
                begin
                    // $display (pc, fshow(ins.code));
                    instructions.enq(ins);
                    future <= ins.dst;
                    got_instruction.send();
                    
                end