{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Types where

import qualified LexCAL as C
import qualified ParCAL as C
import qualified SkelCAL as C
import qualified PrintCAL as C
import qualified AbsCAL as C
import qualified AbsRIPL as R
import AstMappings
import Data.Int
import Data.Word

import Data.Map (Map)
import qualified Data.Map as Map

---------------------------------------------------
-- RIPL data types
data VarNode = VarNode
  { idIdx :: !Int -- ^ when this is one of 2+ LHS idents
  , idLHS :: !String -- ^ LHS ident
  , varRHS :: !VarRHS -- ^ RHS, a skeleton or function call
  , direction :: !(Maybe Direction) -- ^ either columnwise or rowwise
  , dim :: !(Maybe Dimension) -- ^ width and height of LHS image
  , maxBitWidth :: !(Maybe Int) -- ^ upper bound on positive bitwidth
  , isInput :: !Bool -- ^ is the RHS imread(..)
  , isOutput :: !Bool -- ^ is the LHS an argument to imwrite(..)
  , lineNum :: !Int -- ^ line number
  } deriving (Show, Eq)

data VarRHS
  = SkelRHS R.AssignSkelRHS
  | ImReadRHS Integer
              Integer
  | ImWriteRHS R.Ident
  deriving (Show, Eq)

type ImplicitDataflow = Map R.Ident VarNode

data Direction
  = Rowwise
  | Columnwise
  deriving (Eq, Ord, Show)

type ImageDimensions = Map.Map R.Ident Dimension

data Dimension = Dimension
  { w :: Integer -- ^ image width, inferred.
  , h :: Integer -- ^ image height, inferred.
  } deriving (Show, Eq)

type ChunkSize = Integer

---------------------------------------------------
-- Actor and network types
data CalProject = CalProject
  { actors :: [Actor]
  , connections :: Connections
  }

data Actor
  = RiplActor { package :: String
             ,  actorName :: String
             ,  actorAST :: C.Actor}
  | RiplUnit { package :: String
            ,  unitName :: String
            ,  unitAST :: C.Unit}
  | IncludeActor { package :: String
                ,  actorName :: String}
  deriving (Show, Eq)

type Connections = [Connection]

data PortType
  = In
  | Out
  deriving (Show, Eq)

data EndPoint
  = Actor { epName :: String
         ,  actorPort :: String}
  | Port { portType :: PortType}
  | Node { networkName :: String
        ,  networkPort :: String}
  deriving (Show, Eq)

data Connection = Connection
  { src :: EndPoint
  , dest :: EndPoint
  } deriving (Show, Eq)

---------------------------------------------------
-- bitwidths
data CalBitWidth
  = CalUInt8
  | CalUInt16
  | CalUInt32
  deriving (Eq, Show)

calTypeFromCalBWUInt bitWidth =
  case bitWidth of
    CalUInt8 -> 8
    CalUInt16 -> 16
    CalUInt32 -> 32

calTypeFromCalBW bitWidth =
  case bitWidth of
    CalUInt8 ->
      C.TypParam
        C.TUint
        [C.TypeAttrSizeDf (C.LitExpCons (C.IntLitExpr (C.IntegerLit 8)))]
    CalUInt16 ->
      C.TypParam
        C.TUint
        [C.TypeAttrSizeDf (C.LitExpCons (C.IntLitExpr (C.IntegerLit 16)))]
    CalUInt32 ->
      C.TypParam
        C.TUint
        [C.TypeAttrSizeDf (C.LitExpCons (C.IntLitExpr (C.IntegerLit 32)))]

correctBW :: Int -> CalBitWidth
correctBW i =
  if i < 0
    then error "RIPL does not support negative integers"
    else correctBWPositive
  where
    correctBWPositive :: CalBitWidth
    correctBWPositive
      | fromIntegral i <= value8 = CalUInt8
      | fromIntegral i <= value16 = CalUInt16
      | fromIntegral i <= value32 = CalUInt32
      | otherwise = CalUInt32 -- just hope for the best that the worst case does not happen
      where
        (value8 :: Data.Int.Int32) = fromIntegral (maxBound :: Data.Word.Word8)
        (value16 :: Data.Int.Int32) =
          fromIntegral (maxBound :: Data.Word.Word16)
        (value32 :: Data.Int.Int32) =
          fromIntegral (maxBound :: Data.Word.Word32)