module Test.Main where

import Data.Tuple
import Data.Maybe
import Data.Array (zipWith, length, modifyAt, deleteAt, (..), (!!))

import Debug.Trace

import Control.Functor (($>))
import Control.Monad.Eff

import DOM

import Data.Hashable

import Halogen
import Halogen.Signal

import qualified Halogen.Mixin.UndoRedo as U
import qualified Halogen.Mixin.Hashed as Hash

import qualified Halogen.HTML as H
import qualified Halogen.HTML.Attributes as A
import qualified Halogen.HTML.Events as A
import qualified Halogen.HTML.Events.Forms as A
import qualified Halogen.HTML.Events.Handler as E

import qualified Halogen.Themes.Bootstrap3 as B
import qualified Halogen.Themes.Bootstrap3.InputGroup as BI

foreign import appendToBody
  "function appendToBody(node) {\
  \  return function() {\
  \    document.body.appendChild(node);\
  \  };\
  \}" :: forall eff. Node -> Eff (dom :: DOM | eff) Node

newtype Task = Task { description :: String, completed :: Boolean }

instance eqTask :: Eq Task where
  (==) (Task t1) (Task t2) = t1.description == t2.description && t1.completed == t2.completed
  (/=) (Task t1) (Task t2) = t1.description /= t2.description || t1.completed /= t2.completed
    
instance hashableTask :: Hashable Task where
  hash (Task t) = hash t.description <> hash t.completed    
  
-- | The state of the application
data State = State [Task]

instance eqState :: Eq State where
  (==) (State ts1) (State ts2) = ts1 == ts2
  (/=) (State ts1) (State ts2) = ts1 /= ts2
    
instance hashableState :: Hashable State where
  hash (State ts) = hash ts

-- | Inputs to the state machine
data Input 
  = NewTask
  | UpdateDescription Number String
  | MarkCompleted Number Boolean
  | RemoveTask Number
  | Undo
  | Redo
  
instance inputSupportsUndoRedo :: U.SupportsUndoRedo Input where
  fromUndoRedo U.Undo = Undo
  fromUndoRedo U.Redo = Redo
  toUndoRedo Undo = Just U.Undo
  toUndoRedo Redo = Just U.Redo
  toUndoRedo _ = Nothing

-- | The UI is a state machine, consuming inputs, and generating HTML documents which in turn, generate new inputs
ui :: forall eff a. SF1 Input (H.HTML a Input)
ui = Hash.withHash view <$> stateful (U.undoRedoState (State [])) (U.withUndoRedo update)
  where
  view :: U.UndoRedoState State -> H.HTML a Input
  view st = 
    case U.getState st of
      State ts ->
        H.div (A.class_ B.container)
              [ H.h1 (A.id_ "header") [ H.text "todo list" ]
              , toolbar st
              , tasks ts
              ]
              
  toolbar :: forall st. U.UndoRedoState st -> H.HTML a Input
  toolbar st = H.p (A.class_ B.btnGroup)
                   [ H.button ( A.classes [ B.btn, B.btnPrimary ]
                                <> A.onclick (\_ -> pure NewTask) )
                              [ H.text "New Task" ]
                   , H.button ( A.class_ B.btn
                                <> A.enabled (U.canUndo st)
                                <> A.onclick (\_ -> pure Undo) )
                              [ H.text "Undo" ]
                   , H.button ( A.class_ B.btn
                                <> A.enabled (U.canRedo st)
                                <> A.onclick (\_ -> pure Redo) )
                              [ H.text "Redo" ]
                   ]
           
  tasks :: [Task] -> H.HTML a Input
  tasks ts = H.table (A.classes [ B.table, B.tableStriped ]) 
                     (zipWith task ts (0 .. length ts))
                  
              
  task :: Task -> Number -> H.HTML a Input
  task (Task task) index =
    BI.inputGroup 
      (Just (H.input ( A.class_ B.checkbox
                       <> A.type_ "checkbox"
                       <> A.checked task.completed
                       <> A.title "Mark as completed"
                       <> A.onChecked (pure <<< MarkCompleted index) )
                     []))
      (H.input ( A.classes [ B.formControl ]
                 <> A.placeholder "Description"
                 <> A.onValueChanged (pure <<< UpdateDescription index)
                 <> A.value task.description )
               [])
      (Just (H.button ( A.classes [ B.btn, B.btnDefault ]
                        <> A.title "Remove task"
                        <> A.onclick (\_ -> pure $ RemoveTask index) )
                      [ H.text "✖" ]))

  update :: State -> Input -> State
  update (State ts) NewTask = State (ts ++ [Task { description: "", completed: false }])
  update (State ts) (UpdateDescription i description) = State $ modifyAt i (\(Task t) -> Task (t { description = description })) ts
  update (State ts) (MarkCompleted i completed) = State $ modifyAt i (\(Task t) -> Task (t { completed = completed })) ts
  update (State ts) (RemoveTask i) = State $ deleteAt i 1 ts
  
main = do
  node <- runUI ui
  appendToBody node
