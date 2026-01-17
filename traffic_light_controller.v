`timescale 1ns / 1ps

module traffic_light_controller #(
    parameter GREEN_TIME  = 30,  // Green light duration in clock cycles
    parameter YELLOW_TIME = 5,   // Yellow light duration in clock cycles
    parameter RED_TIME    = 35,  // Red light duration in clock cycles
    parameter PED_TIME    = 20   // Pedestrian crossing duration
)(
    input  wire        clk,              // System clock
    input  wire        rst_n,            // Active-low reset
    input  wire        enable,           // Controller enable
    input  wire        emergency,        // Emergency vehicle override
    input  wire        ped_req_ns,       // Pedestrian request North-South
    input  wire        ped_req_ew,       // Pedestrian request East-West
    
    // North-South traffic lights
    output reg         ns_red,
    output reg         ns_yellow,
    output reg         ns_green,
    
    // East-West traffic lights
    output reg         ew_red,
    output reg         ew_yellow,
    output reg         ew_green,
    
    // Pedestrian signals
    output reg         ped_walk_ns,      // North-South pedestrian walk signal
    output reg         ped_walk_ew,      // East-West pedestrian walk signal
    
    // Status outputs
    output reg  [2:0]  current_state,    // Current state for monitoring
    output reg  [7:0]  timer             // Timer value for debugging
);

    // State encoding
    localparam [2:0] IDLE         = 3'b000,
                     NS_GREEN     = 3'b001,
                     NS_YELLOW    = 3'b010,
                     EW_GREEN     = 3'b011,
                     EW_YELLOW    = 3'b100,
                     PED_NS       = 3'b101,
                     PED_EW       = 3'b110,
                     EMERGENCY    = 3'b111;

    // Internal registers
    reg [2:0]  next_state;
    reg [7:0]  timer_next;
    reg        ped_req_ns_reg;
    reg        ped_req_ew_reg;
    
    //==========================================================================
    // Sequential Logic: State Register
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            timer         <= 8'b0;
            ped_req_ns_reg <= 1'b0;
            ped_req_ew_reg <= 1'b0;
        end else if (enable) begin
            current_state <= next_state;
            timer         <= timer_next;
            
            // Latch pedestrian requests
            if (ped_req_ns)
                ped_req_ns_reg <= 1'b1;
            if (ped_req_ew)
                ped_req_ew_reg <= 1'b1;
        end
    end

    //==========================================================================
    // Combinational Logic: Next State and Timer Logic
    //==========================================================================
    always @(*) begin
        // Default assignments
        next_state = current_state;
        timer_next = timer;
        
        // Emergency override - highest priority
        if (emergency) begin
            next_state = EMERGENCY;
            timer_next = 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    next_state = NS_GREEN;
                    timer_next = GREEN_TIME;
                end
                
                NS_GREEN: begin
                    if (timer == 8'b0) begin
                        next_state = NS_YELLOW;
                        timer_next = YELLOW_TIME;
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                NS_YELLOW: begin
                    if (timer == 8'b0) begin
                        // Check for pedestrian request
                        if (ped_req_ns_reg) begin
                            next_state = PED_NS;
                            timer_next = PED_TIME;
                        end else begin
                            next_state = EW_GREEN;
                            timer_next = GREEN_TIME;
                        end
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                PED_NS: begin
                    if (timer == 8'b0) begin
                        next_state = EW_GREEN;
                        timer_next = GREEN_TIME;
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                EW_GREEN: begin
                    if (timer == 8'b0) begin
                        next_state = EW_YELLOW;
                        timer_next = YELLOW_TIME;
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                EW_YELLOW: begin
                    if (timer == 8'b0) begin
                        // Check for pedestrian request
                        if (ped_req_ew_reg) begin
                            next_state = PED_EW;
                            timer_next = PED_TIME;
                        end else begin
                            next_state = NS_GREEN;
                            timer_next = GREEN_TIME;
                        end
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                PED_EW: begin
                    if (timer == 8'b0) begin
                        next_state = NS_GREEN;
                        timer_next = GREEN_TIME;
                    end else begin
                        timer_next = timer - 1'b1;
                    end
                end
                
                EMERGENCY: begin
                    if (!emergency) begin
                        next_state = NS_GREEN;
                        timer_next = GREEN_TIME;
                    end else begin
                        timer_next = 8'b0;
                    end
                end
                
                default: begin
                    next_state = IDLE;
                    timer_next = 8'b0;
                end
            endcase
        end
    end

    //==========================================================================
    // Output Logic: Traffic Light Control
    //==========================================================================
    always @(*) begin
        // Default all lights off
        ns_red    = 1'b0;
        ns_yellow = 1'b0;
        ns_green  = 1'b0;
        ew_red    = 1'b0;
        ew_yellow = 1'b0;
        ew_green  = 1'b0;
        ped_walk_ns = 1'b0;
        ped_walk_ew = 1'b0;
        
        case (current_state)
            IDLE: begin
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
            
            NS_GREEN: begin
                ns_green = 1'b1;
                ew_red   = 1'b1;
            end
            
            NS_YELLOW: begin
                ns_yellow = 1'b1;
                ew_red    = 1'b1;
            end
            
            PED_NS: begin
                ns_red      = 1'b1;
                ew_red      = 1'b1;
                ped_walk_ns = 1'b1;
            end
            
            EW_GREEN: begin
                ns_red   = 1'b1;
                ew_green = 1'b1;
            end
            
            EW_YELLOW: begin
                ns_red    = 1'b1;
                ew_yellow = 1'b1;
            end
            
            PED_EW: begin
                ns_red      = 1'b1;
                ew_red      = 1'b1;
                ped_walk_ew = 1'b1;
            end
            
            EMERGENCY: begin
                // All red for emergency vehicle
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
            
            default: begin
                ns_red = 1'b1;
                ew_red = 1'b1;
            end
        endcase
    end

    //==========================================================================
    // Clear pedestrian requests when serviced
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ped_req_ns_reg <= 1'b0;
            ped_req_ew_reg <= 1'b0;
        end else if (enable) begin
            if (current_state == PED_NS && timer == 8'b0)
                ped_req_ns_reg <= 1'b0;
            if (current_state == PED_EW && timer == 8'b0)
                ped_req_ew_reg <= 1'b0;
        end
    end

endmodule

module tb_traffic_light_controller;

    // Parameters
    parameter CLK_PERIOD = 10;  // 10ns clock period (100 MHz)
    parameter GREEN_TIME  = 30;
    parameter YELLOW_TIME = 5;
    parameter RED_TIME    = 35;
    parameter PED_TIME    = 20;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    reg         enable;
    reg         emergency;
    reg         ped_req_ns;
    reg         ped_req_ew;
    
    wire        ns_red;
    wire        ns_yellow;
    wire        ns_green;
    wire        ew_red;
    wire        ew_yellow;
    wire        ew_green;
    wire        ped_walk_ns;
    wire        ped_walk_ew;
    wire [2:0]  current_state;
    wire [7:0]  timer;

    // Test statistics
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Variables for testing
    reg [2:0] saved_state;

    // State names for display
    reg [87:0] state_name;
    always @(*) begin
        case (current_state)
            3'b000: state_name = "IDLE     ";
            3'b001: state_name = "NS_GREEN ";
            3'b010: state_name = "NS_YELLOW";
            3'b011: state_name = "EW_GREEN ";
            3'b100: state_name = "EW_YELLOW";
            3'b101: state_name = "PED_NS   ";
            3'b110: state_name = "PED_EW   ";
            3'b111: state_name = "EMERGENCY";
            default: state_name = "UNKNOWN  ";
        endcase
    end

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    traffic_light_controller #(
        .GREEN_TIME(GREEN_TIME),
        .YELLOW_TIME(YELLOW_TIME),
        .RED_TIME(RED_TIME),
        .PED_TIME(PED_TIME)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .emergency(emergency),
        .ped_req_ns(ped_req_ns),
        .ped_req_ew(ped_req_ew),
        .ns_red(ns_red),
        .ns_yellow(ns_yellow),
        .ns_green(ns_green),
        .ew_red(ew_red),
        .ew_yellow(ew_yellow),
        .ew_green(ew_green),
        .ped_walk_ns(ped_walk_ns),
        .ped_walk_ew(ped_walk_ew),
        .current_state(current_state),
        .timer(timer)
    );

    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("traffic_light_controller.vcd");
        $dumpvars(0, tb_traffic_light_controller);
    end

    //==========================================================================
    // Monitor
    //==========================================================================
    initial begin
        $monitor("Time=%0t | State=%s | Timer=%0d | NS(R=%b,Y=%b,G=%b) | EW(R=%b,Y=%b,G=%b) | PED(NS=%b,EW=%b)",
                 $time, state_name, timer, ns_red, ns_yellow, ns_green,
                 ew_red, ew_yellow, ew_green, ped_walk_ns, ped_walk_ew);
    end

    //==========================================================================
    // Test Tasks
    //==========================================================================
    task reset_system;
        begin
            rst_n = 0;
            enable = 0;
            emergency = 0;
            ped_req_ns = 0;
            ped_req_ew = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    task wait_state;
        input [2:0] expected_state;
        begin
            wait(current_state == expected_state);
            @(posedge clk);
        end
    endtask

    task check_lights;
        input r_ns, y_ns, g_ns, r_ew, y_ew, g_ew;
        input [255:0] test_desc;
        begin
            test_count = test_count + 1;
            if (ns_red === r_ns && ns_yellow === y_ns && ns_green === g_ns &&
                ew_red === r_ew && ew_yellow === y_ew && ew_green === g_ew) begin
                $display("[PASS] Test %0d: %s", test_count, test_desc);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_count, test_desc);
                $display("       Expected: NS(R=%b,Y=%b,G=%b) EW(R=%b,Y=%b,G=%b)",
                         r_ns, y_ns, g_ns, r_ew, y_ew, g_ew);
                $display("       Got:      NS(R=%b,Y=%b,G=%b) EW(R=%b,Y=%b,G=%b)",
                         ns_red, ns_yellow, ns_green, ew_red, ew_yellow, ew_green);
                fail_count = fail_count + 1;
            end
        end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("========================================");
        $display("Traffic Light Controller Testbench");
        $display("========================================");
        
        //----------------------------------------------------------------------
        // Test 1: Reset Test
        //----------------------------------------------------------------------
        $display("\n[TEST 1] Reset Functionality");
        reset_system();
        check_lights(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "Reset - All Red");
        
        //----------------------------------------------------------------------
        // Test 2: Normal Operation - Full Cycle
        //----------------------------------------------------------------------
        $display("\n[TEST 2] Normal Operation - Full Cycle");
        enable = 1;
        @(posedge clk);
        
        // Wait for NS_GREEN state
        wait_state(3'b001);
        check_lights(1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, "NS Green, EW Red");
        
        // Wait for timer to expire and move to NS_YELLOW
        repeat(GREEN_TIME + 1) @(posedge clk);
        check_lights(1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "NS Yellow, EW Red");
        
        // Wait for EW_GREEN
        repeat(YELLOW_TIME + 1) @(posedge clk);
        check_lights(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, "NS Red, EW Green");
        
        // Wait for EW_YELLOW
        repeat(GREEN_TIME + 1) @(posedge clk);
        check_lights(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, "NS Red, EW Yellow");
        
        //----------------------------------------------------------------------
        // Test 3: Pedestrian Request - North-South
        //----------------------------------------------------------------------
        $display("\n[TEST 3] Pedestrian Request - North-South");
        reset_system();
        enable = 1;
        @(posedge clk);
        
        // Assert pedestrian request during NS_GREEN
        wait_state(3'b001);
        ped_req_ns = 1;
        @(posedge clk);
        ped_req_ns = 0;
        
        // Wait through NS_YELLOW to PED_NS
        repeat(GREEN_TIME + YELLOW_TIME + 2) @(posedge clk);
        
        if (current_state == 3'b101) begin
            check_lights(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "Pedestrian NS - Both Red");
            test_count = test_count + 1;
            if (ped_walk_ns === 1'b1) begin
                $display("[PASS] Test %0d: Pedestrian Walk Signal NS Active", test_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Pedestrian Walk Signal NS Not Active", test_count);
                fail_count = fail_count + 1;
            end
        end
        
        //----------------------------------------------------------------------
        // Test 4: Pedestrian Request - East-West
        //----------------------------------------------------------------------
        $display("\n[TEST 4] Pedestrian Request - East-West");
        
        // Wait for EW_GREEN and assert pedestrian request
        wait_state(3'b011);
        ped_req_ew = 1;
        @(posedge clk);
        ped_req_ew = 0;
        
        // Wait through EW_YELLOW to PED_EW
        repeat(GREEN_TIME + YELLOW_TIME + 2) @(posedge clk);
        
        if (current_state == 3'b110) begin
            check_lights(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "Pedestrian EW - Both Red");
            test_count = test_count + 1;
            if (ped_walk_ew === 1'b1) begin
                $display("[PASS] Test %0d: Pedestrian Walk Signal EW Active", test_count);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: Pedestrian Walk Signal EW Not Active", test_count);
                fail_count = fail_count + 1;
            end
        end
        
        //----------------------------------------------------------------------
        // Test 5: Emergency Override
        //----------------------------------------------------------------------
        $display("\n[TEST 5] Emergency Override");
        reset_system();
        enable = 1;
        repeat(5) @(posedge clk);
        
        // Assert emergency during normal operation
        emergency = 1;
        @(posedge clk);
        check_lights(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "Emergency - All Red");
        
        test_count = test_count + 1;
        if (current_state == 3'b111) begin
            $display("[PASS] Test %0d: Emergency State Entered", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Emergency State Not Entered", test_count);
            fail_count = fail_count + 1;
        end
        
        // Hold emergency for several cycles
        repeat(10) @(posedge clk);
        check_lights(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "Emergency Hold - All Red");
        
        // Release emergency
        emergency = 0;
        repeat(2) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 6: Enable Signal Control
        //----------------------------------------------------------------------
        $display("\n[TEST 6] Enable Signal Control");
        reset_system();
        enable = 1;
        repeat(10) @(posedge clk);
        
        // Capture current state
        saved_state = current_state;
        
        // Disable controller
        enable = 0;
        repeat(10) @(posedge clk);
        
        test_count = test_count + 1;
        if (current_state == saved_state) begin
            $display("[PASS] Test %0d: Controller Freezes When Disabled", test_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Controller Changed State When Disabled", test_count);
            fail_count = fail_count + 1;
        end
        
        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        repeat(10) @(posedge clk);
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("Pass Rate:   %0d%%", (pass_count * 100) / test_count);
        $display("========================================\n");
        
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***\n");
        else
            $display("*** SOME TESTS FAILED ***\n");
        
        $finish;
    end

    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #100000;  // 100 microseconds timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule