// Load/Store Unit (LSU) - Memory Interface Controller
// Handles byte enables, data alignment, and sign/zero extension
// Supports LB, LH, LW, LBU, LHU, SB, SH, SW

module lsu (
    input  [31:0] addr,           // memory address (from ALU: rs1 + imm)
    input  [31:0] write_data,     // data to write (from rs2)
    input         mem_re,         // memory read enable (from control)
    input  [2:0]  mem_width,      // 000=byte, 001=half, 010=word (from control)
    input         mem_sign_ext,   // sign-extend load? (from control)
    input  [31:0] mem_data,       // raw memory read data
    
    output [31:0] load_data,      // extended load result to regfile
    output [3:0]  byte_enable,    // which bytes to write: [byte3 byte2 byte1 byte0]
    output [31:0] store_data      // aligned write data for memory
);

    // Extract aligned byte position from address[1:0]
    wire [1:0] byte_offset = addr[1:0];
    
    // Byte enable generation based on mem_width and alignment
    // (the core forces it to 0000 when the instruction is not a store)
    assign byte_enable = get_byte_enable(mem_width, byte_offset);
    
    function [3:0] get_byte_enable(input [2:0] width, input [1:0] offset);
        case (width)
            3'b000: begin  // byte access
                case (offset)
                    2'b00: get_byte_enable = 4'b0001;
                    2'b01: get_byte_enable = 4'b0010;
                    2'b10: get_byte_enable = 4'b0100;
                    2'b11: get_byte_enable = 4'b1000;
                endcase
            end
            3'b001: begin  // half-word access (2 bytes)
                case (offset[1])  // only check bit[1] for alignment
                    1'b0: get_byte_enable = 4'b0011;   // bytes 0-1
                    1'b1: get_byte_enable = 4'b1100;   // bytes 2-3
                endcase
            end
            3'b010: begin  // word access (4 bytes, always aligned)
                get_byte_enable = 4'b1111;
            end
            default: get_byte_enable = 4'b0000;
        endcase
    endfunction
    
    // Align write data based on byte offset and width
    assign store_data = get_store_data(mem_width, byte_offset, write_data);
    
    function [31:0] get_store_data(input [2:0] width, input [1:0] offset, input [31:0] data);
        case (width)
            3'b000: begin  // byte write
                case (offset)
                    2'b00: get_store_data = {24'b0, data[7:0]};
                    2'b01: get_store_data = {16'b0, data[7:0], 8'b0};
                    2'b10: get_store_data = {8'b0, data[7:0], 16'b0};
                    2'b11: get_store_data = {data[7:0], 24'b0};
                endcase
            end
            3'b001: begin  // half-word write
                case (offset[1])
                    1'b0: get_store_data = {16'b0, data[15:0]};
                    1'b1: get_store_data = {data[15:0], 16'b0};
                endcase
            end
            3'b010:        // word write (no alignment needed)
                get_store_data = data;
            default:
                get_store_data = 32'b0;
        endcase
    endfunction
    
    // Extract and extend load data based on mem_width and sign extension
    assign load_data = get_load_data(mem_width, byte_offset, mem_sign_ext, mem_re, mem_data);
    
    function [31:0] get_load_data(input [2:0] width, input [1:0] offset, 
                                  input sign_ext, input read_en, input [31:0] data);
        if (!read_en) begin
            get_load_data = 32'b0;  // no load active
        end else begin
            case (width)
                3'b000: begin  // byte load
                    case (offset)
                        2'b00: get_load_data = sign_ext ? {{24{data[7]}}, data[7:0]} : {24'b0, data[7:0]};
                        2'b01: get_load_data = sign_ext ? {{24{data[15]}}, data[15:8]} : {24'b0, data[15:8]};
                        2'b10: get_load_data = sign_ext ? {{24{data[23]}}, data[23:16]} : {24'b0, data[23:16]};
                        2'b11: get_load_data = sign_ext ? {{24{data[31]}}, data[31:24]} : {24'b0, data[31:24]};
                    endcase
                end
                3'b001: begin  // half-word load
                    case (offset[1])
                        1'b0: get_load_data = sign_ext ? {{16{data[15]}}, data[15:0]} : {16'b0, data[15:0]};
                        1'b1: get_load_data = sign_ext ? {{16{data[31]}}, data[31:16]} : {16'b0, data[31:16]};
                    endcase
                end
                3'b010: begin  // word load (no extension)
                    get_load_data = data;
                end
                default: get_load_data = 32'b0;
            endcase
        end
    endfunction

endmodule
