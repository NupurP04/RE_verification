
// Gets transactions from Generator via mailbox
// Drives instructions onto DUT interface
// Handles stall signal from DUT

class mips_driver;

    virtual mips_interface vif;
    mailbox gen2drv;

    function new(virtual mips_interface vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    // ENCODE INSTRUCTION
    function logic [31:0] encode(mips_transaction tr);
        logic [31:0] instr;
        case (tr.instr_type)

            mips_transaction::ADD:
                instr = {6'b000000,
                         5'(tr.src1_reg),
                         5'(tr.src2_reg),
                         5'(tr.dest_reg),
                         5'b00000,
                         6'b100000};

            mips_transaction::SUB:
                instr = {6'b000000,
                         5'(tr.src1_reg),
                         5'(tr.src2_reg),
                         5'(tr.dest_reg),
                         5'b00000,
                         6'b100010};

            mips_transaction::AND:
                instr = {6'b000000,
                         5'(tr.src1_reg),
                         5'(tr.src2_reg),
                         5'(tr.dest_reg),
                         5'b00000,
                         6'b100100};

            mips_transaction::OR:
                instr = {6'b000000,
                         5'(tr.src1_reg),
                         5'(tr.src2_reg),
                         5'(tr.dest_reg),
                         5'b00000,
                         6'b100101};

            mips_transaction::NOP:
                instr = 32'b0;

            default: begin
                instr = 32'b0;
                $display("[DRV] WARNING: Unknown instruction — driving NOP");
            end

        endcase
        return instr;
    endfunction

    // APPLY RESET
    task apply_reset();
        $display("[DRV] Applying reset...");

        @(negedge vif.clk);
        vif.cb_driver.reset <= 1'b1;
        vif.cb_driver.instruction <= 32'b0;

        repeat(5) @(negedge vif.clk);

        vif.cb_driver.reset <= 1'b0;
        @(negedge vif.clk);

        $display("[DRV] Reset released\n");
    endtask


    // Drives instruction and handles stall cycles
    // Normal: drive instruction - wait - next
    // Stall: drive NOP - count - wait - check again
    task drive_instruction(mips_transaction tr);
        logic [31:0] encoded;
        int stall_count;
        stall_count = 0;

        encoded = encode(tr);

        $display("[DRV] Driving instr[%0d]: %s | encoded=0x%08h",
            tr.seq_id, tr.instr_label, encoded);

        // Drive instruction
        @(negedge vif.clk);
        vif.cb_driver.instruction <= encoded;

        // Sample stall on posedge
        @(posedge vif.clk);

        // Handle stall cycles
        while (vif.cb_monitor.stall === 1'b1) begin
            stall_count++;
            $display("[DRV] STALL for instr[%0d] — cycle %0d",
                tr.seq_id, stall_count);

            @(negedge vif.clk);
            vif.cb_driver.instruction <= 32'b0;

            @(posedge vif.clk);
        end

        // Record observed stalls
        tr.observed_stalls = stall_count;

        // Check stall count
        if (tr.observed_stalls == tr.expected_stalls)
            $display("[DRV] STALL OK instr[%0d]: expected=%0d observed=%0d",
                tr.seq_id, tr.expected_stalls, tr.observed_stalls);
        else
            $display("[DRV] STALL MISMATCH instr[%0d]: expected=%0d observed=%0d",
                tr.seq_id, tr.expected_stalls, tr.observed_stalls);

    endtask

    task run();
        mips_transaction tr;

        apply_reset();

        $display("[DRV] Starting to drive instructions\n");

        forever begin
            gen2drv.get(tr);
            drive_instruction(tr);
            $display("[DRV] instr[%0d] done\n", tr.seq_id);
        end

    endtask

endclass