module booth_multiplier(
    output wire [15:0] prod,
    output reg busy,
    input [7:0] mc,   // multiplicand
    input [7:0] mp,   // multiplier
    input clk,
    input start
);

    reg [7:0] A, Q, M;
    reg Q_1;
    reg [3:0] count;
    wire [7:0] sum, difference;

   
    alu adder (sum, A, M, 1'b0);
    alu subtracter (difference, A, ~M, 1'b1);

    always @(posedge clk) begin
        if (start) begin
            A <= 8'b0;
            M <= mc;
            Q <= mp;
            Q_1 <= 1'b0;
            count <= 4'b0;
            busy <= 1'b1;
        end else if (busy) begin
            case ({Q[0], Q_1})
                2'b01 : {A, Q, Q_1} <= {sum[7], sum, Q};        // A = A + M
                2'b10 : {A, Q, Q_1} <= {difference[7], difference, Q}; // A = A - M
                default : {A, Q, Q_1} <= {A[7], A, Q};          // No change, shift
            endcase
            count <= count + 1'b1;
            if (count == 4'd7) busy <= 0;
        end
    end

    assign prod = {A, Q};
endmodule


module alu(out, a, b, cin);
    output [7:0] out;
    input [7:0] a;
    input [7:0] b;
    input cin;
    assign out = a + b + cin;
endmodule

module tb_booth_multiplier;
    reg clk, start;
    reg signed [7:0] mc, mp;  
    wire signed [15:0] prod; 
    wire busy;

    booth_multiplier uut (
        .prod(prod), 
        .busy(busy), 
        .mc(mc), 
        .mp(mp), 
        .clk(clk), 
        .start(start)
    );

    
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
      
        $display("  Booth's Multiplier Testbench");
        $display("Time\tMC\tMP\tProduct\t\tBusy");
        
        //Positive × Positive
        start = 1;
        mc = 8'd4; mp = 8'd7; 
        #10; 
        start = 0;
        wait(busy == 0);
        #10;
        $display("%0t\t%0d\t%0d\t%0d\t\t%b", $time, mc, mp, prod, busy);
        
        //Negative × Positive
        start = 1;
        mc = -8'd5; mp = 8'd10; 
        #10; 
        start = 0;
        wait(busy == 0);
        #10;
        $display("%0t\t%0d\t%0d\t%0d\t\t%b", $time, mc, mp, prod, busy);
        
        //Negative × Negative
        start = 1;
        mc = -8'd4; mp = -8'd8; 
        #10; 
        start = 0;
        wait(busy == 0);
        #10;
        $display("%0t\t%0d\t%0d\t%0d\t\t%b", $time, mc, mp, prod, busy);
        
        //Positive × Negative
        start = 1;
        mc = 8'd6; mp = -8'd3; 
        #10; 
        start = 0;
        wait(busy == 0);
        #10;
        $display("%0t\t%0d\t%0d\t%0d\t\t%b", $time, mc, mp, prod, busy);
        
        //Zero multiplication
        start = 1;
        mc = 8'd0; mp = 8'd5; 
        #10; 
        start = 0;
        wait(busy == 0);
        #10;
        $display("%0t\t%0d\t%0d\t%0d\t\t%b", $time, mc, mp, prod, busy);
        $display("  All tests completed!");
        $finish;
    end
endmodule
