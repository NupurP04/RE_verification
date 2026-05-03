
// Creates all components
// Creates mailboxes
// Connects everything together
// Runs all components in parallel
class mips_environment;

    // COMPONENTS
    mips_generator      gen;
    mips_driver         drv;
    mips_monitor        mon;
    mips_scoreboard     scbd;

    // MAILBOXES
    mailbox     gen2drv;
    mailbox     gen2scbd;
    mailbox     mon2scbd;

    virtual mips_interface  vif;
    // CONSTRUCTOR
    function new(virtual mips_interface vif);
        this.vif = vif;

        // Create mailboxes
        gen2drv  = new();
        gen2scbd = new();
        mon2scbd = new();

        $display("[ENV] Mailboxes created");

        // Create components
        gen  = new(gen2drv, gen2scbd);
        drv  = new(vif, gen2drv);
        mon  = new(vif, mon2scbd);
        scbd = new(gen2scbd, mon2scbd);

        $display("[ENV] Components created");
    endfunction

    // RUN TASK
    task run();
    $display("\n[ENV] Starting all components\n");

    $display("[ENV] Generator started");
    gen.run();
    $display("[ENV] Generator finished — all instructions queued");

    fork
        // Driver, Monitor, Scoreboard - run in parallel
        begin
            $display("[ENV] Driver started");
            drv.run();
        end

        begin
            $display("[ENV] Monitor started");
            mon.run();
        end

        begin
            $display("[ENV] Scoreboard started");
            scbd.run();
        end

        begin
            $display("[ENV] Watchdog started");
            #30000ns;   // plenty of time for pipeline + stalls //initially I was getting error for 1000ns simulation was ending in vivado so I added this 
            $display("[ENV] Watchdog timeout reached");
        end
    join_any

    disable fork;

    $display("\n[ENV] All threads stopped\n");
endtask

    task wrapup();
        $display("[ENV] Collecting final results...\n");
        mon.wrapup();
        scbd.wrapup();
    endtask

endclass