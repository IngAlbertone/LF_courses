\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])

   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   //m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   //m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   //m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   //m4_asm(ADD, x14, x13, x14)           // Incremental summation
   //m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   //m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
                   
   //m4_asm(ADDI, x0, x0, 1)//test di registro zero, aggiungiamogli uno
                  
   // Test result value in x14, and set x31 to reflect pass/fail.
   //m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   //m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   //m4_asm_end()
   //m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------

   m4_test_prog()
                   
\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   $reset = *reset;
   
   //Basic PC logic--------------------------------------------------------------------
   
   //Byte addressed memory ma 32b a istruzione, pc incrementa di 4B, se reset torniamo
   //a 0, se branch andiamo alla locazione puntata dal branch
   $next_pc[31:0] = $reset ? 32'd0 : 
                    $taken_br ? $br_tgt_pc :
                    $is_jalr ? $jarl_tgt_pc :
                    $pc + 32'd4 ;
   $pc[31:0] = >>1$next_pc;
   
   //IMEM-------------------------------------------------------------------------------
   
   `READONLY_MEM($pc, $$instr[31:0]) //macro verilog, 
   //NB: $$ per assegnazione segnale, range va specificato
   
   //DECODE logic-----------------------------------------------------------------------
   
   //in teoria se instr[1:0] != 2'b11 allora l'istruzione non è valida, 
   //noi assumiamo che siano tutte vaide
   //mettiamo un booleano per ogni tipo di istruzione possibile
   //$is_u_instr = $instr[6:2] == 5'b00101 || 5'b01101; //lo rifacciamo in sys verilog
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   //se valido l'istruzione è di tipo U
   //lo rifacciamo in sys verilog
   $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                 $instr[6:2] ==? 5'b001x0 ||
                 $instr[6:2] == 5'b11001;
   //se valido l'istruzione è di tipo I
   //$is_s_instr = $instr[6:2] == 5'b01000 || 5'b01000; //lo rifacciamo in sys verilog
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   //se valido l'istruzione è di tipo S
   $is_b_instr = $instr[6:2] == 5'b11000;
   //se valido l'istruzione è di tipo B
   $is_r_instr = $instr[6:2] == 5'b01011 ||
                 $instr[6:2] ==? 5'b011x0 ||
                 $instr[6:2] == 5'b10100;
   //se valido l'istruzione è di tipo R
   $is_j_instr = $instr[6:2] == 5'b11011;
   //se valido l'istruzione è di tipo J
   
   //Decode field logic
   
   $opcode[6:0] = $instr[6:0];
   
   $rs2[4:0] = $instr[24:20]; 
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   
   $rs1[4:0] = $instr[19:15];
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   
   $rd[4:0] = $instr[11:7];
   $rd_valid = ($is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr) && ($rd != 5'd0);
   // non vogliamo mai scrivere nel registro 0 perchè lo vogliamo sempre zero...un modo un po'becero ma funziona
   // magari poi se miglioro il processore tolgo sta cagata
   
   $funct3[2:0] = $instr[14:12];
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   //questo field non lo usiamo nel programma base ma lo tiro fuori comunque
   $funct7[6:0] = $instr[31:25];
   $funct7_valid = $is_r_instr;
   
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   //questo immediato segue una tabella specifica
   $imm[31:0] = $is_i_instr ? {  {21{$instr[31]}},  $instr[30:25], $instr[24:20] } :
                $is_s_instr ? {  {21{$instr[31]}},  $instr[30:25], $instr[11:7] } :
                $is_b_instr ? {  {20{$instr[31]}},  $instr[7], $instr[30:25], $instr[11:8], 1'b0} :
                $is_u_instr ? {  $instr[31], $instr[30:20], $instr[19:12], 12'd0} :
                $is_j_instr ? {  {12{$instr[31]}},  $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0} :
                32'b0;  // Default
   
      
   //Decode logic instruction decode
   
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode}; //bit di decodifica istruzione
   //ogni bool ti dice se è l'operazione selezionata
   //branches
   $is_beq = $dec_bits ==? 11'bx_000_1100011; 
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   //add
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   //
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   //
   $is_slti = $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   //loads, tutte
   $is_load = $dec_bits ==? 11'bx_xxx_0000011;
   //
   $is_sub = $dec_bits ==? 11'b1_000_0110011;
   $is_sll = $dec_bits ==? 11'b0_001_0110011;
   $is_slt = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011;
   $is_xor = $dec_bits ==? 11'b0_100_0110011;
   $is_srl = $dec_bits ==? 11'b0_101_0110011;
   $is_sra = $dec_bits ==? 11'b1_101_0110011;
   $is_or = $dec_bits ==? 11'b0_110_0110011;
   $is_and = $dec_bits ==? 11'b0_111_0110011;
   
   //DESIGN ALU LOGIC------------------------------------------------------------------
   
   //per ora implementiamo solo addi e add, NB: la formattazione dell'imm è sign extended, 'ttappò
   /*$result[31:0] = $is_addi ? $src1_value + $imm :
                   $is_add ? $src1_value + $src2_value :
                   32'd0;*/ //ALU V1
   //ALU V2
   $result[31:0] = 
                 //$is_beq ? :
                 //$is_bne ? :
                 //$is_blt ? :
                 //$is_bge ? :
                 //$is_bltu ? :
                 //$is_bgeu ? :
                 $is_s_instr ? $src1_value + $imm :
                 $is_addi ? $src1_value + $imm : //somma immediato
                 $is_add ? $src1_value + $src2_value : 
                 $is_lui ? {$imm[31:12], 12'b0} : //load upper immediate
                 $is_auipc ? $pc + $imm :
                 $is_jal ? $pc + 32'd4 : //nei jump and link ci dobbiamo tenere il pc dove riprendere l'esecuzione
                 $is_jalr ? $pc + 32'd4 : //ch corrisponde al pc attuale più un istruzione, +4 , 32b indirizzati al Byte 
                 $is_slti ? (($src1_value[31] == $imm[31]) ? $sltiu_rslt : 
                           {31'b0, $src1_value[31]} ):
                 $is_sltiu ? $sltiu_rslt :
                 $is_xori ? $src1_value ^ $imm : //xor con imm
                 $is_ori ? $src1_value | $imm : //or bit a bit con imm
                 $is_andi ? $src1_value & $imm : //and bit a bit con immediate
                 $is_slli ? $src1_value << $imm[5:0] : //shift a sinistra di val in imm
                 $is_srli ? $src1_value >> $imm[5:0] : //shift a destra di val di imm
                 $is_srai ? $srai_rslt[31:0] :
                 $is_load  ? $src1_value + $imm : //stiamo returnando l'address della load come result
                 $is_sub ? $src1_value - $src2_value : 
                 $is_sll ? $src1_value << $src2_value[4:0] : //shift sinistro dei 5b del secondo deg
                 $is_slt ? ( ( $src1_value[31] == $src2_value[31] ) ? 
                           $sltu_rslt : 
                           {31'b0, $src1_value[31]} ) : 
                 $is_sltu ? $sltu_rslt :
                 $is_xor ? $src1_value ^ $src2_value :
                 $is_srl ? $src1_value >> $src2_value[4:0] : //shift destro dei 5b del secondo reg
                 $is_sra ? $sra_rslt[31:0] :
                 $is_or ? $src1_value | $src2_value :
                 $is_and ? $src1_value & $src2_value : //and fra due registri
                 32'd0;
                 
   //SLTU e SLTI (set if less then, unsigned e immediate), gli mettiamo un result a parte per semplicità
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value}; //tutti zeri meno la condizione unsigned che può essere zero o uno
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm}; //uguale ma con l'immediate
   
   //SRA e SRAI (shift right, arithmetic)
   //prima estendiamo di segno il valore da shiftare a 64b per prevedere shift massimo
   $sext_src1[63:0] = {{32{$src1_value[31]}}, $src1_value}; //l'estensione del segno è fatta da 32 volte il valore dell'MSb
   // aggregato alla source da 32b
   //ora facciamo il risultato a 64b dello shift, lo lasciamo da troncare al result
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[64:0] = $sext_src1 >> $imm[4:0]; //NB shiftiamo massimo di 32b quindi l'operazione usa solo 5b
   
   
   //DESIGN BRANCH LOGIC---------------------------------------------------------------
   //Branch condition logic
   $taken_br = $is_beq == 1'b1 ? $src1_value == $src2_value : 
               $is_bne == 1'b1 ? $src1_value != $src2_value : 
               $is_blt == 1'b1 ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]): 
               $is_bge == 1'b1 ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) : 
               $is_bltu == 1'b1 ? $src1_value < $src2_value :
               $is_bgeu == 1'b1 ? $src1_value >= $src2_value : 
               $is_jal == 1'b1 ? 1'b1 :
               1'b0;
   //Program counter after branch expression
   $br_tgt_pc[31:0] = $pc + $imm; //basta sommare l'immeditao, lo facciamo solo se l'immediato è valido
   $jarl_tgt_pc[31:0] = $src1_value + $imm; //nel jump and link calcoliamo l'indirizzo di jump
   //----------------------------------------------------------------------------------

   //LOAD : addr = rs1 + imm // rd <= DMem[addr] (where, addr = rs1 + imm)
   //STORE : DMem[addr] <= rs2 (where, addr = rs1 + imm)
   `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $rs2 $rs2_valid $funct3 $funct3_valid $imm_valid $opcode $funct7 $funct7_valid
              $dec_bits $imm )  

   
   // Assert these to end simulation (before the cycle limit).
   //
   
   //*passed = *cyc_cnt > 100;
   m4+tb()
   *failed = 1'b0;
   
   
   //REGISTER FILE LOGIC---------------------------------------------------------------
   //m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rd_en1, $rd_index1[4:0], $rd_data1, $rd_en2, $rd_index2[4:0], $rd_data2)
   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $is_load ? $ld_data[31:0] : $result[31:0], $rs1_valid, $rs1[4:0], $$src1_value[31:0], $rs2_valid, $rs2[4:0], $$src2_value[31:0])
   
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value[31:0], $is_load, $ld_data)
   m4+cpu_viz()
   
   
\SV
   endmodule
