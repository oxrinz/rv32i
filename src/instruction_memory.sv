module instruction_memory (
    input wire [31:0] addr,
    output reg [31:0] instr_out
);
    reg [31:0] memory[0:1023];
    
    `ifndef SYNTHESIS
    // SIMULATION CODE - will be used with iverilog
    integer i;
    integer file;
    integer status;
    reg continue_reading;
    
    initial begin
        // Initialize memory with zeros
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] = 32'h0;
        end
        
        // Load program from binary file
        file = $fopen("program", "rb");
        if (file == 0) begin
            $display("Error: Failed to open file");
            $finish;
        end
        
        i = 0;
        continue_reading = 1;
        while (continue_reading && i < 1024) begin
            status = $fgetc(file);
            if (status != -1) begin
                memory[i][31:24] = status;
                status = $fgetc(file);
                if (status != -1) begin
                    memory[i][23:16] = status;
                    status = $fgetc(file);
                    if (status != -1) begin
                        memory[i][15:8] = status;
                        status = $fgetc(file);
                        if (status != -1) begin
                            memory[i][7:0] = status;
                        end else begin
                            memory[i][7:0] = 8'h00;
                            continue_reading = 0;
                        end
                    end else begin
                        memory[i][15:0] = 16'h0000;
                        continue_reading = 0;
                    end
                end else begin
                    memory[i][23:0] = 24'h000000;
                    continue_reading = 0;
                end
                i = i + 1;
            end else begin
                continue_reading = 0;
            end
        end
        $fclose(file);
        
        `ifdef DEBUG
        $display("Loaded %0d 32-bit instructions", i);
        $display("Memory initialization complete");
        `endif
    end
    `else
    // SYNTHESIS CODE - will be used with Yosys
    initial begin
        // For synthesis, either leave memory uninitialized (RAM will be inferred)
        // or provide a few default instructions if needed
        memory[0] = 32'h00000013; // NOP (addi x0, x0, 0)
        // Add more initialization if needed
    end
    `endif
    
    always @(*) begin
        instr_out = memory[addr];
    end
endmodule