
// Creates RAW hazard instruction sequences
// Maintains software register file
// Computes expected results
// Sends transactions to Driver and Scoreboard

class mips_generator;

    mailbox gen2drv;
    mailbox gen2scbd;

    // Used to compute expected results
    logic [31:0] reg_file [0:31];

    // RECENT INSTRUCTION QUEUE
    // Keeps last 3 instructions for RAW detection
    mips_transaction recent_q[$];
    int seq_counter;

    function new(mailbox gen2drv, mailbox gen2scbd);
        this.gen2drv = gen2drv;
        this.gen2scbd = gen2scbd;
        seq_counter = 0;
        init_reg_file();
    endfunction

    // REGISTER FILE INITIALIZATION
    // Match DUT initial register values
    // R2=10, R3=5, R5=3, R7=15
    function void init_reg_file();
        foreach (reg_file[i])
            reg_file[i] = 32'd0;

        reg_file[0] = 32'd0;
        reg_file[2] = 32'd10;
        reg_file[3] = 32'd5;
        reg_file[5] = 32'd3;
        reg_file[7] = 32'd15;
        reg_file[8] = 32'd8;
        reg_file[9] = 32'd4;

        $display("[GEN] Register file initialized:");
        $display(" R2=%0d R3=%0d R5=%0d R7=%0d R8=%0d R9=%0d",
            reg_file[2], reg_file[3], reg_file[5], reg_file[7], reg_file[8], reg_file[9]);
    endfunction


    // RAW HAZARD DETECTION
    // Checks if current instruction reads a register that a recent instruction wrote to
    function void detect_RAW(mips_transaction tr);
        tr.has_RAW = 0;
        tr.RAW_gap = -1;
        tr.RAW_reg = -1;

        for (int gap = 0; gap < recent_q.size(); gap++) begin
            mips_transaction prev;
            prev = recent_q[recent_q.size() - 1 - gap];

            if (prev.instr_type == mips_transaction::NOP)
                continue;

            if (prev.dest_reg == 0)
                continue;

            if (prev.dest_reg == tr.src1_reg ||
                prev.dest_reg == tr.src2_reg) begin

                tr.has_RAW = 1;
                tr.RAW_gap = gap;
                tr.RAW_reg = prev.dest_reg;

                $display("[GEN] RAW detected: instr[%0d] reads R%0d written by instr[%0d] (gap=%0d)",
                    tr.seq_id, tr.RAW_reg, prev.seq_id, gap);
                break;
            end
        end
    endfunction

  
    // COMPUTE EXPECTED RESULT
   // Updates reg_file after computation
    // This is the reference model
    function void compute_expected(mips_transaction tr);
        case (tr.instr_type)

            mips_transaction::ADD: begin
                tr.src1_val = reg_file[tr.src1_reg];
                tr.src2_val = reg_file[tr.src2_reg];
                tr.expected_result = tr.src1_val + tr.src2_val;
                if (tr.dest_reg != 0)
                    reg_file[tr.dest_reg] = tr.expected_result;
            end

            mips_transaction::SUB: begin
                tr.src1_val = reg_file[tr.src1_reg];
                tr.src2_val = reg_file[tr.src2_reg];
                tr.expected_result = tr.src1_val - tr.src2_val;
                if (tr.dest_reg != 0)
                    reg_file[tr.dest_reg] = tr.expected_result;
            end

            mips_transaction::AND: begin
                tr.src1_val = reg_file[tr.src1_reg];
                tr.src2_val = reg_file[tr.src2_reg];
                tr.expected_result = tr.src1_val & tr.src2_val;
                if (tr.dest_reg != 0)
                    reg_file[tr.dest_reg] = tr.expected_result;
            end

            mips_transaction::OR: begin
                tr.src1_val = reg_file[tr.src1_reg];
                tr.src2_val = reg_file[tr.src2_reg];
                tr.expected_result = tr.src1_val | tr.src2_val;
                if (tr.dest_reg != 0)
                    reg_file[tr.dest_reg] = tr.expected_result;
            end

            mips_transaction::NOP: begin
                tr.src1_val = 32'd0;
                tr.src2_val = 32'd0;
                tr.expected_result = 32'd0;
                tr.dest_reg = 0;
            end

        endcase
    endfunction

  
    task create_and_send(
        input mips_transaction::instr_type_e itype,
        input int dest,
        input int src1,
        input int src2
    );
        mips_transaction tr;
        tr = new();
        tr.instr_type = itype;
        tr.dest_reg = dest;
        tr.src1_reg = src1;
        tr.src2_reg = src2;
        tr.seq_id = ++seq_counter;

        detect_RAW(tr);
        compute_expected(tr);
        tr.compute_expected_stalls();
        tr.build_label();
        $display("[GEN] Created: %s", tr.instr_label);
        recent_q.push_back(tr);
        if (recent_q.size() > 3)
            recent_q.pop_front();
        gen2drv.put(tr);
        gen2scbd.put(tr);

    endtask

    task run();
  
        $display("[GEN] Starting RAW Hazard Test Sequences");

        test_RAW_0gap();
        #10;
        test_RAW_1gap();
        #10;
        test_RAW_2gap();
        #10;
        test_RAW_diff_types();

        $display("\n[GEN] All sequences sent\n");
    endtask

    // TEST 1: RAW with 0 instruction gap
    // ADD R1,R2,R3 - writes R1=15
    // SUB R4,R1,R5 - reads R1 immediately (RAW gap=0 stalls=2)
    // AND R6,R1,R7 - reads R1 again (RAW gap=1 stalls=1)
    task test_RAW_0gap();
        $display("[GEN] TEST 1: RAW 0 gap ");
        recent_q.delete();

        create_and_send(mips_transaction::ADD, 1, 2, 3);
        // R1 = R2+R3 = 10+5 = 15

        create_and_send(mips_transaction::SUB, 4, 1, 5);
        // R4 = R1-R5 = 15-3 = 12  RAW gap=0 stalls=2

        create_and_send(mips_transaction::AND, 6, 1, 7);
        // R6 = R1&R7 = 15&15 = 15  RAW gap=1 stalls=1

        $display("[GEN] TEST 1 done \n");
    endtask


    // TEST 2: RAW with 1 instruction gap
    // ADD R1,R2,R3 - writes R1=15
    // OR  R10,R8,R9 - unrelated (gap)
    // SUB R4,R1,R5 - reads R1 (RAW gap=1 stalls=1)
    task test_RAW_1gap();
        $display("[GEN] TEST 2: RAW 1 gap ");
        recent_q.delete();

        create_and_send(mips_transaction::ADD, 1, 2, 3);
        // R1 = 15

        create_and_send(mips_transaction::OR, 10, 8, 9);
        // R10 = R8|R9 = 8|4 = 12  unrelated

        create_and_send(mips_transaction::SUB, 4, 1, 5);
        // R4 = R1-R5 = 15-3 = 12  RAW gap=1 stalls=1

        $display("[GEN] TEST 2 done \n");
    endtask

 
    // TEST 3: RAW with 2 instruction gap — SAFE
    // ADD R1,R2,R3 - writes R1=15
    // OR  R10,R8,R9 - gap 1
    // AND R11,R7,R9 - gap 2
    // SUB R4,R1,R5 - reads R1 (SAFE gap=2 stalls=0)
    task test_RAW_2gap();
        $display("[GEN] TEST 3: RAW 2 gap (safe) ");
        recent_q.delete();

        create_and_send(mips_transaction::ADD, 1, 2, 3);
        // R1 = 15

        create_and_send(mips_transaction::OR, 10, 8, 9);
        // R10 = 12  gap 1

        create_and_send(mips_transaction::AND, 11, 7, 9);
        // R11 = R7&R9 = 15&4 = 4  gap 2

        create_and_send(mips_transaction::SUB, 4, 1, 5);
        // R4 = R1-R5 = 15-3 = 12 SAFE no stalls

        $display("[GEN] TEST 3 done \n");
    endtask

    // TEST 4: Different instruction types
    // ADD R1,R2,R3 - writes R1=15
    // SUB R1,R8,R9 - writes R1=4  (also RAW with AND below)
    // AND R6,R1,R7 - reads R1 (RAW gap=0 stalls=2)

    task test_RAW_diff_types();
        $display("[GEN] TEST 4: Different instruction types ");
        recent_q.delete();

        create_and_send(mips_transaction::ADD, 1, 2, 3);
        // R1 = 15

        create_and_send(mips_transaction::SUB, 1, 8, 9);
        // R1 = R8-R9 = 8-4 = 4

        create_and_send(mips_transaction::AND, 6, 1, 7);
        // R6 = R1&R7 = 4&15 = 4 RAW with SUB gap=0 stalls=2

        $display("[GEN] TEST 4 done \n");
    endtask

endclass