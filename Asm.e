-- asm.e
-- Assembly to machine code translator for Euphoria
-- by Pete Eberlein <xseal@harborside.com>

global constant asm_version = "Mar 2, 2000"

-- WARNING:  This compiler may not encode all instructions correctly.
--   *** USE AT YOUR OWN RISK! ***
-- I will not be held responsible for any damage caused by the use of this file.

--------------------------<get_asm>------------------------------------------
--  Syntax:      a = get_asm(text)
--  Description: Translates assembly language text into a sequence of
--               machine language bytecodes, allocates the memory required,
--               pokes in the bytecodes and returns the address in a.
--  Comments:    a should be an atom because it will hold a memory address.
--               You must deallocate this pointer yourself using free(a).
--               If you're totally clueless, you can execute it with call(a).
--------------------------<get_label>----------------------------------------
--  Syntax:      i = get_label(text)
--  Description: Returns the offset into a machine code sequence for the
--               label text, or -1 if no such label exists.
--------------------------<get_param>----------------------------------------
--  Syntax:      i = get_param(text)
--  Description: Returns the offset into a machine code sequence for the
--               parameter text, or -1 if no such parameter exists.
--  Comments:    No indication of parameter length is given.  Returns only 
--               the last parameter if there are more than one.
--------------------------<get_asm>------------------------------------------
--  Syntax:      a = include_asm(filename)
--  Description: This reads an asm function from a file and translates the 
--               text into machine language using get_asm.
--  Comments:    a should be treated the same as with get_asm
--------------------------<asm_output>----------------------------------------
--  Syntax:      asm_output(output_file, style)       
--  Description: Sets up the file for output when get_asm is called.  style
--               determines how the output is formatted.  output_file may be
--               a sequence naming the file or an atom of a file already opened.
--  Comments:    Allowed styles are:
--               1 - machine codes with commented source and line numbers
--               2 - machine codes with commented source only
--               3 - machine codes only, no commented source
--------------------------<resolve_param>-------------------------------------
--  Syntax:      resolve_param(parameter, data)
--  Description: Replaces all occurences of parameter in memory with data.
--  Comments:    data is sized to fit into each parameter.  A warning will
--               be displayed if the parameter is not found.
-----------------------------------------------------------------------------


include machine.e

sequence 
    instruction_prefix,
    address_size_prefix,
    operand_size_prefix,
    segment_override,
    opcode,
    modrm,  --modrm becomes part of opcode
    sib,
    displacement,
    immediate,
    suffix

integer operand_size, address_size, immediate_label, displacement_label
sequence label_names

constant
    -- these must be in this order
    BYTE = power(2,8),    -- 1 byte
    WORD = power(2,9),    -- 2 bytes
    DWORD = power(2,10),  -- 4 bytes
    QWORD = BYTE + WORD,  -- 8 bytes (FPU,MMX only)
    TBYTE = WORD + DWORD -- 10 bytes (FPU only)
    
integer DEFAULT_OPERAND, DEFAULT_ADDRESS

    -- we are assumed to be in protected mode (32-bit)
    DEFAULT_OPERAND = DWORD
    DEFAULT_ADDRESS = DWORD

constant
    REGISTER = power(2,11),
    IMMEDIATE = power(2,12),
    ACCUMULATOR = power(2,13),  
    MODRM = power(2,14),
    SEGMENT = power(2,15),
    PREFIX = power(2,16),
    SUFFIX = PREFIX,
    DIRECTION = power(2,17),  -- adds 2 to opcode if ordered REGISTER, MODRM
    SIGN_EXTEND = power(2,18),  -- adds 3 to opcode if WORD/DWORD and IMMEDIATE BYTE
    CONSTANT_1 = power(2,19),
    CONSTANT_CL = power(2,20),
    CONSTANT_DX = power(2,21),
    REVERSE = power(2,22),  -- reverses the first two parameters
    IMMED = power(2,23),  -- causes operand size to be ignored, only limits immediate
    LABEL = power(2,24),
    CANCEL_SX = power(2,25), -- cancel operand if sign-extension is possible
    STRUC = power(2,26),
    DATA = power(2,27),
    CONSTANT_DISP = power(2,28), --test for a effective address with only displacement
    EXTENSION = power(2,30),    -- tests for a word, dword reg followed by a byte/word mod/rm
    FPU_STACK = REGISTER,
    FPU_MODRM = power(2,27),
    MMX_REG = REGISTER,
    MMX_MODRM_REG = EXTENSION + QWORD,
    CONSTANT_AX = power(2,29),

    SIZE_MASK = BYTE + WORD + DWORD,
    UNION = STRUC + 1,
    END_STRUC = STRUC + 3,
    DUP = STRUC + 4


