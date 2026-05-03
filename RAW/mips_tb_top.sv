
// Instantiates interface and DUT, creates and runs Environment

`include "mips_transaction.sv"
`include "mips_interface.sv"
`include "mips_generator.sv"
`include "mips_driver.sv"
`include "mips_monitor.sv"
`include "mips_scoreboard.sv"
`include "mips_environment.sv"

module mips_tb_top;

    logic clk;
    initial  clk = 1'b0;
    always #5 clk = ~clk;


    mips_interface mips_if (.clk(clk));
    mips_processor DUT (
        .clk          (mips_if.clk),
        .reset        (mips_if.reset),
        .instruction  (mips_if.instruction),
        .wb_reg_write (mips_if.wb_reg_write),
        .wb_reg_dest  (mips_if.wb_reg_dest),
        .wb_reg_data  (mips_if.wb_reg_data),
        .stall        (mips_if.stall)
    );


    initial begin
        mips_environment env;

        $display("  MIPS RAW HAZARD VERIFICATION TESTBENCH");
        $display("  5-stage pipeline — Stalling only");

        $dumpfile("mips_raw_hazard.vcd");
        $dumpvars(0, mips_tb_top);

        env = new(mips_if);
        env.run();
        env.wrapup();

        $display("[TOP] Simulation complete");
        $finish;
    end

endmodule