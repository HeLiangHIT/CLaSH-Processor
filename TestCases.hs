module TestCases where

import Components.Types
import CLaSH.Prelude
import qualified Data.List as L


progAdd :: [Instruction]
progAdd = [
  Load (RImm 3) r7 
  , Load (RImm 9) r8 
  , Arith Add r7 r8 r9
  , Arith Id r9 0 oReg
  , EndProg
    ]

-- 为何store后不能马上load?
progLdSt :: [Instruction]
progLdSt = [
    Store (MImm 13) (ImmAdr 0)
    , Load (RAddr 0) r9
    , Load (RImm 3) r7
    , Load (RImm 4) r8
    , Arith Add r7 r8 r8
    , Arith Add r8 r9 r9 -- r9 == 20
    , Push r9
    , Pop oReg
    , EndProg
    ]
progLdSt2 :: [Instruction]
progLdSt2 = [
    Store (MImm 13) (ImmAdr 0)
    , Store (MImm 14) (ImmAdr 1)
    , Load (RAddr 0) r7
    , Load (RAddr 1) r8
    , Load (RImm  3) r9 
    , Arith Add r7 r9 r9 -- r7 is ready, r8 is not ready
    , Arith Add r8 r9 r8 -- r8 is ready
    , Push r8            -- shoule write 30 to memory
    , Pop oReg
    , EndProg
    ]

progStack :: [Instruction]
progStack = [
    Load (RImm 3) r7
    , Push r7
    , Arith Incr r7 r7 r7
    , Push r7

    , Pop r8 -- r8 == 4
    , Arith Add r7 r8 r8 -- r8 == 8, r8 is ready, r9 is not ready
    , Pop r9 -- r9 == 3
    , Arith Add r8 r9 r9 -- r9 == 8 + 3 == 11
    , Push r9
    , Pop oReg
    , EndProg
    ]

progMov :: [Instruction]
progMov = [
    Load (RImm 3) r7 
    , Arith Id r7 zeroreg r8
    , Push r8
    , Pop oReg
    , EndProg
    ]

progJump :: [Instruction]
progJump = [
    Load (RImm 1)   r7 -- r7 := 1
    , Load (RImm 2) r8 -- r8 := 2
    , Load (RImm 2) r9 -- r9 := 2
    , Arith Add pcreg r9 jmpreg
    , Jump UR 4
    , Store (MReg r9) (ImmAdr 0)
    , Load (RAddr 0) r10
    , EndProg

    , Arith Add r7 r8 r9 -- r9 := 1+2= 3
    , Jump Back 0
    ]

progMax :: [Instruction]
progMax = [
    Store (MImm 3) (ImmAdr 0)
    , Store (MImm 4) (ImmAdr 1)
    , Load  (RAddr 0) r7
    , Load  (RAddr 1) r8
    , Load  (RImm  2) r9 -- inc to pc
    , Arith Add pcreg r9 jmpreg
    , Jump  UR 3
    , Arith Id r8 0 oReg
    , EndProg

    , Arith Lt r7 r8 r9
    , Jump  CR 2
    , Arith Id r7 r8 r8 -- move r7 to r8
    , Jump  Back 0
    ] 