constant operand_override = {#66},
         address_override = {#67}

                          --  ES: CS: SS: CS: FS: GS:
constant segment_prefixes = {#26,#2E,#36,#3E,#64,#65}

constant keywords = {
    {"AX",      REGISTER + WORD + 0},   {"EAX",     REGISTER + DWORD + 0},
    {"AL",      REGISTER + BYTE + 0},   {"AH",      REGISTER + BYTE + 4},
    {"BX",      REGISTER + WORD + 3},   {"EBX",     REGISTER + DWORD + 3},
    {"BL",      REGISTER + BYTE + 3},   {"BH",      REGISTER + BYTE + 7},
    {"CX",      REGISTER + WORD + 1},   {"ECX",     REGISTER + DWORD + 1},
    {"CL",      REGISTER + BYTE + 1},   {"CH",      REGISTER + BYTE + 5},
    {"DX",      REGISTER + WORD + 2},   {"EDX",     REGISTER + DWORD + 2},
    {"DL",      REGISTER + BYTE + 2},   {"DH",      REGISTER + BYTE + 6},
    {"SP",      REGISTER + WORD + 4},   {"ESP",     REGISTER + DWORD + 4},
    {"BP",      REGISTER + WORD + 5},   {"EBP",     REGISTER + DWORD + 5},
    {"SI",      REGISTER + WORD + 6},   {"ESI",     REGISTER + DWORD + 6},
    {"DI",      REGISTER + WORD + 7},   {"EDI",     REGISTER + DWORD + 7},
    {"ES",      SEGMENT + 0},
    {"CS",      SEGMENT + 1},
    {"SS",      SEGMENT + 2},
    {"DS",      SEGMENT + 3},
    {"FS",      SEGMENT + 4},
    {"GS",      SEGMENT + 5},

    {"BYTE PTR",    MODRM + BYTE},
    {"WORD PTR",    MODRM + WORD},
    {"DWORD PTR",   MODRM + DWORD},
    {"BYTE",    LABEL + BYTE},
    {"WORD",    LABEL + WORD},
    {"DWORD",   LABEL + DWORD},

    {"STRUC",   STRUC},
    {"UNION",   UNION},
    {"ENDS",    END_STRUC},

    {"DB",  DATA + BYTE},
    {"DW",  DATA + WORD},
    {"DD",  DATA + DWORD},
    {"DQ",  DATA + QWORD},
    {"DT",  DATA + TBYTE},
    {"DUP", DUP},

    {"CPUID",   {#0F,#A2}},

    {"ADD",     {#04 + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#00 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #00 + MODRM + IMMEDIATE}},
    {"OR",      {#0C + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#08 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #08 + MODRM + IMMEDIATE}},
    {"ADC",     {#14 + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#10 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #10 + MODRM + IMMEDIATE}},
    {"SBB",     {#1C + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#18 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #18 + MODRM + IMMEDIATE}},
    {"AND",     {#24 + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#20 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #20 + MODRM + IMMEDIATE}},
    {"SUB",     {#2C + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#28 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #28 + MODRM + IMMEDIATE}},
    {"XOR",     {#34 + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#30 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #30 + MODRM + IMMEDIATE}},
    {"CMP",     {#3C + ACCUMULATOR + IMMEDIATE + CANCEL_SX},
                {#38 + DIRECTION, MODRM + REGISTER},
                {#80 + SIGN_EXTEND, #38 + MODRM + IMMEDIATE}},
                                    
    {"INC",     {#40 + REGISTER + DEFAULT_OPERAND},
                {#FE, #00 + MODRM}},
    {"DEC",     {#48 + REGISTER + DEFAULT_OPERAND},
                {#FE, #08 + MODRM}},

    {"PUSH",    {#50 + REGISTER + DEFAULT_OPERAND},
                {#6A + IMMEDIATE + BYTE},
                {#68 + IMMEDIATE + DEFAULT_OPERAND},
                {#FE, #30 + MODRM + WORD + DWORD},
                {#06 + SEGMENT}},
    {"POP",     {#58 + REGISTER + DEFAULT_OPERAND},
--                        {#8F, MODRM + DEFAULT_OPERAND}
                {#07 + SEGMENT}},
    {"MOV",     {#B0 + REGISTER + IMMEDIATE + BYTE},
                {#B8 + REGISTER + IMMEDIATE + WORD + DWORD},
                {#A0 + ACCUMULATOR + CONSTANT_DISP + REVERSE + DIRECTION},
                {#88 + DIRECTION, MODRM + REGISTER},
--                {#8C + DIRECTION, MODRM + SEGMENT},
                {#C6, #00 + MODRM + IMMEDIATE}
                },
    {"TEST",    {#84, MODRM + REGISTER},
                {#84, MODRM + REGISTER + REVERSE},
                {#A8 + ACCUMULATOR + IMMEDIATE},
                {#F6, #00 + MODRM + IMMEDIATE}},
    {"XCHG",    {#90 + ACCUMULATOR + REGISTER + WORD + DWORD},
--                {#B4, MODRM + REGISTER}},
                {#86, MODRM + REGISTER}},

    {"LEA",     {#8D-1, MODRM + REGISTER + REVERSE}},
    {"LDS",     {#C5-1, MODRM + REGISTER + REVERSE}},
    {"LES",     {#C4-1, MODRM + REGISTER + REVERSE}},

    {"NOT",     {#F6, #10 + MODRM}},
    {"NEG",     {#F6, #18 + MODRM}},
    {"MUL",     {#F6, #20 + MODRM}},
    {"IMUL",    {#F6, #28 + MODRM}},
    {"DIV",     {#F6, #30 + MODRM}},
    {"IDIV",    {#F6, #38 + MODRM}},

    {"ROL",     {#D0, #00 + MODRM + CONSTANT_1},
                {#D2, #00 + MODRM + CONSTANT_CL},
                {#C0, #00 + MODRM + IMMED + BYTE}},
    {"ROR",     {#D0, #08 + MODRM + CONSTANT_1},
                {#D2, #08 + MODRM + CONSTANT_CL},
                {#C0, #08 + MODRM + IMMED + BYTE}},
    {"RCL",     {#D0, #10 + MODRM + CONSTANT_1},
                {#D2, #10 + MODRM + CONSTANT_CL},
                {#C0, #10 + MODRM + IMMED + BYTE}},
    {"RCR",     {#D0, #18 + MODRM + CONSTANT_1},
                {#D2, #18 + MODRM + CONSTANT_CL},
                {#C0, #18 + MODRM + IMMED + BYTE}},
    {"SHL",     {#D0, #20 + MODRM + CONSTANT_1},
                {#D2, #20 + MODRM + CONSTANT_CL},
                {#C0, #20 + MODRM + IMMED + BYTE}},
    {"SAL",     {#D0, #20 + MODRM + CONSTANT_1},
                {#D2, #20 + MODRM + CONSTANT_CL},
                {#C0, #20 + MODRM + IMMED + BYTE}},
    {"SHR",     {#D0, #28 + MODRM + CONSTANT_1},
                {#D2, #28 + MODRM + CONSTANT_CL},
                {#C0, #28 + MODRM + IMMED + BYTE}},
    {"SAR",     {#D0, #38 + MODRM + CONSTANT_1},
                {#D2, #38 + MODRM + CONSTANT_CL},
                {#C0, #38 + MODRM + IMMED + BYTE}},
    {"SHLD",    {#0F, #A4-1, MODRM + REGISTER + IMMED + BYTE},  -- must use 
                {#0F, #A5-1, MODRM + REGISTER + CONSTANT_CL}},  -- words or
    {"SHRD",    {#0F, #AC-1, MODRM + REGISTER + IMMED + BYTE},  -- dwords
                {#0F, #AD-1, MODRM + REGISTER + CONSTANT_CL}},  -- for SHxD
    
    {"DAA",     {#27}},
    {"DAS",     {#2F}},
    {"AAA",     {#37}},
    {"AAS",     {#3F}},
    {"AAM",     {#D4 + IMMED + BYTE},
                {#D4, #0A}},
    {"AAD",     {#D5 + IMMED + BYTE},
                {#D5, #0A}},

    {"PUSHA",   {#60}}, {"PUSHAD",  {#60 + DWORD}},
    {"POPA",    {#61}}, {"POPAD",   {#61 + DWORD}},
    {"NOP",     {#90}},

    {"CBW",     {#98}},
    {"CWD",     {#99}},
                
    {"WAIT",    {#9B}},
    {"PUSHF",   {#9C}},
    {"POPF",    {#9D}},
    {"SAHF",    {#9E}},
    {"LAHF",    {#9F}},
    
    {"XLAT",    {#D7}}, {"XLATB",   {#D7}},   -- like MOV AL, [EBX + AL]

    {"SEG_ES",  PREFIX + SEGMENT + #26},
    {"SEG_CS",  PREFIX + SEGMENT + #2E},
    {"SEG_SS",  PREFIX + SEGMENT + #36},
    {"SEG_CS",  PREFIX + SEGMENT + #3E},
    {"SEG_FS",  PREFIX + SEGMENT + #64},
    {"SEG_GS",  PREFIX + SEGMENT + #65},
                      
    {"LOCK",    PREFIX + #F0},
    {"REPNE",   PREFIX + #F2},  {"REPNZ",   PREFIX + #F2},
    {"REP",     PREFIX + #F3},  {"REPE",    PREFIX + #F3},  {"REPZ",    PREFIX + #F3},
    
    {"INTO",    {#CE}},
    {"INT3",    {#CC}}, {"INT 3",   {#CC}},
    {"INT",     {#CD + IMMED + BYTE}},
    {"RET",     --{#C2 + IMMED + WORD},
                {#C3}},
    {"RETF",    --{#CA + IMMED + WORD},
                {#CB}},
    {"IRET",    {#CF}},

    {"HLT",     {#F4}},
    {"CMC",     {#F5}}, {"CLC",     {#F8}}, {"STC",     {#F9}},
    {"CLI",     {#FA}}, {"STI",     {#FB}},
    {"CLD",     {#FC}}, {"STD",     {#FD}},

    {"JO NEAR",  {#0F, #80 + LABEL + DEFAULT_OPERAND}},
    {"JNO NEAR", {#0F, #81 + LABEL + DEFAULT_OPERAND}},
    {"JB NEAR",  {#0F, #82 + LABEL + DEFAULT_OPERAND}},  {"JNAE NEAR",{#0F, #82 + LABEL + DEFAULT_OPERAND}},
    {"JNB NEAR", {#0F, #83 + LABEL + DEFAULT_OPERAND}},  {"JAE NEAR", {#0F, #83 + LABEL + DEFAULT_OPERAND}},
    {"JZ NEAR",  {#0F, #84 + LABEL + DEFAULT_OPERAND}},  {"JE NEAR",  {#0F, #84 + LABEL + DEFAULT_OPERAND}},
    {"JNZ NEAR", {#0F, #85 + LABEL + DEFAULT_OPERAND}},  {"JNE NEAR", {#0F, #85 + LABEL + DEFAULT_OPERAND}},
    {"JBE NEAR", {#0F, #86 + LABEL + DEFAULT_OPERAND}},  {"JNA NEAR", {#0F, #86 + LABEL + DEFAULT_OPERAND}},
    {"JNBE NEAR",{#0F, #87 + LABEL + DEFAULT_OPERAND}},  {"JA NEAR",  {#0F, #87 + LABEL + DEFAULT_OPERAND}},
    {"JS NEAR",  {#0F, #88 + LABEL + DEFAULT_OPERAND}},  
    {"JNS NEAR", {#0F, #89 + LABEL + DEFAULT_OPERAND}},
    {"JP NEAR",  {#0F, #8A + LABEL + DEFAULT_OPERAND}},  {"JPE NEAR", {#0F, #8A + LABEL + DEFAULT_OPERAND}},
    {"JNP NEAR", {#0F, #8B + LABEL + DEFAULT_OPERAND}},  {"JPO NEAR", {#0F, #8B + LABEL + DEFAULT_OPERAND}},
    {"JL NEAR",  {#0F, #8C + LABEL + DEFAULT_OPERAND}},  {"JNGE NEAR",{#0F, #8C + LABEL + DEFAULT_OPERAND}},
    {"JNL NEAR", {#0F, #8D + LABEL + DEFAULT_OPERAND}},  {"JGE NEAR", {#0F, #8D + LABEL + DEFAULT_OPERAND}},
    {"JLE NEAR", {#0F, #8E + LABEL + DEFAULT_OPERAND}},  {"JNG NEAR", {#0F, #8E + LABEL + DEFAULT_OPERAND}},
    {"JNLE NEAR",{#0F, #8F + LABEL + DEFAULT_OPERAND}},  {"JG NEAR",  {#0F, #8F + LABEL + DEFAULT_OPERAND}},

    {"JO",      {#70 + LABEL + BYTE}},
    {"JNO",     {#71 + LABEL + BYTE}},
    {"JB",      {#72 + LABEL + BYTE}},  {"JNAE",    {#72 + LABEL + BYTE}},
    {"JNB",     {#73 + LABEL + BYTE}},  {"JAE",     {#73 + LABEL + BYTE}},
    {"JZ",      {#74 + LABEL + BYTE}},  {"JE",      {#74 + LABEL + BYTE}},
    {"JNZ",     {#75 + LABEL + BYTE}},  {"JNE",     {#75 + LABEL + BYTE}},
    {"JBE",     {#76 + LABEL + BYTE}},  {"JNA",     {#76 + LABEL + BYTE}},
    {"JNBE",    {#77 + LABEL + BYTE}},  {"JA",      {#77 + LABEL + BYTE}},
    {"JS",      {#78 + LABEL + BYTE}},  
    {"JNS",     {#79 + LABEL + BYTE}},
    {"JP",      {#7A + LABEL + BYTE}},  {"JPE",     {#7A + LABEL + BYTE}},
    {"JNP",     {#7B + LABEL + BYTE}},  {"JPO",     {#7B + LABEL + BYTE}},
    {"JL",      {#7C + LABEL + BYTE}},  {"JNGE",    {#7C + LABEL + BYTE}},
    {"JNL",     {#7D + LABEL + BYTE}},  {"JGE",     {#7D + LABEL + BYTE}},
    {"JLE",     {#7E + LABEL + BYTE}},  {"JNG",     {#7E + LABEL + BYTE}},
    {"JNLE",    {#7F + LABEL + BYTE}},  {"JG",      {#7F + LABEL + BYTE}},

    {"LOOPNE",  {#E0 + LABEL + BYTE}},  {"LOOPNZ",  {#E0 + LABEL + BYTE}},
    {"LOOPE",   {#E1 + LABEL + BYTE}},  {"LOOPZ",   {#E1 + LABEL + BYTE}},
    {"LOOP",    {#E2 + LABEL + BYTE}},
    {"JCXZ",    {#E3 + LABEL + BYTE}},
    {"JMP SHORT",   {#EB + LABEL + BYTE}},
    {"JMP NEAR",    {#FE, #20 + MODRM + DEFAULT_OPERAND},
                    {#E9 + LABEL + DEFAULT_OPERAND}},
    {"JMP FAR", {#FE, #28 + MODRM}},
    {"JMP",     {#EB + LABEL + BYTE}},
    
    {"CALL NEAR",   {#FE, #10 + MODRM + DEFAULT_OPERAND},
                {#E8 + LABEL + DEFAULT_OPERAND}},

    {"IN",      {#E4 + ACCUMULATOR + IMMED + BYTE},
                {#EC + ACCUMULATOR + CONSTANT_DX}},
    {"OUT",     {#E6 + REVERSE + ACCUMULATOR + IMMED + BYTE},
                {#EE + REVERSE + ACCUMULATOR + CONSTANT_DX}},
    {"INSB",    {#6C + BYTE}},  {"INSW",    {#6D + WORD}},  {"INSD",    {#6D + DWORD}},
    {"OUTSB",   {#6E + BYTE}},  {"OUTSW",   {#6F + WORD}},  {"OUTSD",   {#6F + DWORD}},
    {"MOVSB",   {#A4 + BYTE}},  {"MOVSW",   {#A5 + WORD}},  {"MOVSD",   {#A5 + DWORD}},
    {"CMPSB",   {#A6 + BYTE}},  {"CMPSW",   {#A7 + WORD}},  {"CMPSD",   {#A7 + DWORD}},
    {"STOSB",   {#AA + BYTE}},  {"STOSW",   {#AB + WORD}},  {"STOSD",   {#AB + DWORD}},
    {"LODSB",   {#AC + BYTE}},  {"LODSW",   {#AD + WORD}},  {"LODSD",   {#AD + DWORD}},
    {"SCASB",   {#AE + BYTE}},  {"SCASW",   {#AF + WORD}},  {"SCASD",   {#AF + DWORD}},

    {"MOVSX",  {#0F, #BE, EXTENSION}},
    {"MOVZX",  {#0F, #B6, EXTENSION}},

    {"SETA",   {#0F, #97, MODRM + BYTE}},
    {"SETAE",  {#0F, #93, MODRM + BYTE}},
    {"SETB",   {#0F, #92, MODRM + BYTE}},
    {"SETBE",  {#0F, #96, MODRM + BYTE}},
    {"SETC",   {#0F, #92, MODRM + BYTE}},
    {"SETE",   {#0F, #94, MODRM + BYTE}},
    {"SETG",   {#0F, #9F, MODRM + BYTE}},
    {"SETGE",  {#0F, #9D, MODRM + BYTE}},
    {"SETL",   {#0F, #9C, MODRM + BYTE}},
    {"SETLE",  {#0F, #9E, MODRM + BYTE}},
    {"SETNA",  {#0F, #96, MODRM + BYTE}},
    {"SETNAE", {#0F, #92, MODRM + BYTE}},
    {"SETNB",  {#0F, #93, MODRM + BYTE}},
    {"SETNBE", {#0F, #97, MODRM + BYTE}},
    {"SETNC",  {#0F, #93, MODRM + BYTE}},
    {"SETNE",  {#0F, #95, MODRM + BYTE}},
    {"SETNG",  {#0F, #9E, MODRM + BYTE}},
    {"SETNGE", {#0F, #9C, MODRM + BYTE}},
    {"SETNL",  {#0F, #9D, MODRM + BYTE}},
    {"SETNLE", {#0F, #9F, MODRM + BYTE}},
    {"SETNO",  {#0F, #91, MODRM + BYTE}},
    {"SETNP",  {#0F, #9B, MODRM + BYTE}},
    {"SETNS",  {#0F, #99, MODRM + BYTE}},
    {"SETNZ",  {#0F, #95, MODRM + BYTE}},
    {"SETO",   {#0F, #90, MODRM + BYTE}},
    {"SETP",   {#0F, #9A, MODRM + BYTE}},
    {"SETPE",  {#0F, #9A, MODRM + BYTE}},
    {"SETPO",  {#0F, #9B, MODRM + BYTE}},
    {"SETS",   {#0F, #98, MODRM + BYTE}},
    {"SETZ",   {#0F, #94, MODRM + BYTE}},

-- FPU (8087)
    {"ST(0)",   FPU_STACK + 0},
    {"ST(1)",   FPU_STACK + 1},
    {"ST(2)",   FPU_STACK + 2},
    {"ST(3)",   FPU_STACK + 3},
    {"ST(4)",   FPU_STACK + 4},
    {"ST(5)",   FPU_STACK + 5},
    {"ST(6)",   FPU_STACK + 6},
    {"ST(7)",   FPU_STACK + 7},
    {"ST",      FPU_STACK + 0},
    {"TBYTE PTR",   MODRM + TBYTE},
    {"QWORD PTR",   MODRM + QWORD},

-- Data Transfer
    {"FLD",     {#D9,#C0 + FPU_STACK}, -- Load ST(i) into ST(0)
                {#D9,#00 + FPU_MODRM + DWORD},
                {#DD,#00 + FPU_MODRM + QWORD},
                {#DB,#28 + FPU_MODRM + TBYTE}},
    {"FILD",    {#DB,#00 + FPU_MODRM + DWORD},
                {#DF,#00 + FPU_MODRM + WORD},
                {#DF,#28 + FPU_MODRM + QWORD}},
    {"FBLD",    {#DF,#20 + FPU_MODRM + TBYTE}},
    {"FST",     {#DD,#D0 + FPU_STACK}, -- Store ST(0) to ST(i)
                {#D9,#10 + FPU_MODRM + DWORD},
                {#DD,#10 + FPU_MODRM + QWORD}},
    {"FIST",    {#DB,#10 + FPU_MODRM + DWORD},
                {#DF,#10 + FPU_MODRM + WORD}},
    {"FSTP",    {#DD,#D8 + FPU_STACK}, -- Store and Pop ST(0) to ST(i)
                {#D9,#18 + FPU_MODRM + DWORD},
                {#DD,#18 + FPU_MODRM + QWORD},
                {#DB,#38 + FPU_MODRM + TBYTE}},
    {"FISTP",   {#DB,#18 + FPU_MODRM + DWORD},
                {#DF,#18 + FPU_MODRM + WORD},
                {#DF,#38 + FPU_MODRM + QWORD}},
    {"FBSTP",   {#DF,#30 + FPU_MODRM + TBYTE}},
    {"FXCH",    {#D9,#C8 + FPU_STACK}}, -- Exchange ST(i) and ST(0)
-- Comparison
    {"FCOM",    {#D8,#D0 + FPU_STACK}, -- Compare ST(i) to ST(0)
                {#D8,#10 + FPU_MODRM + DWORD},
                {#DC,#10 + FPU_MODRM + QWORD},
                {#D8,#D1}},
    {"FICOM",   {#DA,#10 + FPU_MODRM + DWORD},
                {#DE,#10 + FPU_MODRM + WORD}},
    {"FCOMP",   {#D8,#D8 + FPU_STACK}, -- Compare and Pop ST(i) to ST(0)
                {#D8,#18 + FPU_MODRM + DWORD},
                {#DC,#18 + FPU_MODRM + QWORD},
                {#D8,#D9}},
    {"FICOMP",  {#DA,#18 + FPU_MODRM + DWORD},
                {#DE,#18 + FPU_MODRM + WORD}},
    {"FCOMPP ST(1)",  {#DE,#D9}}, -- Compare ST(1) to ST(0) and Pop twice
    {"FCOMPP",  {#DE,#D9}}, -- Compare ST(1) to ST(0) and Pop twice
    {"FTST",    {#D9,#E4}}, -- Test ST(0)
    {"FXAM",    {#D9,#E5}}, -- Examine ST(0)
-- Arithmetic
    {"FADD",    {#D8,#00 + FPU_MODRM + DWORD},
                {#DC,#00 + FPU_MODRM + QWORD},
                {#D8,#C0 + ACCUMULATOR + FPU_STACK},
                {#DC,#C0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#C0 + FPU_STACK}},
    {"FADDP",   {#DA,#C0 + ACCUMULATOR + FPU_STACK},
                {#DE,#C0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#C0 + FPU_STACK}},
    {"FIADD",   {#DA,#00 + FPU_MODRM + DWORD},
                {#DE,#00 + FPU_MODRM + WORD}},
    {"FSUB",    {#D8,#20 + FPU_MODRM + DWORD},
                {#DC,#20 + FPU_MODRM + QWORD},
                {#D8,#E0 + ACCUMULATOR + FPU_STACK},
                {#DC,#E0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#E0 + FPU_STACK}},
    {"FSUBP",   {#DA,#E0 + ACCUMULATOR + FPU_STACK},
                {#DE,#E0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#E0 + FPU_STACK}},
    {"FISUB",   {#DA,#20 + FPU_MODRM + DWORD},
                {#DE,#20 + FPU_MODRM + WORD}},
    {"FSUBR",   {#D8,#28 + FPU_MODRM + DWORD},
                {#DC,#28 + FPU_MODRM + QWORD},
                {#D8,#E8 + ACCUMULATOR + FPU_STACK},
                {#DC,#E8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#E8 + FPU_STACK}},
    {"FSUBRP",  {#DA,#E8 + ACCUMULATOR + FPU_STACK},
                {#DE,#E8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#E8 + FPU_STACK}},
    {"FISUBR",  {#DA,#28 + FPU_MODRM + DWORD},
                {#DE,#28 + FPU_MODRM + WORD}},
    {"FMUL",    {#D8,#08 + FPU_MODRM + DWORD},
                {#DC,#08 + FPU_MODRM + QWORD},
                {#D8,#C8 + ACCUMULATOR + FPU_STACK},
                {#DC,#C8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#C8 + FPU_STACK}},
    {"FMULP",   {#DA,#C8 + ACCUMULATOR + FPU_STACK},
                {#DE,#C8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#C8 + FPU_STACK}},
    {"FIMUL",   {#DA,#08 + FPU_MODRM + DWORD},
                {#DE,#08 + FPU_MODRM + WORD}},
    {"FDIV",    {#D8,#30 + FPU_MODRM + DWORD},
                {#DC,#30 + FPU_MODRM + QWORD},
                {#D8,#F0 + ACCUMULATOR + FPU_STACK},
                {#DC,#F0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#F0 + FPU_STACK}},
    {"FDIVP",   {#DA,#F0 + ACCUMULATOR + FPU_STACK},
                {#DE,#F0 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#F0 + FPU_STACK}},
    {"FIDIV",   {#DA,#30 + FPU_MODRM + DWORD},
                {#DE,#30 + FPU_MODRM + WORD}},
    {"FDIVR",   {#D8,#38 + FPU_MODRM + DWORD},
                {#DC,#38 + FPU_MODRM + QWORD},
                {#D8,#F8 + ACCUMULATOR + FPU_STACK},
                {#DC,#F8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#D8,#F8 + FPU_STACK}},
    {"FDIVRP",  {#DA,#F8 + ACCUMULATOR + FPU_STACK},
                {#DE,#F8 + ACCUMULATOR + FPU_STACK + REVERSE},
                {#DA,#F8 + FPU_STACK}},
    {"FIDIVR",  {#DA,#38 + FPU_MODRM + DWORD},
                {#DE,#38 + FPU_MODRM + WORD}},
    {"FSQRT",   {#D9,#FA}}, -- Square Root of ST(0)
    {"FSCALE",  {#D9,#FD}}, -- Scale ST(0) by ST(1)
    {"FPREM",   {#D9,#F8}}, -- Partial Remainder of ST(0) ö ST(1)
    {"FRNDINT", {#D9,#FC}}, -- Round ST(0) to Integer
    {"FXTRACT", {#D9,#F4}}, -- Extract Components of ST(0)
    {"FABS",    {#D9,#E1}}, -- Absolute Value of ST(0)
    {"FCHS",    {#D9,#E0}}, -- Change Sign of ST(0)
-- Transcendental
    {"FPTAN",   {#D9,#F2}}, -- Partial Tangent of ST(0)
    {"FPATAN",  {#D9,#F3}}, -- Partial Arctangent of ST(0) ö ST(1)
    {"F2XM1",   {#D9,#F0}}, -- 2^ST(0) - 1
    {"FYL2X",   {#D9,#F1}}, -- ST(1) ù LOG2[ST(0)]
    {"FYL2XP1", {#D9,#F9}}, -- ST(1) ù LOG2[ST(0)+1]
-- Constants
    {"FLDZ",    {#D9,#EE}}, -- Load + 0.0 into ST(0)
    {"FLD1",    {#D9,#E8}}, -- Load + 1.0 into ST(0)
    {"FLDPI",   {#D9,#EB}}, -- Load ã into ST(0)
    {"FLDL2T",  {#D9,#E9}}, -- Load log2 10 into ST(0)
    {"FLDL2E",  {#D9,#EA}}, -- Load log2 e into ST(0)
    {"FLDLG2",  {#D9,#EC}}, -- Load log10 2 into ST(0)
    {"FLDLN2",  {#D9,#ED}}, -- Load Loge 2 into ST(0)
-- Processor Control
    {"FINIT",   {#DB,#E3}}, -- Initialize NDP
    {"FENI",    {#DB,#E0}}, -- Enable interrupts
    {"FDISI",   {#DB,#E1}}, -- Disable interrupts
    {"FLDCW",   {#D9,#28 + FPU_MODRM}}, -- Load Control Word
    {"FSTCW",   {#D9,#38 + FPU_MODRM}}, -- Store Control Word
    {"FSTSW",   {#DF,#E0 + CONSTANT_AX},-- Store Status Word
                {#DD,#38 + MODRM}}, -- (regs shouldn't be used)
    {"FCLEX",   {#DB,#E2}}, -- Clear Exceptions
    {"FSTENV",  {#D9,#30 + FPU_MODRM}}, -- Store Environment
    {"FLDENV",  {#D9,#20 + FPU_MODRM}}, -- Load Environment
    {"FSAVE",   {#DD,#30 + FPU_MODRM}}, -- Save State
    {"FRSTOR",  {#DD,#20 + FPU_MODRM}}, -- Restore State
    {"FINCSTP", {#D9,#F7}}, -- Increment Stack Pointer
    {"FDECSTP", {#D9,#F6}}, -- Decrement Stack Pointer
    {"FFREE",   {#D9,#C0 + FPU_STACK}}, -- Free ST(i)
    {"FNOP",    {#D9,#D0}}, -- No Operation
    {"FWAIT",   {#9B}}, -- CPU Wait for NDP
-- undocumented (kinda)
    {"FPREM1",  {#D9,#F5}},
    {"FSINCOS", {#D9,#FB}},
    {"FSIN",    {#D9,#FE}},
    {"FCOS",    {#D9,#FF}},
    {"FUCOMPP", {#DA,#E9}},

-- MMX 
    {"MMREG0",   MMX_REG + QWORD + 0},	{"MM0",   MMX_REG + QWORD + 0},
    {"MMREG1",   MMX_REG + QWORD + 1},	{"MM1",   MMX_REG + QWORD + 1},
    {"MMREG2",   MMX_REG + QWORD + 2},	{"MM2",   MMX_REG + QWORD + 2},
    {"MMREG3",   MMX_REG + QWORD + 3},	{"MM3",   MMX_REG + QWORD + 3},
    {"MMREG4",   MMX_REG + QWORD + 4},	{"MM4",   MMX_REG + QWORD + 4},
    {"MMREG5",   MMX_REG + QWORD + 5},	{"MM5",   MMX_REG + QWORD + 5},
    {"MMREG6",   MMX_REG + QWORD + 6},	{"MM6",   MMX_REG + QWORD + 6},
    {"MMREG7",   MMX_REG + QWORD + 7},	{"MM7",   MMX_REG + QWORD + 7},

    {"EMMS",	{#0F,#77}},
    {"MOVD",	{#0F,#6E, EXTENSION + DWORD},
    	    	{#0F,#7E, REVERSE + EXTENSION + DWORD}},
    {"MOVQ",	{#0F,#6F, MMX_MODRM_REG},
    	    	{#0F,#7F, REVERSE + MMX_MODRM_REG}},

    {"PACKSSDW",{#0F,#6B, MMX_MODRM_REG}},
    {"PACKSSWB",{#0F,#63, MMX_MODRM_REG}},
    {"PACKUSWB",{#0F,#67, MMX_MODRM_REG}},
    {"PADDB",   {#0F,#FC, MMX_MODRM_REG}},
    {"PADDD",   {#0F,#FE, MMX_MODRM_REG}},
    {"PADDSB",  {#0F,#EC, MMX_MODRM_REG}},
    {"PADDSW",  {#0F,#ED, MMX_MODRM_REG}},
    {"PADDUSB", {#0F,#DC, MMX_MODRM_REG}},
    {"PADDUSW", {#0F,#DD, MMX_MODRM_REG}},
    {"PADDW",   {#0F,#FD, MMX_MODRM_REG}},
    {"PAND",    {#0F,#DB, MMX_MODRM_REG}},
    {"PANDN",   {#0F,#DF, MMX_MODRM_REG}},
    {"PCMPEQB", {#0F,#74, MMX_MODRM_REG}},
    {"PCMPEQD", {#0F,#76, MMX_MODRM_REG}},
    {"PCMPEQW", {#0F,#75, MMX_MODRM_REG}},
    {"PCMPGTB", {#0F,#64, MMX_MODRM_REG}},
    {"PCMPGTD", {#0F,#66, MMX_MODRM_REG}},
    {"PCMPGTW", {#0F,#65, MMX_MODRM_REG}},
    {"PMADDWD", {#0F,#F5, MMX_MODRM_REG}},
    {"PMULHW",  {#0F,#E5, MMX_MODRM_REG}},
    {"PMULLW",  {#0F,#D5, MMX_MODRM_REG}},
    {"POR",     {#0F,#EB, MMX_MODRM_REG}},
    {"PSLLD",   {#0F,#F2, MMX_MODRM_REG},
		{#0F,#72, #F0 + MMX_REG + IMMED + BYTE}},
    {"PSLLQ",   {#0F,#F3, MMX_MODRM_REG},
		{#0F,#73, #F0 + MMX_REG + IMMED + BYTE}},
    {"PSLLW",   {#0F,#F1, MMX_MODRM_REG},
		{#0F,#71, #F0 + MMX_REG + IMMED + BYTE}},
    {"PSRAD",   {#0F,#E2, MMX_MODRM_REG},
		{#0F,#72, #E0 + MMX_REG + IMMED + BYTE}},
    {"PSRAW",   {#0F,#E1, MMX_MODRM_REG},
		{#0F,#71, #E0 + MMX_REG + IMMED + BYTE}},
    {"PSRLD",   {#0F,#D2, MMX_MODRM_REG},
		{#0F,#72, #D0 + MMX_REG + IMMED + BYTE}},
    {"PSRLQ",   {#0F,#D3, MMX_MODRM_REG},
		{#0F,#73, #D0 + MMX_REG + IMMED + BYTE}},
    {"PSRLW",   {#0F,#D1, MMX_MODRM_REG},
		{#0F,#71, #D0 + MMX_REG + IMMED + BYTE}},
    {"PSUBB",   {#0F,#F8, MMX_MODRM_REG}},
    {"PSUBD",   {#0F,#FA, MMX_MODRM_REG}},
    {"PSUBSB",  {#0F,#E8, MMX_MODRM_REG}},
    {"PSUBSW",  {#0F,#E9, MMX_MODRM_REG}},
    {"PSUBUSB", {#0F,#D8, MMX_MODRM_REG}},
    {"PSUBUSW", {#0F,#D9, MMX_MODRM_REG}},
    {"PSUBW",   {#0F,#F9, MMX_MODRM_REG}},
    {"PUNPCKHBW",{#0F,#68, MMX_MODRM_REG}},
    {"PUNPCKHDQ",{#0F,#6A, MMX_MODRM_REG}},
    {"PUNPCKLBW",{#0F,#60, MMX_MODRM_REG}},
    {"PUNPCKLDQ",{#0F,#62, MMX_MODRM_REG}},
    {"PUNPCKLBW",{#0F,#61, MMX_MODRM_REG}},
    {"PXOR",    {#0F,#EF, MMX_MODRM_REG}},

-- 3DNow!
    {"FEMMS",	{#0F,#0E}},
    {"PAVGUSB", {#0F,#0F, MMX_MODRM_REG, SUFFIX + #BF}},
    {"PFADD",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #9E}},
    {"PFSUB",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #9A}},
    {"PFSUBR",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #AA}},
    {"PFACC",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #AE}},
    {"PFMUL",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #B4}},
    {"PFCMPGE",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #90}},
    {"PFCMPGT",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #A0}},
    {"PFCMPEQ",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #B0}},
    {"PFMIN",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #94}},
    {"PFMAX",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #A4}},
    {"PI2FD",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #0D}},
    {"PF2ID",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #1D}},
    {"PFRCP",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #96}},
    {"PFSQRT",	{#0F,#0F, MMX_MODRM_REG, SUFFIX + #97}},
    {"PFRCPIT1",{#0F,#0F, MMX_MODRM_REG, SUFFIX + #A6}},
    {"PFRSQIT1",{#0F,#0F, MMX_MODRM_REG, SUFFIX + #A7}},
    {"PFRCPIT2",{#0F,#0F, MMX_MODRM_REG, SUFFIX + #B6}},
    {"PFMULHRW",{#0F,#0F, MMX_MODRM_REG, SUFFIX + #B7}},
    {"PREFETCH",{#0F,#0D, #00 + MODRM}},
    {"PREFETCHW",{#0F,#0D, #08 + MODRM}}
    
  }


function upper(object hi)
    return hi + ('A'-'a') * (hi>='a' and hi<='z')
end function

sequence asm_text
integer asm_pos, opstart, error_line
opstart = 1

procedure error(sequence msg)
-- outputs an error message and offending code
    printf(2, "Line %d: "& msg & asm_text[opstart..asm_pos-1] & "\n", error_line)
    abort(1)
end procedure

sequence hash_table
procedure make_hash_table()
    sequence hash, str
    integer hashcode
    hash_table = repeat({}, 26)
    for i = 1 to length(keywords) do
        str = keywords[i][1]
        hashcode = str[1] - 'A' + 1
        hash = hash_table[hashcode]
        if length(str) then
            hash = append(hash, i)
        end if
        hash_table[hashcode] = hash
    end for
end procedure
make_hash_table()


function get_keyword()
-- scans asm_text and returns one of the following:
--  1. an opcode from the table
--  2. an immediate value
--  3. {}, if end of text
--  4. or a label, with optional size specifier (BYTE/WORD/DWORD)
    integer next_char, key_len, c, sign, base, size_spec, hashcode, hv
    sequence hash
    size_spec = 0
    if asm_pos <= length(asm_text) then
        hashcode = upper(asm_text[asm_pos])
    else
        hashcode = 0
    end if
    if hashcode >= 'A' and hashcode <= 'Z' then
        hash = hash_table[hashcode-'A'+1]
--    for i = 1 to length(keywords) do
        for i = 1 to length(hash) do
--        key_len = length(keywords[i][1])
        hv = hash[i]
        key_len = length(keywords[hv][1])
        if asm_pos + key_len - 1 <= length(asm_text) then
            if compare(keywords[hv][1], upper(asm_text[asm_pos..asm_pos-1+key_len])) = 0 then
                if asm_pos + key_len <= length(asm_text) then
                    next_char = upper(asm_text[asm_pos+key_len])
                else
                    next_char = 0
                end if
                if not ((next_char >= '0' and next_char <= '9') 
                     or (next_char >= 'A' and next_char <= 'Z')
                      or next_char  = '_') then
                    asm_pos = asm_pos + key_len
                    if atom(keywords[hv][2]) then
                        if and_bits(keywords[hv][2], LABEL) then
                            size_spec = and_bits(keywords[hv][2], SIZE_MASK)
                            while asm_text[asm_pos] <= ' ' do
                                if asm_text[asm_pos] = '\n' then
                                    error_line = error_line + 1
                                end if
                                asm_pos = asm_pos + 1
                            end while
                            exit -- special case: size specifier
                        end if
                        return keywords[hv][2]
                    else
                        return keywords[hv][2..length(keywords[hv])]
                    end if
                end if
            end if
        end if
        end for
    end if

    if asm_pos > length(asm_text) then 
        return {}  -- not an unknown keyword, just end of text
    end if

        c = asm_text[asm_pos]
        if c = '-' then
            sign = -1
            asm_pos = asm_pos + 1
            c = asm_text[asm_pos]
        else
            sign = 1
        end if
        if c = '#' then -- hexidecimal constant, # form
            asm_pos = asm_pos + 1
            c = upper(asm_text[asm_pos])
            base = 16
        elsif c = '0'   -- hex constant, 0x form
        and upper(asm_text[asm_pos+1]) = 'X' then
            asm_pos = asm_pos + 2
            c = upper(asm_text[asm_pos])
            base = 16
        else
            base = 10
        end if
        if (c >= '0' and c <= '9') or (base = 16 and c >= 'A' and c <= 'F') then
            if length(immediate) then
                return {} -- can't read another immediate
            end if
            immediate = {0,0,0,0}
            while (c >= '0' and c <= '9') or (c >= 'A' and c <= 'F') do
                if (c >= 'A' and c <= 'F') and base = 10 then
                    error("Decimal values must have numerals only: ")
                end if
                immediate = immediate * base
                immediate[1] = immediate[1] + c-'0' + ('0'-'A'+#A) * (c >= 'A' and c <= 'F')
                for x = 1 to 3 do
                    immediate[x+1] = immediate[x+1] + floor(immediate[x] / 256)
                    immediate[x] = remainder(immediate[x], 256)
                end for
                asm_pos = asm_pos + 1
                if asm_pos <= length(asm_text) then
                    c = upper(asm_text[asm_pos])
                else
                    exit
                end if
            end while
            if sign = -1 then
                immediate = 255 - immediate
                immediate[1] = immediate[1] + 1
                for x = 1 to 3 do
                    immediate[x+1] = immediate[x+1] + floor(immediate[x] / 256)
                    immediate[x] = remainder(immediate[x], 256)
                end for
            end if
--            printf(1, "%x %x %x %x\n", immediate)
            return IMMEDIATE + size_spec
        elsif c = '[' then  -- start of mod r/m or sib address
            return MODRM
        end if
        
    -- if nothing else, it must be a code label  (if not, we'll know later)
        label_names = append(label_names, "")
        c = length(label_names)
        while (asm_text[asm_pos] >= '0' and asm_text[asm_pos] <= '9')
           or (asm_text[asm_pos] >= 'A' and asm_text[asm_pos] <= 'Z')
           or (asm_text[asm_pos] >= 'a' and asm_text[asm_pos] <= 'z') 
           or (asm_text[asm_pos]  = '_') or (asm_text[asm_pos] = '@') do
            label_names[c] = append(label_names[c], asm_text[asm_pos])
            asm_pos = asm_pos + 1
            if asm_pos > length(asm_text) then
                exit
            end if
        end while
        return LABEL + c + size_spec
end function

               
procedure no_whitespace()
-- scans past control chars, spaces, and comments
    while asm_pos <= length(asm_text) do
        if asm_text[asm_pos] <= ' ' then -- skip past spaces and control chars
            if asm_text[asm_pos] = '\n' then
                error_line = error_line + 1
            end if
            asm_pos = asm_pos + 1
        elsif asm_text[asm_pos] = ';' then --comment - ignore until cr
            asm_pos = asm_pos + 2
            while asm_text[asm_pos - 1] != '\n' do
                asm_pos = asm_pos + 1
                if asm_pos - 1 > length(asm_text) then
                    return
                end if
            end while
            error_line = error_line + 1
        else
            exit
        end if
    end while
end procedure

function get_data(integer size)
-- to be called after a DATA keyword is recieved
-- returns a sequence of data values
    integer save_pos, dup_count
    sequence datas, temp
    object kw
    dup_count = 1
    datas = {}
    while 1 do
        no_whitespace()
        save_pos = asm_pos
        kw = get_keyword()
        if compare(kw, IMMEDIATE) = 0 then
            datas = append(datas, immediate)
            immediate = {}
            if asm_pos < length(asm_text) then
                asm_pos = asm_pos + (asm_text[asm_pos] = ',')
            end if
        elsif compare(kw, DUP) = 0 then
            if length(datas) != 1 then
                error("Expected only one immediate value before DUP: ")
            end if
            dup_count = dup_count * bytes_to_int(datas[1])
            datas = {}
        else
            asm_pos = save_pos
            exit
        end if
    end while
    temp = {}
    if length(datas) then
        for i = 1 to length(datas) do
            temp = temp & datas[i][1..floor(size / BYTE)]
        end for
        datas = {}
    elsif asm_pos <= length(asm_text) then
        if asm_text[asm_pos] = '?' then
            temp = repeat(0, floor(size / BYTE))
            asm_pos = asm_pos + 1
        end if
    end if
    if length(temp) = 0 then
        error("Expected an immediate value or '?' for data: ")
    end if
    for i = 1 to dup_count do
        datas = datas & temp
    end for
    return datas                    
end function

sequence strucs
strucs = {}
-- { {name, struc_size, {{item_name, size, offset, {initial data}}...}}...}
--  if and_bits(size, STRUC)!=0, then size is ptr to a struc

procedure get_struc(integer union)
-- reads a struc or a union
    object kw
    sequence this_struc, this_item
    integer offset
    no_whitespace()
    kw = get_keyword()
    if compare(and_bits(kw, LABEL), LABEL) then
        error("Invalid struc or union name: ")
    end if
    this_struc = {label_names[kw-LABEL], 0, {}}
    offset = 0
    while 1 do
        no_whitespace()
        kw = get_keyword()
        
        if compare(and_bits(kw, LABEL), LABEL) = 0 then
            this_item = {label_names[kw-LABEL], 0, offset * (union = 0), {}}
            no_whitespace()
            kw = get_keyword()
            if compare(and_bits(kw, DATA), DATA) = 0 then
                this_item[2] = and_bits(kw, SIZE_MASK)
                if this_item[2] = QWORD then this_item[2] = #800
                elsif this_item[2] = TBYTE then this_item[2] = #A00
                end if
                this_item[4] = get_data(this_item[2])
                offset = offset + length(this_item[4])
            elsif compare(and_bits(kw, LABEL), LABEL) = 0 then
                for i = 1 to length(strucs) do
                    if compare(label_names[kw-LABEL], strucs[i][1]) = 0 then -- reference to another struc
                        this_item[2] = STRUC + i
                        for j = 1 to length(strucs[i][3]) do
                            if j = 1 or strucs[i][3][j][3] then
                            -- only the first element is used to initialize a union
                                this_item[4] = this_item[4] & strucs[i][3][j][4]
                            end if
                        end for
                        offset = offset + strucs[i][2]
                        exit
                    end if
                end for
                if this_item[2] = 0 then
                    error("Unknown structure '" & label_names[kw-LABEL] & "': ")
                end if
                no_whitespace()
                asm_pos = asm_pos + (asm_text[asm_pos] = '?')
            end if                        
            this_struc[3] = append(this_struc[3], this_item)
        elsif compare(kw, END_STRUC) = 0 then
            no_whitespace()
            kw = get_keyword()
            if compare(and_bits(kw, LABEL), LABEL) then 
                error("Name mismatch at end of struc: ")
            elsif compare(label_names[kw-LABEL], this_struc[1]) then
                error("Name mismatch at end of struc: ")
            end if
            exit
        else
            error("Label expected for struc member: ")
        end if
    end while
    this_struc[2] = offset
    strucs = append(strucs, this_struc)
end procedure

function is_short(sequence imm4)
    return ((compare(imm4[2..4],{0,0,0})=0) and (imm4[1] < 128))
        or ((compare(imm4[2..4],{#FF,#FF,#FF})=0) and (imm4[1] > 127))
end function

       
function get_effective_address(integer size)
-- gets an effective address (duh)
    sequence save_immediate 
    integer rm, index, scale, base, offset, n
    object kw

    if length(modrm) != 0 then -- already read an effective address
        return {}
    end if
    
    no_whitespace()
    if asm_text[asm_pos] = '[' then
        asm_pos = asm_pos + 1
    else
        error("Expected '[' in effective address: ")
    end if

    save_immediate = immediate
    n = 0
    rm = 0  index = 0  scale = 0  base = 0
    address_size = 0
    displacement = {0,0,0,0}
    modrm = {}
    while 1 do
        no_whitespace()
        if asm_text[asm_pos] = '(' then
            asm_pos = asm_pos + 1
            no_whitespace()
        end if
        if asm_text[asm_pos] = ')' then
            asm_pos = asm_pos + 1
        else
            kw = get_keyword()
        end if
        if compare(and_bits(kw, LABEL), LABEL) = 0
	or asm_text[asm_pos] = '.' then   -- struc reference
            if compare(and_bits(kw, LABEL), LABEL) = 0 then
                n = 0
                for i = 1 to length(strucs) do
                    if compare(label_names[kw-LABEL], strucs[i][1]) = 0 then
                        n = i
--                        label_name = ""
                        exit
                    end if
                end for
                if n = 0 then
                    displacement_label = kw - LABEL
                    kw = IMMEDIATE
                    immediate = {0,0,0,0}
                end if
            end if
            if asm_text[asm_pos] = '.' then
                offset = 0
                while n do
                    asm_pos = asm_pos + (asm_text[asm_pos] = '.')
                    kw = get_keyword()
                    if compare(and_bits(kw, LABEL), LABEL) then
                        error("Invalid member name: ")
                    end if
                    for j = 1 to length(strucs[n][3]) do
                        if compare(label_names[kw-LABEL], strucs[n][3][j][1]) = 0 then
                            offset = offset + strucs[n][3][j][3]
                            if and_bits(strucs[n][3][j][2], STRUC) = 0 then
                            -- data element
                                if size = 0 then -- set data size unless overridden
                                    size = strucs[n][3][j][2]
                                end if
                                n = 0
                            else
                            -- another struc
                                n = strucs[n][3][j][2] - STRUC
                            end if
                            exit
                        elsif j = length(strucs[n][3]) then
                            error("Invalid member name: ")
                        end if
                    end for
                    if n = 0 and size = 0 then
                        error("Invalid member name '" & label_names[kw-LABEL] & "': ")
                    end if
                end while
--                label_name = ""
                kw = IMMEDIATE
                immediate = int_to_bytes(offset)
            elsif n != 0 then
                no_whitespace()
                kw = get_keyword()
            end if
        end if
        if compare(kw, IMMEDIATE) = 0 then
            displacement = int_to_bytes(bytes_to_int(displacement) + 
		bytes_to_int(immediate))
            immediate = {}
            --for x = 1 to 3 do
            --    displacement[x+1] = displacement[x+1] + floor(displacement[x] / 256)
            --    displacement[x] = remainder(displacement[x], 256)
            --end for
            --displacement[4] = remainder(displacement[4], 256)
        elsif compare(and_bits(kw, SEGMENT), SEGMENT) = 0 then
            segment_override = {segment_prefixes[and_bits(kw, 7)]}
            asm_pos = asm_pos + (asm_text[asm_pos] = ':')
        elsif compare(and_bits(kw, REGISTER), REGISTER) = 0 then
            if and_bits(kw, SIZE_MASK) = WORD and address_size != DWORD then
                address_size = WORD
                kw = and_bits(kw, 7)
                if kw = 3 then --BX
                    rm = 8*(rm=0) + 1*(rm=5) + 2*(rm=6)
                elsif kw = 5 then --BP
                    rm = 7*(rm=0) + 3*(rm=5) + 4*(rm=6)
                elsif kw = 6 then --SI
                    rm = 5*(rm=0) + 1*(rm=8) + 3*(rm=7)
                elsif kw = 7 then --DI
                    rm = 6*(rm=0) + 2*(rm=8) + 4*(rm=7)
                end if
            elsif and_bits(kw, SIZE_MASK) = DWORD and address_size != WORD then
                address_size = DWORD
                kw = and_bits(kw, 7)
                no_whitespace()
                if kw != 4 then
                    if asm_text[asm_pos] = '*' then
                        if index != 0 then
                            error("Only one index allowed in effective address: ")
                        end if
                        asm_pos = asm_pos + 1
                        no_whitespace()
                        if asm_text[asm_pos] = '1' then
                            scale = 0
                        elsif asm_text[asm_pos] = '2' then
                            scale = 1
                        elsif asm_text[asm_pos] = '4' then
                            scale = 2
                        elsif asm_text[asm_pos] = '8' then
                            scale = 3
                        else
                            error("Invalid scale value in effective address: ")
                        end if
                        asm_pos = asm_pos + 1
                        index = kw + 1
                        if base = 0 then
                            base = rm
                        end if
                        rm = 5
                    else
                        if rm = 0 then
                            rm = kw + 1
                        elsif base = 0 then
                            base = kw + 1
                            if rm != 5 then
                                index = rm
                                rm = 5
                            end if
                        elsif index = 0 then
                            index = kw + 1
                            if rm != 6 then
                                base = rm
                                rm = 5
                            end if
                        else
                            error("Too many operands in effective address: ")
                        end if
                    end if
                else
                    if rm = 0 then
                        index = 5
                        rm = 5
                        base = 5
                    else
                        error("Too many operands in effective address: ")
                    end if
                end if
            else
                error("Invalid operand sizes in effective address: ")
            end if
        else    
            error("Invalid combination of operands in effective address: ")
        end if
        no_whitespace()
        if asm_text[asm_pos] = '+' then
            asm_pos = asm_pos + 1
        elsif asm_text[asm_pos] = '-' or asm_text[asm_pos] = ')' then
        else
            exit
        end if
    end while

    if base or index or scale then
        if index then
            index = index - 1
        else
            index = 4
        end if
        if base then
            sib = {base-1 + 8*index + #40*scale}
        else
            sib = {5 + 8*index + #40*scale}
        end if
    end if
    if displacement_label then
        if and_bits(displacement_label, SIZE_MASK) then
            address_size = and_bits(displacement_label, SIZE_MASK)
        else
            address_size = DEFAULT_ADDRESS
        end if
        if rm = 0 then
            rm = 6 - (DEFAULT_ADDRESS = DWORD)
            if address_size != DEFAULT_ADDRESS then
                error("Unable to override displacement size when mod=0: ")
            end if
        elsif length(sib) and base = 0 then
            rm = rm - 1
            address_size = DWORD
        elsif address_size = BYTE then
            rm = #40 + rm - 1
        else
            rm = #80 + rm - 1
        end if
        displacement = displacement[1..floor(address_size / BYTE)]
        displacement_label = and_bits(displacement_label, not_bits(SIZE_MASK))
        label_names[displacement_label] = prepend(label_names[displacement_label], '&')
    elsif length(sib) and base = 0 then
        rm = rm - 1
    elsif rm = 0 then
        rm = 6 - (DEFAULT_ADDRESS = DWORD)
        displacement = displacement[1..floor(DEFAULT_ADDRESS / BYTE)]
    elsif compare(displacement, {0,0,0,0}) = 0 then
        rm = rm - 1
        if rm = 5 and base = 0 and scale = 0 and index = 0 then
            -- fixup EBP
            rm = #40 + rm
            displacement = {0}
        elsif base != 6 then
            displacement = {}
        else
            rm = #40 + rm
            displacement = {0}
        end if
    elsif is_short(displacement) then
        rm = #40 + rm - 1
        displacement = displacement[1..1]
    else
        rm = #80 + rm - 1
        displacement = displacement[1..floor(address_size / BYTE)]
    end if
    
    if asm_text[asm_pos] = ']' then 
        asm_pos = asm_pos + 1
    else
        error("Expected ']' in effective address: ")
    end if
    immediate = save_immediate
    modrm = {rm}
    return rm + MODRM + size
end function


function get_token()
-- gets a token from asm_text, expands upon modrm, clears whitespace, removes comma
    object kw

    no_whitespace()
    kw = get_keyword()
    if compare(and_bits(kw, MODRM), MODRM) = 0 then
        kw = get_effective_address(and_bits(kw, SIZE_MASK))
    elsif compare(kw, STRUC) = 0 or compare(kw, UNION) = 0 then
        get_struc(compare(kw, UNION) = 0)
        kw = {}
    end if
    no_whitespace()
    return kw
end function    


function get_operand(sequence code, sequence param, sequence new_pos)
-- returns 0 if param does not accomodate code
-- else returns 1, builds opcode, and moves asm_pos to after last param used
    sequence attr
    integer reg_shift, immediate_size, attr_size_mask
    attr = and_bits(code, not_bits(#FF))
    opcode = and_bits(code, #FF)
    reg_shift = 1
    operand_size = 0
    immediate_size = 0
    for i = 1 to length(code) do
        attr_size_mask = and_bits(attr[i], SIZE_MASK)
        
        if and_bits(attr[i], REVERSE) then
            if length(param) >= 2 then
                param = param[2] & param[1] & param[3..length(param)]
            else
                return 0
            end if
        end if
        
        if and_bits(attr[i], DIRECTION) then
            if length(param) >= 2 then
                if and_bits(param[1], MODRM + REGISTER) = 0 
                or and_bits(param[2], MODRM) then
                    param = param[2] & param[1] & param[3..length(param)]
                    opcode[i] = opcode[i] + 2
                end if
            else
                return 0
            end if
        end if

        if and_bits(attr[i], SIGN_EXTEND) then
            if length(param) >= 2 then
                if and_bits(param[1], MODRM + REGISTER) then
                    if and_bits(param[1], BYTE) then
                        -- skip if modrm is not a word or dword
                    elsif and_bits(param[2], IMMEDIATE) then
                        if and_bits(param[2], WORD + DWORD) then
                            -- skip if immediate is explicitly not to become a byte
                        elsif is_short(immediate) then
                            immediate_size = BYTE
                            opcode[i] = opcode[i] + 3
                        end if
                    elsif and_bits(param[2], LABEL) then
                        if and_bits(param[2], SIZE_MASK) = BYTE then
                            immediate_size = BYTE
                            opcode[i] = opcode[i] + 3
                        end if
                    end if
                end if
            else
                return 0
            end if
        end if
        
        if and_bits(attr[i], IMMED) then
            immediate_size = attr_size_mask
        elsif attr_size_mask then
            operand_size = attr_size_mask
        end if

        if and_bits(attr[i], CONSTANT_DISP) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], MODRM) = 0 
            or and_bits(param[1], #FF) != 6 + (5 - 6) * (DEFAULT_ADDRESS = DWORD) then
                return 0
            end if
            if and_bits(param[1], SIZE_MASK) then
                operand_size = and_bits(param[1], SIZE_MASK)
            end if
            param = param[2..length(param)]
        end if

        if and_bits(attr[i], ACCUMULATOR) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], REGISTER + 7) = REGISTER then
                if attr_size_mask and and_bits(param[1], attr_size_mask) = 0 then
                    return 0
                end if
                if operand_size and and_bits(param[1], operand_size) = 0 then
                    return 0
                else
                    operand_size = and_bits(param[1], SIZE_MASK)
                end if
                if attr_size_mask = 0 then
                    opcode[i] = opcode[i] + (operand_size > BYTE)
                end if
                param = param[2..length(param)]
            else
                return 0
            end if
        end if

        if and_bits(attr[i], MODRM) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], REGISTER) then
                param[1] = param[1] - REGISTER + MODRM + #C0 
            end if
            if and_bits(param[1], MODRM) then
                opcode[i] = opcode[i] + and_bits(param[1], #C7)
                if operand_size then 
                    operand_size = and_bits(param[1], operand_size) 
                    if operand_size = 0 then
                        return 0
                    end if
                elsif and_bits(param[1], SIZE_MASK) then
                    operand_size = and_bits(param[1], SIZE_MASK)
                end if
                if (immediate_size != BYTE and operand_size) or and_bits(attr[i], IMMED) then
                    opcode[i-1] = opcode[i-1] + (operand_size > BYTE)
                end if
                param = param[2..length(param)]
                reg_shift = 8
            else
                return 0
            end if
        end if

            
        if and_bits(attr[i], REGISTER) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], REGISTER) then

                if operand_size then
                    operand_size = and_bits(param[1], operand_size) 
                    if operand_size = 0 then
                        return 0
                    end if
                else
                    operand_size = and_bits(param[1], SIZE_MASK)
                    if and_bits(attr[i], MODRM) then
                        opcode[i-1] = opcode[i-1] + (operand_size > BYTE)
                    elsif attr_size_mask = 0 then -- NEW CODE! MIGHT BREAK!
                        opcode[i] = opcode[i] + (operand_size > BYTE)
                    end if
                end if

                opcode[i] = opcode[i] + and_bits(param[1], 7) * reg_shift
                param = param[2..length(param)]
            else
                return 0
            end if
        end if
        
        if and_bits(attr[i], SEGMENT) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], SEGMENT) then
                param[1] = and_bits(param[1], 7)
                if param[1] < 4 then
                    opcode[i] = opcode[i] + param[1] * 8
                    if opcode[i] = #0F then
                        return 0  -- can't POP CS
                    end if
                else --FS or GS
                    opcode = {#0F,opcode[i]-6+#A0+(param[1]-4)*8}
                end if                
                param = param[2..length(param)]
            else
                return 0
            end if
        end if
                
       
        if and_bits(attr[i], IMMEDIATE) or and_bits(attr[i], IMMED) then
            if length(param) = 0 or (immediate_size = 0 and operand_size = 0) then
                return 0
            elsif and_bits(param[1], LABEL) then
                if and_bits(param[1], SIZE_MASK) then
                    if (immediate_size and (and_bits(param[1], SIZE_MASK) != immediate_size))
                    or (operand_size and (and_bits(param[1], SIZE_MASK) != operand_size)) then
                        return 0
                    end if
                    immediate_size = and_bits(param[1], SIZE_MASK)
                    if and_bits(attr[i], CANCEL_SX) and operand_size > BYTE and immediate_size = BYTE then
                        return 0
                    end if
                end if
                immediate_label = param[1] - LABEL - and_bits(param[1], SIZE_MASK)
                label_names[immediate_label] = prepend(label_names[immediate_label], '&')
                param = param[2..length(param)]                
                immediate = repeat(0, floor((immediate_size * (immediate_size != 0) +
                    operand_size * (operand_size != 0 and immediate_size = 0)) / BYTE))
            elsif and_bits(param[1], IMMEDIATE) then
                if and_bits(attr[i], CANCEL_SX) and operand_size > BYTE and is_short(immediate) then
                    return 0
                end if
                if length(immediate) then
                    immediate = immediate[1..floor((immediate_size * (immediate_size != 0) +
                        operand_size * (operand_size != 0 and immediate_size = 0)) / BYTE)]
                else
                    immediate = repeat(0, floor((immediate_size * (immediate_size != 0) +
                        operand_size * (operand_size != 0 and immediate_size = 0)) / BYTE))
                end if
                param = param[2..length(param)]
            else
                return 0
            end if
        end if

        if and_bits(attr[i], CONSTANT_1) then
            if length(param) = 0 then
                return 0
            elsif param[1] = IMMEDIATE then
                if compare(immediate,{1,0,0,0}) != 0 then
                    return 0
                else
                    immediate = {}
                    param = param[2..length(param)]
                end if
            else
                return 0
            end if
        end if

        if and_bits(attr[i], CONSTANT_CL) then
            if length(param) = 0 then
                return 0
            elsif param[1] != REGISTER + BYTE + 1 then
                return 0
            else
                param = param[2..length(param)]
            end if
        end if

        if and_bits(attr[i], CONSTANT_DX) then
            if length(param) = 0 then
                return 0
            elsif param[1] != REGISTER + WORD + 2 then
                return 0
            else
                param = param[2..length(param)]
            end if
        end if

        if and_bits(attr[i], CONSTANT_AX) then
            if length(param) = 0 then
                return 0
            elsif param[1] != REGISTER + WORD then
                return 0
            else
                param = param[2..length(param)]
            end if
        end if

        if and_bits(attr[i], LABEL) then
            if length(param) = 0 then
                return 0
            elsif param[1] = IMMEDIATE then
                if immediate_size != 0 then
                    immediate = immediate[1..floor(immediate_size / BYTE)]
                elsif operand_size != 0 then
                    immediate = immediate[1..floor(operand_size / BYTE)]
                end if
            elsif and_bits(param[1], LABEL) then
                if and_bits(param[1], SIZE_MASK) then
                    if (immediate_size and (and_bits(param[1], SIZE_MASK) != immediate_size))
                    or (operand_size and (and_bits(param[1], SIZE_MASK) != operand_size)) then
                        return 0
                    end if
                end if
                immediate_label = param[1] - LABEL - and_bits(param[1], SIZE_MASK)
                immediate = repeat(0, floor((immediate_size * (immediate_size != 0) +
                    operand_size * (operand_size != 0 and immediate_size = 0)) / BYTE))
            else
                return 0
            end if
            param = param[2..length(param)]
        end if
        
        if and_bits(attr[i], EXTENSION) then
            if length(param) < 2 then
                return 0
            elsif and_bits(param[2], REGISTER) then
                param[2] = param[2] - REGISTER + MODRM + #C0 
            end if
            if and_bits(param[1], REGISTER) and and_bits(param[2], MODRM) then
                if and_bits(attr[i], SIZE_MASK) = 0 then
                    if and_bits(param[1], SIZE_MASK) = BYTE 
                    or and_bits(param[2], SIZE_MASK) = DWORD then
                        return 0
                    end if
                elsif attr_size_mask = QWORD or attr_size_mask = DWORD then
                    if and_bits(param[2], SIZE_MASK) = 0 then
                        param[2] = param[2] + attr_size_mask
                    end if 

                    if and_bits(param[1], SIZE_MASK) != QWORD 
                    or and_bits(param[2], SIZE_MASK) != attr_size_mask then
                        return 0
                    end if
                end if

                operand_size = and_bits(param[1], SIZE_MASK)
                opcode[i] = opcode[i] 
                    + and_bits(param[1], 7) * 8 
                    + and_bits(param[2], #C7)
                if and_bits(param[2], SIZE_MASK) = WORD then
                    opcode[i-1] = opcode[i-1] + 1
                end if
            else
                return 0                
            end if
            
            param = param[3..length(param)]
        end if

        if and_bits(attr[i], FPU_MODRM) then
            if length(param) = 0 then
                return 0
            elsif and_bits(param[1], MODRM) then
                if and_bits(attr[i], SIZE_MASK) != and_bits(param[1], SIZE_MASK) then
                    return 0
                end if
                operand_size = 0
                opcode[i] = opcode[i] + and_bits(param[1], #C7)
                param = param[2..length(param)]
            else
                return 0
            end if
        end if

        if and_bits(attr[i], SUFFIX) then
	    suffix = {opcode[i]}
	    opcode = opcode[1..i-1]
	end if

    end for
    asm_pos = new_pos[length(param)+1]
    return 1
end function

constant hex = "0123456789ABCDEF"
constant source_column = 28
sequence parameters, labels
--parameters = {}  labels = {}
global integer asm_output_style, asm_output_file
global sequence asm_proc_name
asm_output_style = 1
asm_output_file = -1
asm_proc_name = "proc"

global procedure asm_output(object fn, integer style)
    if sequence(fn) then
        if find('.', fn) then
            asm_proc_name = fn[1..find('.', fn)-1]
        else
            asm_proc_name = fn
        end if
        fn = open(fn, "w")
    end if
    asm_output_file = fn
    if style >= 1 and style <= 3 then
        asm_output_style = style
    end if
    while find('\\', asm_proc_name) do
        asm_proc_name = asm_proc_name[find('\\', asm_proc_name)+1..length(asm_proc_name)]
    end while
end procedure

atom asm_proc
global function get_asm(sequence text)
--   returns a sequence of machine code
--   and outputs a commented eu-code sequence to asm_output_file if nonzero
--     (use 1 for asm_output_file for output to the screen)

    object token, t1
    sequence asm_code, param, code, line_numbers, ur_labels, new_pos, source_code
    integer save_pos, n, op_end, data_label
    
    if atom(text[1]) then
        asm_text = text
    else
        asm_text = {}
        for i = 1 to length(text) do
            asm_text = asm_text & text[i] & '\n'
        end for
    end if
    error_line = 1
    asm_pos = 1
    asm_code = {}
    line_numbers = {}
    ur_labels = {}
    labels = {}
    parameters = {}
    
    while asm_pos <= length(asm_text) do
        instruction_prefix = {}
        address_size_prefix = {}
        operand_size_prefix = {}
        segment_override = {}
        opcode = {}
        modrm = {}
        sib = {}
        displacement = {}
        immediate = {}
	suffix = {}
        operand_size = 0
        address_size = 0
        immediate_label = 0
        displacement_label = 0
        data_label = 0
        label_names = {}
        code = {}
        
        no_whitespace()
        opstart = asm_pos
        token = get_token()
        while compare(and_bits(token, LABEL), LABEL) = 0 do
            for i = 1 to length(strucs) do
                if compare(label_names[token-LABEL], strucs[i][1]) = 0 then  -- data structure
                    for j = 1 to length(strucs[i][3]) do
                        if j = 1 or strucs[i][3][j][3] then
                        -- only the first element is used to initialize a union
                            code = code & strucs[i][3][j][4]  -- initialized data
                        end if
                    end for
                    token = {}  -- continue normally
                    exit
                end if
            end for
            if compare(token, {}) then  -- not a structure so it must be a label
                labels = prepend(labels, {label_names[token-LABEL], length(asm_code)})
                if asm_pos <= length(asm_text) then
                    asm_pos = asm_pos + (asm_text[asm_pos] = ':')
                end if
                no_whitespace()
                token = get_token()
            end if
        end while
        if compare(and_bits(token, DATA), DATA) = 0 then
            data_label = length(label_names) 
            token = and_bits(token, SIZE_MASK)
            if token = QWORD then token = #800
            elsif token = TBYTE then token = #A00 end if
            code = get_data(token)
            no_whitespace()
        else
            if compare(and_bits(token, PREFIX), PREFIX) = 0 then
                if and_bits(token, SEGMENT) then
                    segment_override = {and_bits(token, #FF)}
                else
                    instruction_prefix = {and_bits(token, #FF)}
                end if
                token = get_token()
            end if
            if atom(token) then
                --puts(1, asm_text[asm_pos..asm_pos+40]&"\n") 
                asm_pos = opstart
                if length(label_names) then
                    error("Not a valid instruction '" & label_names[length(label_names)] & "': ")
                else
                    error("Not a valid instruction: ")
                end if                    
            elsif length(token) then  -- instruction
                param = {}
                new_pos = {asm_pos}
                for i = 1 to 3 do
                    save_pos = asm_pos
                    t1 = get_token()
                    if asm_pos <= length(asm_text) then
                        asm_pos = asm_pos + (asm_text[asm_pos] = ',')
                    end if
                    if atom(t1) then
                        param = append(param, t1)
                        new_pos = asm_pos & new_pos
                    else
                        asm_pos = save_pos
                        exit
                    end if
                end for
                for i = 1 to length(token) do
                    if get_operand(token[i], param, new_pos) then
                        exit
                    else
                        opcode = {}
                    end if
                end for
                if length(opcode) then
                    if operand_size = WORD or operand_size = DWORD then
                        if operand_size != DEFAULT_OPERAND then
                            operand_size_prefix = operand_override
                        end if
                    end if
                    if address_size = WORD or address_size = DWORD then
                        if address_size != DEFAULT_ADDRESS then
                            address_size_prefix = address_override
                        end if
                    end if
                    
                    code =  instruction_prefix &
                            address_size_prefix &
                            operand_size_prefix &
                            segment_override &
                            opcode &
--                            modrm &  -- modrm is part of opcode
                            sib &
                            displacement &
                            and_bits(immediate, #FF) &
			    suffix
                else
                    error("Invalid combination of operands: ")
                end if
            end if
        end if
        
        op_end = asm_pos - 1
        if op_end > length(asm_text) then
            op_end = length(asm_text)
        end if
        while asm_text[op_end] <= ' ' do
            op_end = op_end - 1
        end while
        line_numbers = append(line_numbers, {length(asm_code)+1,length(asm_code)+length(code),opstart,op_end})
        
        if length(code) then
            asm_code = asm_code & code
            if data_label then
                ur_labels = append(ur_labels, {'&'&label_names[data_label], 
                    length(asm_code), length(code),opstart,op_end})
            end if
            if displacement_label then
                ur_labels = append(ur_labels, {label_names[displacement_label], 
                    length(asm_code)-length(immediate)-length(suffix), length(displacement),opstart,op_end})
            end if
            if immediate_label then
                ur_labels = append(ur_labels, {label_names[immediate_label], 
                    length(asm_code), length(immediate),opstart,op_end})
            end if
        end if

    end while

    if length(asm_code) = 0 then return 0 end if
    asm_proc = allocate(length(asm_code))

    for i = 1 to length(ur_labels) do -- finish unresolved_labels
        if ur_labels[i][1][1] = '&' then  -- parameter or reference
            param = ur_labels[i][1][2..length(ur_labels[i][1])]
            n = ur_labels[i][2] - ur_labels[i][3]
            parameters = prepend(parameters, {param, n} & ur_labels[i][3..5])
            if param[1] = '@' then -- reference
                param = param[2..length(param)]
                n = -1
                for j = 1 to length(ur_labels) do
                    if compare('&'&param, ur_labels[j][1]) = 0 then  -- to param
                        n = ur_labels[j][2] - ur_labels[j][3]
                        parameters[1] = append(parameters[1], n)
                        code = and_bits(int_to_bytes(n + asm_proc), #FF)
                        asm_code[ur_labels[i][2]-ur_labels[i][3]+1 .. ur_labels[i][2]] =
                            code[1..ur_labels[i][3]]
                        exit
                    end if
                end for
                if n = -1 then
                    for j = 1 to length(labels) do
                        if compare(param, labels[j][1]) = 0 then  -- to label
                            n = labels[j][2]
                            parameters[1] = append(parameters[1], n)
                            code = and_bits(int_to_bytes(n + asm_proc), #FF)
                            asm_code[ur_labels[i][2]-ur_labels[i][3]+1 .. ur_labels[i][2]] =
                                code[1..ur_labels[i][3]]
                            exit
                        end if
                    end for
                end if
                if n = -1 then
                    opstart = ur_labels[i][4]
                    asm_pos = ur_labels[i][5]+1
                    error("Unable to resolve reference '@" & param & "' :")
                end if
            else  -- parameter
                for j = 1 to length(line_numbers) do
                    if n >= line_numbers[j][1]-1 and n <= line_numbers[j][2]-1 then
                        line_numbers[j] = append(line_numbers[j], sprintf(" (%d)",{n}))
                    end if
                end for                
            end if
        else  -- labels
            for j = 1 to length(labels) do
                if compare(ur_labels[i][1], labels[j][1]) = 0 then
                    n = labels[j][2] - ur_labels[i][2]
                    if (n < -128 or n > 127) and (ur_labels[i][3] = 1) then
                        opstart = ur_labels[i][4]
                        asm_pos = ur_labels[i][5]+1
                        error("Label '" & ur_labels[i][1] & "' too far away:")
                    end if
                    code = and_bits(int_to_bytes(n), #FF)
                    asm_code[ur_labels[i][2]-ur_labels[i][3]+1 .. ur_labels[i][2]] =
                        code[1..ur_labels[i][3]]
                    exit
                elsif j = length(labels) then
                    opstart = ur_labels[i][4]
                    asm_pos = ur_labels[i][5]+1
                    error("Unable to resolve label '" & ur_labels[i][1] & "' :")
                end if
            end for
        end if
    end for
    
    poke(asm_proc, asm_code)
    
    if asm_output_file != -1 then
        printf(asm_output_file, "constant %s = allocate(%d)\npoke(%s, {\n", 
            {asm_proc_name, length(asm_code), asm_proc_name})
        if asm_output_style = 3 then
            n = 1
            while n <= length(asm_code) do
                for i = 1 to 20 do
                    puts(asm_output_file, "#" & 
                        hex[floor(asm_code[n] / 16)+1] & 
                        hex[remainder(asm_code[n], 16)+1])
                    n = n + 1
                    if n <= length(asm_code) then
                        puts(asm_output_file, ",")
                    else
                        exit
                    end if
                    if i = 20 then
                        puts(asm_output_file, "\n")
                    end if
                end for
            end while
            puts(asm_output_file, "})\n")
        else
            for i = 1 to length(line_numbers) do
                code = "    " 
                for j = line_numbers[i][1] to line_numbers[i][2] do
    --                if j = 1 then
    --                    code[length(code)] = '{'
    --                end if
                    n = asm_code[j]
                    code = code & "#" & hex[floor(n / 16)+1] & hex[remainder(n, 16)+1] & ","
                    if j = length(asm_code) then
                        code = code[1..length(code)-1] & "})"
                    end if
                end for
                source_code = text[line_numbers[i][3]..line_numbers[i][4]]
                n = find(10, source_code)
                while n do
                    puts(asm_output_file, repeat(32, source_column)&"-- ")
                    if asm_output_style = 1 then
                        printf(asm_output_file, "%4x: ", {line_numbers[i][1]-1})
                    end if
                    puts(asm_output_file, source_code[1..n])
                    source_code = source_code[n+1..length(source_code)]
                    n = find(10, source_code)
                end while
                if length(code) < source_column then
                    code = code & repeat(' ', source_column - length(code))
                end if
                puts(asm_output_file, code & "-- ")
                if asm_output_style = 1 then
                    printf(asm_output_file, "%4x: ", {line_numbers[i][1]-1})
                end if
                
                puts(asm_output_file, source_code)
                for j = 5 to length(line_numbers[i]) do
                    puts(asm_output_file, line_numbers[i][j])
                end for
                puts(asm_output_file, "\n")
            end for
                
        end if

        for i = length(parameters) to 1 by -1 do
            puts(asm_output_file, "poke")
            if parameters[i][3] = 4 then
                puts(asm_output_file, "4")
            end if
            if parameters[i][1][1] = '@' then
                printf(asm_output_file, "(%s + %d, %s + %d) -- %s\n", 
                    {asm_proc_name, parameters[i][2], 
                    asm_proc_name, parameters[i][6],
                    parameters[i][1]})
            elsif equal(repeat(0, parameters[i][3]), 
                peek({asm_proc + parameters[i][2], parameters[i][3]})) then
                printf(asm_output_file, "(%s + %d, %s)\n", 
                    {asm_proc_name, parameters[i][2], parameters[i][1]})
            else
                printf(asm_output_file, "(%s + %d, %s + peek", 
                    {asm_proc_name, parameters[i][2], parameters[i][1]})
                if parameters[i][3] = 4 then
                    puts(asm_output_file, "4s")
                end if
                printf(asm_output_file, "(%s + %d))\n", 
                    {asm_proc_name, parameters[i][2]})
                
            end if
        end for
    end if

    return asm_proc
end function

global function get_param(sequence name)
    for i = 1 to length(parameters) do
        if compare(name, parameters[i][1]) = 0 then
            return parameters[i][2]
        end if
    end for
    puts(2,"Unable to find param '"&name&"'\n")
--    for i = 1 to length(parameters) do
--        printf(1, "%s = %d, ", parameters[i][1..2])
--    end for
    return -1
end function

global function get_label(sequence name)
    for i = 1 to length(labels) do
        if compare(name, labels[i][1]) = 0 then
            return labels[i][2]
        end if
    end for
    puts(2,"Unable to find label '"&name&"'\n")
    return -1
end function

global procedure resolve_param(sequence name, object data)
    atom unresolved, temp
    unresolved = 1
    if atom(data) then data = {data} end if
    for i = 1 to length(parameters) do
        if compare(name, parameters[i][1]) = 0 then
            if parameters[i][3] = 1 then
                poke(asm_proc + parameters[i][2], data + 
                    peek({asm_proc + parameters[i][2], length(data)}))
            elsif parameters[i][3] = 2 then
                for j = 1 to length(data) do
                   temp = data[j] +
                           peek(asm_proc + parameters[i][2] + j*2-2) +
                     256 * peek(asm_proc + parameters[i][2] + j*2-1)
                   poke(asm_proc + parameters[i][2]+j*2-2, 
                       {temp,temp/#100})
                end for
            elsif parameters[i][3] = 4 then
                poke4(asm_proc + parameters[i][2], data + 
		    peek4s({asm_proc + parameters[i][2], length(data)}))
            end if
            --poke(asm_proc + parameters[i][2], data[1..parameters[i][3]])
            unresolved = 0
        end if
    end for
    if unresolved then
        puts(2, "Warning: parameter '"&name&"' was not found and could not be resolved.\n")
    end if
end procedure

global function include_asm(sequence infile)
    integer fn
    sequence code
    object line
    fn = open(infile, "r")
    if fn = -1 then
        fn = open(infile&".asm", "r")
        if fn = -1 then
            printf(2, "\n\n  Could not open \"%s\" or \"%s.asm\"\n\n", {infile,infile})
            abort(1)
        end if
    end if
    if find('.', infile) then
        asm_proc_name = infile[1..find('.', infile)-1]
    else
        asm_proc_name = infile
    end if

    code = ""
    line = gets(fn)
    while sequence(line) do
        code = code & line
        line = gets(fn)
    end while           
    close(fn)
    return get_asm(code)    
end function

