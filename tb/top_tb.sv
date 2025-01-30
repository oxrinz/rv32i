module top_tb;

    reg clk;
    wire [31:0] pc_out;
    wire [31:0] instr;
    
    top dut (
        .clk(clk)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
        
        #15;
        
        #50;
        
        $display("Simulation completed successfully");
        $finish;
    end
    
    always @(posedge clk) begin
        $display("Time=%0t pc=%h instr=%h", 
                 $time, dut.pc_out, dut.instr);
    end
    
    initial begin
        #1;
        assert(dut.rst === 1'b1) 
        else $error("Reset not active at start");
        
        #11;
        assert(dut.rst === 1'b0) 
        else $error("Reset not deasserted after 10 time units");

        assert(dut.alu_ops === 4'b0000)
        else $error("alu_ops not 0000 for ADD");
        
        @(posedge clk);
        if (dut.pc_out !== 32'h0)
            $error("PC not reset to 0");
            
        @(posedge clk);
        if (dut.pc_out !== 32'h1)
            $error("PC not incrementing");
    end

endmodule