-- define recursive fib function
progFibRecr :: [Instruction]
progFibRecr = [
    Store (MImm 9) (ImmAdr 0)
    , Load  (RAddr 0) r7
    , Load  (RImm 2) r8
    , Arith Add pcreg r8 jmpreg
    , Jump  UA fibAbsAddr
    , Arith Id r8 0 oReg
    , EndProg

    , Load (RImm 2) r8
    , Arith Lt r7 r8 r8    -- whether input < 2
    , Jump CA recursionOut -- Conditional Absolute jump

    , Push jmpreg   -- fib (n-1)
    , Push r7
    , Arith Decr r7 zeroreg r7 -- r7 - 1
    , Load (RImm 2) r8
    , Arith Add pcreg r8 jmpreg
    , Jump UA fibAbsAddr
    , Pop r7
    , Pop jmpreg
    , Arith Id r8 zeroreg r9 -- move r8 to r9
    , Push jmpreg -- fib (n-2)
    , Push r7
    , Push r9
    , Load (RImm 2) r8
    , Arith Sub r7 r8 r7 -- r7 - 2
    , Arith Add pcreg r8 jmpreg
    , Jump UA fibAbsAddr    -- unconditional Absolute jump
    , Pop r9
    , Pop r7
    , Pop jmpreg

    , Arith Add r8 r9 r8 -- fib (n-1） + fib (n-2)
    , Jump UR 2         -- unconditional relative jump
    , Load (RImm 1) r8  -- recursionOut fib 0 or fib 1
    , Jump Back 0
    ] 
    where
        fibAbsAddr   = 1 + (fromIntegral $ L.length $ L.takeWhile (/= EndProg) progFibRecr)
        recursionOut = fromIntegral $ L.length progFibRecr - 2

progFibIter = [
    Store (MImm 8) (ImmAdr 0) -- mem[0] := 8

    , Load (RAddr 0) r7 -- r7 := mem[0]
    , Load (RImm 2)  r8 -- r8 := 2
    , Arith Add pcreg r8 jmpreg -- jmpreg := pcreg + r8
    , Jump UA fibIterAddr -- call fibIter
    , Arith Id r8 0 oReg
    , EndProg

    , Load (RImm 1) r8 -- r8 := 1
    , Load (RImm 0) r9 -- r9 := 1
    , Arith Eq r7 zeroreg r10 -- test
    , Jump CA fibIterRet
    , Arith Decr r7 r7 r7 -- r7 -= 1
    , Arith Id r8 zeroreg r10 -- r10 := r8
    , Arith Add r8 r9 r8      -- r8  := r8 + r9
    , Arith Id r10 zeroreg r9 -- r9  := 10
    , Jump UR fibIterTestZero

    , Jump Back 0
    ] 
    where fibIterAddr     = 1 + (fromIntegral $ L.length $ L.takeWhile (/= EndProg) progFibIter)
          fibIterRet      = fromIntegral $ L.length progFibIter - 1
          fibIterTestZero = (-6)

progFacIter = [
    Store (MImm 6) (ImmAdr 0)    -- mem[0] := 8
    
    , Load (RAddr 0) r7  -- r7 := mem[0]
    , Load (RImm 2)  r8  -- r8 := 2
    , Arith Add pcreg r8 jmpreg -- jmpreg := pcreg + 2
    , Jump UA facIterAddr   -- call facIter
    , Arith Id r8 0 oReg
    , EndProg
    
    , Load  (RImm 1) r8     -- r8 = 1
    , Arith Eq       r7 zeroreg r9  
    , Jump  CA       facIterRet 
    , Arith Mul      r8 r7 r8
    , Arith Decr     r7 r7 r7
    , Jump  UR       (-4)
    , Jump  Back     0 -- return
    ]
    where facIterRet  = fromIntegral $ L.length progFacIter - 1
          facIterAddr = 1 + (fromIntegral $ L.length $ L.takeWhile (/= EndProg) progFacIter)

progFacRecr = [
    Store (MImm 6) (ImmAdr 0)
    , Load  (RAddr 0) r7
    , Load  (RImm  2) r8
    , Arith Add       pcreg r8 jmpreg
    , Jump  UA        facRecrAddr
    , Arith Id r8 0 oReg
    , EndProg

    , Arith Eq r7 zeroreg r8
    , Jump CA facRecrRet

    , Push jmpreg
    , Push r7
    , Load (RImm 2) r8
    , Arith Decr r7 r7 r7
    , Arith Add pcreg r8 jmpreg
    , Jump UA facRecrAddr
    , Pop  r7
    , Pop  jmpreg
    , Arith Mul r7 r8 r8

    , Jump Back 0
    ]
    where facRecrAddr = 1 + (fromIntegral $ L.length $ L.takeWhile (/= EndProg) progFacRecr)
          facRecrRet  = fromIntegral $ L.length progFacRecr - 1

progInput = register (False, 0) $ register (False, 0) $ register (True, 3) $ register (True, 4) $ register (True, 5) $ signal (False, 0)
progIO = [
    Arith Id iReg 0 r7
    , Jump CR 2
    , Jump UR (-2)

    , Load (RImm 2)  r8  -- r8 := 2
    , Arith Add pcreg r8 jmpreg -- jmpreg := pcreg + 2
    , Jump UA facIterAddr   -- call facIter
    , Arith Id r8 0 oReg
    , EndProg
    
    , Load  (RImm 1) r8     -- r8 = 1
    , Arith Eq       r7 zeroreg r9  
    , Jump  CA       facIterRet 
    , Arith Mul      r8 r7 r8
    , Arith Decr     r7 r7 r7
    , Jump  UR       (-4)
    , Jump  Back     0 -- return
    ]
    where facIterRet  = fromIntegral $ L.length progIO - 1
          facIterAddr = 1 + (fromIntegral $ L.length $ L.takeWhile (/= EndProg) progIO)


progPointer = [
    Store (MImm 3) (ImmAdr 3)
    , Load (RImm 3) r7 --
    , Load (RPtr r7) r8  -- r8 = 3 now
    , Arith Add r8 r8 r8 -- r8 = 4 now
    , Arith Incr r7 0 r7 -- r7 = 4 now
    , Store (MReg r8) (RegPtr r7)
    , Load (RPtr r7) oReg
    , EndProg
    ]
