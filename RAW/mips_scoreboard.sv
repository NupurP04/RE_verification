// Compares expected results from Generator against observed results from Monitor
// Reports PASS or FAIL
class mips_scoreboard;

    mailbox gen2scbd;
    mailbox mon2scbd;

    // Storing expected and observed separately
    mips_transaction expected_q[$];
    mips_transaction observed_q[$];

    int value_pass;
    int value_fail;
    int stall_pass;
    int stall_fail;
    int total_checked;

    function new(mailbox gen2scbd, mailbox mon2scbd);
        this.gen2scbd = gen2scbd;
        this.mon2scbd = mon2scbd;
        value_pass = 0;
        value_fail = 0;
        stall_pass = 0;
        stall_fail = 0;
        total_checked = 0;
    endfunction

    // COLLECT EXPECTED
    // Runs forever pulling from gen2scbd
    // Skips NOPs as they produce no writeback
    task collect_expected();
        mips_transaction tr;
        forever begin
            gen2scbd.get(tr);

            if (tr.instr_type == mips_transaction::NOP) begin
                $display("[SCBD] Skipping NOP instr[%0d]", tr.seq_id);
                continue;
            end

            expected_q.push_back(tr);
            $display("[SCBD] Expected stored: instr[%0d] R%0d=%0d stalls=%0d",
                tr.seq_id, tr.dest_reg,
                tr.expected_result, tr.expected_stalls);
        end
    endtask

    // COLLECT OBSERVED
    // Runs forever pulling from mon2scbd
    // Calls check() after each observed arrives
    task collect_observed();
        mips_transaction tr;
        forever begin
            mon2scbd.get(tr);

            observed_q.push_back(tr);
            $display("[SCBD] Observed received: R%0d=%0d stalls=%0d",
                tr.obs_dest_reg,
                tr.obs_result,
                tr.observed_stalls);

            check();
        end
    endtask

    // Compares one expected against one observed
    // Called every time a new observed result arrives
    // CHECK 1: Correct register written?
    // CHECK 2: Correct value written?
    // CHECK 3: Correct stall count?
    task check();
        mips_transaction expected;
        mips_transaction observed;

        if (expected_q.size() == 0 || observed_q.size() == 0)
            return;

        expected = expected_q.pop_front();
        observed = observed_q.pop_front();

        total_checked++;

        $display("\n[SCBD] Checking instr[%0d] ", expected.seq_id);
        $display("[SCBD] Instruction : %s", expected.instr_label);
        $display("[SCBD] Expected    : R%0d=%0d stalls=%0d",
            expected.dest_reg,
            expected.expected_result,
            expected.expected_stalls);
        $display("[SCBD] Observed    : R%0d=%0d stalls=%0d",
            observed.obs_dest_reg,
            observed.obs_result,
            observed.observed_stalls);

        // CHECK 1: Correct register?
        if (observed.obs_dest_reg !== expected.dest_reg) begin
            $display("[SCBD] FAIL: Wrong register - expected R%0d got R%0d",
                expected.dest_reg, observed.obs_dest_reg);
            value_fail++;
        end

        // CHECK 2: Correct value?
        else if (observed.obs_result === expected.expected_result) begin
            $display("[SCBD] PASS: R%0d = %0d correct",
                expected.dest_reg, observed.obs_result);
            value_pass++;
        end
        else begin
            $display("[SCBD] FAIL: R%0d expected=%0d got=%0d",
                expected.dest_reg,
                expected.expected_result,
                observed.obs_result);

            if (expected.has_RAW)
                $display("[SCBD] RAW on R%0d (gap=%0d) not handled!",
                    expected.RAW_reg, expected.RAW_gap);

            value_fail++;
        end

        // CHECK 3: Correct stall count?
        if (observed.observed_stalls === expected.expected_stalls) begin
            $display("[SCBD] PASS: Stall count expected=%0d observed=%0d",
                expected.expected_stalls, observed.observed_stalls);
            stall_pass++;
        end
        else begin
            $display("[SCBD] FAIL: Stall count expected=%0d observed=%0d",
                expected.expected_stalls, observed.observed_stalls);

            if (observed.observed_stalls < expected.expected_stalls)
                $display("[SCBD] Too few stalls — RAW not fully resolved");
            else
                $display("[SCBD] Too many stalls — unnecessary stalling");

            stall_fail++;
        end

    endtask

    task run();
        $display("[SCBD] Scoreboard started\n");
        fork
            collect_expected();
            collect_observed();
        join_none
    endtask


    task wrapup();
        $display("\n[SCBD] ============================================");
        $display("[SCBD] SCOREBOARD FINAL SUMMARY");
        $display("[SCBD] ============================================");
        $display("[SCBD] Total checked      : %0d", total_checked);
        $display("[SCBD] Value  PASS        : %0d", value_pass);
        $display("[SCBD] Value  FAIL        : %0d", value_fail);
        $display("[SCBD] Stall  PASS        : %0d", stall_pass);
        $display("[SCBD] Stall  FAIL        : %0d", stall_fail);
        $display("[SCBD] ============================================");

        if (value_fail == 0 && stall_fail == 0)
            $display("[SCBD] RESULT: ALL TESTS PASSED");
        else begin
            $display("[SCBD] RESULT: SOME TESTS FAILED");
            if (value_fail > 0)
                $display("[SCBD] %0d value failures — RAW not handled", value_fail);
            if (stall_fail > 0)
                $display("[SCBD] %0d stall failures — stall unit bug", stall_fail);
        end
    endtask

endclass