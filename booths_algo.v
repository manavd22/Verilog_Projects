module booths_multiplier #(
    parameter WIDTH = 8
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,
    input  wire signed [WIDTH-1:0]   multiplicand,
    input  wire signed [WIDTH-1:0]   multiplier,
    output reg  signed [2*WIDTH-1:0] product,
    output reg                       done
);

    reg signed [WIDTH:0]   A;
    reg signed [WIDTH-1:0] M, Q;
    reg                    Q_1;
    reg [3:0]             count;
    reg [1:0]             state;
    reg signed [WIDTH:0]   A_temp;
    
    localparam IDLE = 0, COMPUTE = 1, FINISH = 2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            A <= 0;
            M <= 0;
            Q <= 0;
            Q_1 <= 0;
            count <= 0;
            product <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        M <= multiplicand;
                        Q <= multiplier;
                        A <= 0;
                        Q_1 <= 0;
                        count <= WIDTH;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Booth recoding - add or subtract
                    case ({Q[0], Q_1})
                        2'b01:  A_temp = A + M;
                        2'b10:  A_temp = A - M;
                        default: A_temp = A;
                    endcase
                    
                    // Arithmetic right shift of {A_temp, Q, Q_1}
                    A <= A_temp >>> 1;
                    Q <= {A_temp[0], Q[WIDTH-1:1]};
                    Q_1 <= Q[0];
                    
                    count <= count - 1;
                    if (count == 1)
                        state <= FINISH;
                end
                
                FINISH: begin
                    product <= {A[WIDTH-1:0], Q};
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

`timescale 1ns/1ps

module tb_booths_multiplier;

    parameter WIDTH = 8;
    parameter CLK_PERIOD = 10;

    reg                     clk;
    reg                     rst_n;
    reg                     start;
    reg signed [WIDTH-1:0]  multiplicand;
    reg signed [WIDTH-1:0]  multiplier;
    wire signed [2*WIDTH-1:0] product;
    wire                    done;

    integer pass = 0;
    integer fail = 0;
    reg signed [2*WIDTH-1:0] expected;

    // DUT instantiation
    booths_multiplier #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Waveform dump
    initial begin
        $dumpfile("booths_multiplier.vcd");
        $dumpvars(0, tb_booths_multiplier);
    end

    // Test task
    task test_multiply(input signed [WIDTH-1:0] a, b, input [200*8:1] desc);
        begin
            expected = a * b;
            @(posedge clk);
            multiplicand = a;
            multiplier = b;
            start = 1;
            @(posedge clk);
            start = 0;
            
            wait(done);
            @(posedge clk);
            
            if (product === expected) begin
                $display("[PASS] %s: %0d × %0d = %0d", desc, a, b, product);
                pass = pass + 1;
            end else begin
                $display("[FAIL] %s: %0d × %0d = %0d (expected %0d)", 
                         desc, a, b, product, expected);
                fail = fail + 1;
            end
        end
    endtask

    // Main test
    initial begin
        $display("========================================");
        $display("Booth's Multiplier Testbench (WIDTH=%0d)", WIDTH);
        $display("========================================\n");
        
        // Reset
        rst_n = 0;
        start = 0;
        multiplicand = 0;
        multiplier = 0;
        #50;
        rst_n = 1;
        #20;
        
        // Test cases
        $display("Testing Positive × Positive:");
        test_multiply(5, 3, "5 × 3");
        test_multiply(7, 9, "7 × 9");
        test_multiply(15, 10, "15 × 10");
        
        $display("\nTesting Negative × Positive:");
        test_multiply(-5, 3, "-5 × 3");
        test_multiply(-7, 9, "-7 × 9");
        
        $display("\nTesting Positive × Negative:");
        test_multiply(5, -3, "5 × -3");
        test_multiply(7, -9, "7 × -9");
        
        $display("\nTesting Negative × Negative:");
        test_multiply(-5, -3, "-5 × -3");
        test_multiply(-7, -9, "-7 × -9");
        
        $display("\nTesting Zero:");
        test_multiply(0, 5, "0 × 5");
        test_multiply(10, 0, "10 × 0");
        
        $display("\nTesting Edge Cases:");
        test_multiply(127, 1, "127 × 1 (max positive)");
        test_multiply(-128, 1, "-128 × 1 (max negative)");
        test_multiply(127, 127, "127 × 127");
        test_multiply(-128, -128, "-128 × -128");
        
        // Summary
        #100;
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Passed: %0d", pass);
        $display("  Failed: %0d", fail);
        $display("  Total:  %0d", pass + fail);
        $display("========================================");
        
        if (fail == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** SOME TESTS FAILED ***\n");
        
        $finish;
    end

    // Timeout
    initial begin
        #50000;
        $display("\nERROR: Timeout!");
        $finish;
    end

endmodule