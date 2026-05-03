// Watches DUT outputs every clock cycle
// Captures register writebacks
// Sends observed results to Scoreboard
// Never drives anything, read only

class mips_monitor;

    virtual mips_interface vif;
    mailbox mon2scbd;

    int current_stall_count;
    int total_stall_count;
    int wb_count;

    function new(virtual mips_interface vif, mailbox mon2scbd);
        this.vif = vif;
        this.mon2scbd = mon2scbd;
        current_stall_count = 0;
        total_stall_count = 0;
        wb_count = 0;
    endfunction

    // Watches every posedge
    // Three cases each cycle:
    // reset=1, skip
    // stall=1, count stall
    // wb_write=1, capture and send to scoreboard
    task run();
        mips_transaction observed_tr;

        $display("[MON] Monitor started\n");

        forever begin
            @(posedge vif.clk);

            // Skip during reset
            if (vif.reset === 1'b1)
                continue;

            // Stall cycle
            if (vif.cb_monitor.stall === 1'b1) begin
                current_stall_count++;
                total_stall_count++;
                $display("[MON] STALL cycle observed (count=%0d)",
                    current_stall_count);
                continue;
            end

            // Writeback observed
            if (vif.cb_monitor.wb_reg_write === 1'b1) begin

                observed_tr = new();
                observed_tr.obs_dest_reg = vif.cb_monitor.wb_reg_dest;
                observed_tr.obs_result = vif.cb_monitor.wb_reg_data;
                observed_tr.observed_stalls = current_stall_count;

                current_stall_count = 0;
                wb_count++;
                observed_tr.seq_id = wb_count;

                $display("[MON] WB observed - R%0d = %0d (stalls=%0d)",
                    observed_tr.obs_dest_reg,
                    observed_tr.obs_result,
                    observed_tr.observed_stalls);

                mon2scbd.put(observed_tr);

            end

        end

    endtask

    task wrapup();
        $display("[MON] Total writebacks : %0d", wb_count);
        $display("[MON] Total stalls     : %0d", total_stall_count);
    endtask

endclass