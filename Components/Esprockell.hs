{-# language RecordWildCards #-}
module Components.Esprockell where

{-------------------------
| TODO: 
| add error status
| store address in register such pointer could be implemented
-------------------------}
import CLaSH.Prelude hiding(Word)
import Components.Types
import Debug.Trace



decode :: DAddr         -- ^ stack pointer
       -> Instruction   -- ^ current instruction
       -> MachCode      -- ^ target machine code
decode sp instr = case instr of
    Arith op r0 r1 r2  -> def {ldCode  = LdAlu,  opCode   = op,  fromReg0 = r0, fromReg1 = r1, toReg = r2}
    Jump  jType jAddr  -> def {jmpCode = jType,  jmpNum   = jAddr}
    Load (RImm n) rid  -> def {ldCode  = LdImm,  ldImm    = n,   toReg    = rid}
    Load (RAddr a) rid -> def {ldCode  = LdAddr, fromAddr = (ImmAdr a),   toReg    = rid}
    Load (RPtr p)  rid -> def {ldCode  = LdAddr, fromAddr = (RegPtr p),   toReg    = rid}
    Store (MImm n) a   -> def {stCode  = StImm,  stImm    = n,   toAddr   = a, we = True}
    Store (MReg r) a   -> def {stCode  = StReg,  fromReg0 = r,   toAddr   = a, we = True}
    Push r             -> def {stCode  = StReg,  fromReg0 = r,   toAddr   = ImmAdr (sp + 1), spCode = Up, we = True}
    Pop r              -> def {ldCode  = LdAddr, fromAddr = ImmAdr sp,  toReg    = r, spCode = Down}
    EndProg            -> def {jmpCode = UR,     jmpNum   = 0} -- forever loop here


alu :: OpCode       -- operator
    -> (Word, Word) -- to operands
    -> (Word, Bool) -- result and Conditional test resutl
alu op (x, y) =  (opRet, cnd)
    where (opRet, cnd) = (app op x y, testBit opRet 0)
          app op x y   = case op of
            Nop  -> 0 -- 此时，toreg应该是zeroreg
            Id   -> x
            Incr -> x + 1
            Decr -> x - 1
            Neg  -> negate x
            Not  -> complement x
            Add  -> x + y
            Sub  -> x - y
            Mul  -> x * y
            Div  -> x `quot` y
            Mod  -> x `rem` y
            Eq   -> if x == y then 1 else 0
            Ne   -> if x /= y then 1 else 0
            Gt   -> if x > y  then 1 else 0
            Lt   -> if x < y  then 1 else 0
            Le   -> if x <= y then 1 else 0
            Ge   -> if x >= y then 1 else 0
            And  -> x .&. y 
            Or   -> x .|. y
            Xor  -> x `xor` y

load :: LdCode 
     -> RegIdx 
     -> (Word, Word)  -- (immediate-number, aluOut)
     -> Reg
     -> Reg
load ldCode toReg (imm, aluOut) regs = regs <~ (toReg, v)
    where v = case ldCode of
                NoLoad -> 0
                LdImm  -> imm
                LdAlu  -> aluOut 
                LdAddr -> regs !! toReg -- memory-load is delayed


store :: StCode 
      -> (Word, Word) -- (immediate-number, reg-number)
      -> Word
store stCode (imm, regData) = case stCode of
                                NoStore -> 0    -- 此时, we == False
                                StImm   -> imm
                                StReg   -> regData

updatePC :: (JmpCode, Bool) -- (jump code, cnd)
         -> (PC, PC, Word)  -- (current-pc, jump-addr, jmpreg)
         -> PC
updatePC (jmpCode, cnd) (pc, jmpNum, jumpRegV) = case jmpCode of
   NoJmp -> pc + 1
   UA    -> jmpNum
   UR    -> pc + jmpNum
   CA    -> if cnd then jmpNum else pc + 1
   CR    -> if cnd then pc + jmpNum else pc + 1
   Back  -> fromIntegral jumpRegV

updateSp :: SpCode -> DAddr -> DAddr
updateSp None sp = sp
updateSp Up   sp = sp + 1
updateSp Down sp = sp - 1

oEn :: RegIdx -> RegIdx -> LdCode -> Bool
oEn bufLast toReg ldCode = memLoad || aluImm
    where memLoad = bufLast == oReg
          aluImm  = toReg   == oReg && (ldCode == LdImm || ldCode == LdAlu)

getAddr :: Reg -> RamAdr -> DAddr
getAddr _    (ImmAdr a) = a
getAddr regs (RegPtr p) = fromIntegral $ regs !! p

esprockellMealy :: PState -> PIn -> (PState, POut)
esprockellMealy state (instr, memData, gpInEn, gpInput) = (state', out)
    where 
        MachCode{..}   = decode sp instr
        PState{..}     = state
        (aluOut, aluCnd) = alu opCode (x, y)
        cnd' = if fromReg0 == iReg || opCode == Id then gpInEn else aluCnd
        state'  = PState { reg = reg', cnd = cnd', pc = pc', sp = sp', ldBuf = ldBuf'}
        wAddr   = getAddr reg toAddr
        rAddr   = getAddr reg fromAddr
        out     = (wAddr, rAddr, we, toMem, pc', gpOutEn, gpOut)
        gpOut   = reg' !! oReg
        gpOutEn = oEn bufLast toReg ldCode
        (x, y)  = (reg0 !! fromReg0, reg0 !! fromReg1)
        ldBuf'  = ldReg +>> ldBuf
        bufLast = last ldBuf
        ldReg 
          | ldCode == LdAddr = toReg
          | otherwise        = 0
        reg0 = reg  <~ (bufLast, memData)
                    <~ (iReg, gpInput) 
                    <~ (iEn, fromIntegral $ pack gpInEn)
                    <~ (zeroreg, 0)         -- r0
                    <~ (pcreg, fromIntegral pc) -- pc of next clock
        reg' = load ldCode toReg (ldImm, aluOut) reg0
        -- reg0   = load ldCode toReg (ldImm, aluOut) $ reg <~ (last ldBuf, memData)
        -- reg'   = reg0 <~ (zeroreg, 0) <~ (pcreg, fromIntegral pc')
        toMem  = store stCode (stImm, x)
        pc'    = updatePC (jmpCode, cnd) (pc, jmpNum, reg' !! jmpreg)
        sp'    = updateSp spCode sp

esprockell :: Signal PIn
           -> Signal POut
esprockell = esprockellMealy `mealy` def

