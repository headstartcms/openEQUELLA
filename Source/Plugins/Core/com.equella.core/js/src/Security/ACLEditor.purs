module Security.ACLEditor where 


import Prelude hiding (div)

import Control.Monad.Aff.Console (log)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.IOEffFn (IOFn1, mkIOFn1, runIOFn1)
import Control.Monad.Maybe.Trans (MaybeT(..), runMaybeT)
import Control.Monad.State (State, execState, get, gets)
import Control.Monad.Trans.Class (lift)
import Control.MonadZero (guard)
import Data.Argonaut (decodeJson, encodeJson)
import Data.Array (deleteAt, fold, foldl, foldr, fromFoldable, index, insertAt, mapWithIndex, reverse, snoc, (!!))
import Data.Bifunctor (bimap)
import Data.Either (Either(..), either)
import Data.Lens (Lens', Prism', Traversal', _Left, _Right, assign, filtered, foldMapOf, lens', modifying, over, preview, previewOn, prism', set, traversed, use, view, (^?))
import Data.Lens.Index (ix)
import Data.Lens.Iso.Newtype (_Newtype)
import Data.Lens.Record (prop)
import Data.List (List(..), uncons, (:))
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Newtype (class Newtype)
import Data.Nullable (toMaybe)
import Data.Symbol (SProxy(..))
import Data.Traversable (traverse)
import Data.Tuple (Tuple(Tuple), fst)
import Debug.Trace (spy, traceAny, traceAnyA)
import Dispatcher (DispatchEff(DispatchEff))
import Dispatcher.React (ReactProps(ReactProps), ReactState(ReactState), createLifecycleComponent, createLifecycleComponent', didMount, getProps, getState, modifyState)
import DragNDrop.Beautiful (DropResult, dragDropContext, draggable, droppable)
import EQUELLA.Environment (baseUrl)
import MaterialUI.Button (button, raised)
import MaterialUI.ButtonBase (onClick)
import MaterialUI.Color (primary)
import MaterialUI.Icon (icon_)
import MaterialUI.IconButton (iconButton)
import MaterialUI.Input (onChange)
import MaterialUI.List (disablePadding, list)
import MaterialUI.ListItem (button) as P
import MaterialUI.ListItem (listItem)
import MaterialUI.ListItemIcon (listItemIcon_)
import MaterialUI.ListItemSecondaryAction (listItemSecondaryAction_)
import MaterialUI.ListItemText (listItemText)
import MaterialUI.ListItemText (primary, secondary) as P
import MaterialUI.MenuItem (menuItem)
import MaterialUI.Paper (paper)
import MaterialUI.PropTypes (handle)
import MaterialUI.Properties (className, color, component, mkProp, style, variant)
import MaterialUI.Select (select, value)
import MaterialUI.Styles (withStyles)
import MaterialUI.TextStyle (subheading)
import MaterialUI.Typography (error, typography)
import Network.HTTP.Affjax (get, put_) as A
import React (ReactElement, createFactory)
import React.DOM (div, div', text)
import React.DOM.Props (className, ref, style) as P
import Security.Expressions (Expression(..)) as SE
import Security.Expressions (class ExpressionDecode, AccessEntry(AccessEntry), Expression, ExpressionTerm(..), OpType(OR, AND), TargetList(TargetList), collapseOps, entryToTargetList, expressionText, parseEntry, textForExpression, textForTerm, traverseExpr)
import Template (template')
import UserLookup (GroupDetails(..), RoleDetails(..), UserDetails(..), UserGroupRoles(..), lookupUsers)

data ResolvedTerm = Already ExpressionTerm | ResolvedUser UserDetails | ResolvedGroup GroupDetails | ResolvedRole RoleDetails
derive instance eqRT :: Eq ResolvedTerm 

data ResolvedExpression = Term ResolvedTerm Boolean | Op OpType (Array ResolvedExpression) Boolean

derive instance eqRE :: Eq ResolvedExpression

instance rexDecode :: ExpressionDecode ResolvedExpression ResolvedTerm where 
  decodeExpr (Term rt n) = Tuple n (Left $ rt)
  decodeExpr (Op op exprs n) = Tuple n (Right {op,exprs})
  fromTerm = Term 
  fromOp = Op

data ExprType = Unresolved Expression | Resolved ResolvedExpression | EmptyExpr

derive instance etEQ :: Eq ExprType

mapResolved :: (ResolvedExpression -> ExprType) -> ExprType -> ExprType 
mapResolved f (Resolved r) = f r
mapResolved _ o = o


type ResolveEntryR = {priv::String, granted::Boolean, override::Boolean, expr :: ExprType}
newtype ResolvedEntry = ResolvedEntry ResolveEntryR

derive instance ntRE :: Newtype ResolvedEntry _
derive instance eqREnt :: Eq ResolvedEntry 


data Command = Resolve | HandleDrop DropResult | SelectEntry Int | SaveChanges | Undo | DeleteExpr Int | ChangeOp Int String

type MyState = {
  acls :: Array ResolvedEntry,
  selectedIndex :: Maybe Int,
  terms :: Array ResolvedTerm,
  undoList :: List (Tuple (Maybe Int) (Array ResolvedEntry))
}

aclEditor :: {acls :: Array AccessEntry, applyChanges :: IOFn1 (Array AccessEntry) Unit } -> ReactElement
aclEditor = createFactory $ withStyles styles $ createLifecycleComponent' (didMount Resolve) initialState render eval
  where 
  _resolvedExpr :: Prism' ExprType ResolvedExpression
  _resolvedExpr = prism' Resolved $ case _ of 
    Resolved r -> Just r
    _ -> Nothing
  _unresolvedExpr :: Prism' ExprType Expression
  _unresolvedExpr = prism' Unresolved $ case _ of 
    Unresolved r -> Just r
    _ -> Nothing

  _id = prop (SProxy :: SProxy "id")
  _expr = prop (SProxy :: SProxy "expr")
  _terms = prop (SProxy :: SProxy "terms")
  _acls = prop (SProxy :: SProxy "acls")
  _undoList = prop (SProxy :: SProxy "undoList")
  _selectedIndex = prop (SProxy :: SProxy "selectedIndex")
  _ResolvedEntry :: Lens' ResolvedEntry ResolveEntryR
  _ResolvedEntry = _Newtype
  currentExpr :: Int -> Traversal' (Array ResolvedEntry) ExprType
  currentExpr ind = ix ind <<< _ResolvedEntry <<< _expr 

  styles theme = {
    buttons: {
      margin: theme.spacing.unit
    },
    accessEntry: {
      display: "flex"
    },
    entryList: {
      overflow: "auto",
      marginRight: theme.spacing.unit,
      flexShrink: 0,
      width: "40%"
    },
    overallPanel: {
      display: "flex",
      flexDirection: "column",
      height: "100%"
    }, 
    editorPanels: {
      display: "flex",
      height: "100%"
    },
    currentEntryPanel: {
      width: "30%",
      flexShrink: 0,
      overflow: "auto",
      display: "flex",
      marginRight: theme.spacing.unit,
      marginLeft: theme.spacing.unit
    },
    commonPanel: {
      width: "30%",
      overflow: "auto"
    },
    currentEntryDrop: {
      flexGrow: 1,
      padding: theme.spacing.unit * 2
    }, 
    opDrop: {
      height: 48
    }, 
    selectedEntry: {
      backgroundColor: theme.palette.action.selected
    }
  }

  initialState (ReactProps {acls}) = ReactState {
      acls:markForResolve <$> acls, 
      terms: commonTerms,
      selectedIndex: Nothing, 
      undoList: Nil
    }
    where  
    markForResolve (AccessEntry {priv,granted,override,expr}) = ResolvedEntry {priv,granted,override, expr: Unresolved expr}

  render {acls,terms,selectedIndex} 
      (ReactProps {classes}) (DispatchEff d) = 
    let expressionM = selectedIndex >>= \i -> previewOn acls (currentExpr i)
    in dragDropContext { onDragEnd: mkIOFn1 (d HandleDrop) } [ 
      div [P.className classes.overallPanel] [
        div [P.className classes.editorPanels] [
          paper [className classes.entryList ] [
            droppable {droppableId:"list", "type": "entry"} \p _ -> 
              div [P.ref p.innerRef, p.droppableProps ] [
                list [disablePadding true] $
                  mapWithIndex entryRow acls,
                p.placeholder
              ]
          ],
          paper [className classes.currentEntryPanel ] $ expressionM # maybe [] expressionContents,
          paper [className classes.commonPanel ] [
            droppable {droppableId:"common"} \p _ -> 
              div [P.ref p.innerRef, p.droppableProps] [
                list [disablePadding true] $
                  mapWithIndex (commonExpr "common" [] []) terms,
                p.placeholder
              ]
          ]
        ],
        div [P.className classes.buttons] [ 
          button [variant raised, color primary, onClick $ handle $ d \_ -> SaveChanges ] [ text "Save" ],
          button [variant raised, onClick $ handle $ d \_ -> Undo ] [ text "Undo" ]
        ]
    ]
  ]
    where 
    expressionContents exprType =                 
      let exprEntries = case exprType of 
            Resolved expression -> [ list [disablePadding true] $ mapWithIndex (#) $ fromFoldable $ makeExpression 0 expression Nil ]
            _ -> []
      in  [
        droppable {droppableId:"currentEntry"} \p _ -> 
          div [P.ref p.innerRef, p.droppableProps, P.className classes.currentEntryDrop] $ snoc exprEntries p.placeholder
      ]

    stdDrag pfx content i = draggable {draggableId: pfx <> show i, index:i} \p _ -> 
      div' [
        div [P.ref p.innerRef, p.draggableProps, p.dragHandleProps] [
          content i
        ], 
        p.placeholder
      ]
    makeExpression indent expr l = case expr of 
      Term t _ -> Cons (\i -> commonExpr "term" [style { marginLeft: indentPixels }] [
        listItemSecondaryAction_ [ 
            iconButton [ onClick $ handle $ d \_ -> DeleteExpr i ] [ 
              icon_ [ text "delete" ] 
            ] 
        ]
      ] i t) l
      Op op exprs _ -> (Cons $ opEntry op ) (foldr (makeExpression (indent + 1)) l exprs)
      where 
      opEntry op = stdDrag "op" $ \i -> div [ P.className classes.opDrop, P.style {marginLeft: indentPixels} ] [ 
        select [value $ opValue op, onChange $ handle $ d $ \e -> ChangeOp i e.target.value ] opItems
      ]
      indentPixels = indent * 16
    

    commonExpr pfx props actions i rt = stdDrag pfx (\_ -> 
      listItem props $ [ 
        listItemIcon_ [ 
          icon_ [ 
            text $ iconNameForResolved rt 
          ] 
        ], 
        listItemText [ P.primary $ textForResolved rt ]
      ] <> actions) i
    entryRow i (ResolvedEntry {granted,priv,expr}) = draggable {
        "type": "entry", draggableId: "entry" <> show i, index:i} \p _ -> 
      div' [
        div [P.ref p.innerRef, p.draggableProps, p.dragHandleProps] [
          let p = guard (eq i <$> selectedIndex # fromMaybe false) $> className classes.selectedEntry
          in listItem (p <> [ P.button true, onClick $ handle $ d \_ -> SelectEntry i]) [ 
            listItemText [ P.primary $ text priv, P.secondary $ textForExprType expr ]
          ]
        ],
        p.placeholder
      ]

    textForExprType (Unresolved std) = text $ textForExpression std 
    textForExprType (Resolved rexpr) = text $ expressionText textForResolved rexpr
    textForExprType EmptyExpr = typography [component "span", color error] [ text "* Required" ]
  
  textForResolved :: ResolvedTerm -> String
  textForResolved = case _ of 
    Already std -> textForTerm std
    ResolvedUser (UserDetails {username}) -> username
    ResolvedGroup (GroupDetails {name}) -> name
    ResolvedRole (RoleDetails {name}) -> name

  iconNameForResolved = case _ of 
    Already std -> iconNameForTerm std
    ResolvedUser (UserDetails _) -> iconNameForTerm (User "")
    ResolvedGroup (GroupDetails _) -> iconNameForTerm (Group "")
    ResolvedRole (RoleDetails _) -> iconNameForTerm (Role "")

  iconNameForTerm = case _ of 
   Group _ -> "people"
   Role _ -> "people"
   User _ -> "person"
   Everyone -> "public"
   LoggedInUsers -> "face"
   Ip _ -> "dns"
   Guests -> "person_outline"
   Owner -> "account_box"
   Referrer _ -> "http"
   ShareSecretToken _ -> "apps"
    
  toQuery :: Expression -> UserGroupRoles String String String
  toQuery = traverseExpr (\t _ -> UserGroupRoles (termQuery t)) \{exprs} _ -> fold exprs
    where
    termQuery (User uid) = {users:[uid],groups:[], roles:[]}
    termQuery (Group gid) = {users:[], groups:[gid], roles:[]}
    termQuery (Role rid) = {users:[], groups:[], roles:[rid]}
    termQuery _ = {users:[],groups:[],roles:[]}

  reorder :: forall a. Int -> Int -> Array a -> Array a 
  reorder sourceIndex destIndex a = fromMaybe a do
     let newdest = if destIndex < 1 then 0 else destIndex
     o <- index a sourceIndex
     d <- deleteAt sourceIndex a
     insertAt newdest o d

  deleteFrom :: Int -> ResolvedExpression -> Either Int (Tuple (Maybe ResolvedExpression) ResolvedExpression)
  deleteFrom i e = if i == 0 then pure (Tuple Nothing e) else case e of 
    Term _ _ -> Left $ (i - 1)
    origOp@(Op op exprs notted) -> 
      let foldOp (Left {i,l}) e = deleteFrom i e # bimap {i: _, l: Cons e l} (\(Tuple m e) -> Tuple (maybe l (flip Cons l) m) e)
          foldOp (Right (Tuple l me)) e = Right $ Tuple (Cons e l) me
          mkOp l e = Right $ Tuple (Just $ (Op op (reverse $ fromFoldable $ l) notted)) e
      in case foldl foldOp (Left {i: i - 1, l:Nil}) exprs of 
        Left {i:0,l} -> mkOp l origOp
        Left {i} -> Left $ i - 1
        Right (Tuple r me) -> mkOp r me

  insertInto :: ResolvedExpression -> Int -> ResolvedExpression -> ResolvedExpression
  insertInto nt i e = let 
    insertOrPos :: Int -> ResolvedExpression -> Either Int (List ResolvedExpression)
    insertOrPos 0 e = pure $ e : nt : Nil
    insertOrPos i e = case e of  
        t1@(Term _ _) -> Left (i - 1)
        (Op op exprs notted) -> 
          let foldOp (Left {i,l}) e = insertOrPos i e # bimap {i: _, l: Cons e l} (\nl -> nl <> l)
              foldOp o e = map (Cons e) o
              mkOp l = Right $ (Op op (reverse $ fromFoldable $ l) notted) : Nil
          in case foldl foldOp (Left {i:i - 1,l:Nil}) exprs of  
              Left {i:0,l} -> mkOp $ nt : l
              Left {i} -> Left $ i - 1
              Right r -> mkOp r
    in case insertOrPos i e of 
      Left 0 -> Op AND [e, nt] false
      Right (r : n : Nil) -> Op AND [n, r] false
      Right (r : Nil) -> r
      a -> e
  
  addUndo :: (Array ResolvedEntry -> Array ResolvedEntry) -> State MyState Unit
  addUndo f = do 
    oldEntries <- use _acls
    indx <- use _selectedIndex
    let newEntries = f oldEntries
    if newEntries == oldEntries then pure unit else do 
      modifying _undoList $ Cons (Tuple indx oldEntries)
      assign _acls newEntries

  modifyResolved :: (ResolvedExpression -> ResolvedExpression) -> State MyState Unit
  modifyResolved f = modifyExpression (mapResolved (f >>> Resolved))

  modifyExpression :: (ExprType -> ExprType) -> State MyState Unit
  modifyExpression f = void $ runMaybeT do 
    selectedIndex <- MaybeT (gets _.selectedIndex)
    let curExpr :: Traversal' (Array ResolvedEntry) ExprType
        curExpr = ix selectedIndex <<< _ResolvedEntry <<< _expr
    oldEx <- MaybeT $ (preview (_acls <<< curExpr) <$> get)
    let newEx = mapResolved (collapseOps >>> maybe EmptyExpr Resolved) $ f oldEx
    guard (oldEx /= newEx)
    lift $ addUndo $ set curExpr newEx

  copyToCurrent :: Int -> Int -> State MyState Unit
  copyToCurrent srcIx destIx = do 
    let insertNew t = case _ of 
         Resolved r -> Resolved $ insertInto (Term t false) destIx r
         EmptyExpr -> Resolved (Term t false)
         o -> o 
    ce <- use _terms
    ce !! srcIx # maybe (pure unit) (modifyExpression <<< insertNew)  

  eval (ChangeOp ind op) = do 
    let editOp (Op _ exprs n) | Just newOp <- valToOpType op = Op newOp exprs n 
        editOp o = o
        changeOp r (Right (Tuple _ e)) = editOp e
        changeOp r _ = r
    modifyState $ execState $ modifyResolved (\r -> changeOp r $ deleteFrom ind r)
  eval (DeleteExpr i) = do 
    let delExpr e@(Resolved r) = either (const e) (fst >>> maybe EmptyExpr Resolved) $ deleteFrom i r
        delExpr o = o
    modifyState $ execState $ modifyExpression delExpr
  eval Undo = do 
    modifyState $ execState do 
      undos <- use _undoList
      uncons undos # maybe (pure unit) \{head:Tuple ix list, tail} -> do 
        assign _undoList tail
        assign _acls list
        assign _selectedIndex ix

  eval SaveChanges = do 
    {applyChanges} <- getProps
    {acls} <- getState
    (traverse backToAccessEntry acls) # maybe (pure unit) (liftEff <<< runIOFn1 applyChanges)

  eval (SelectEntry entry) = do 
    modifyState $ execState $ assign _selectedIndex $ Just entry

  eval Resolve = do
    {acls} <- getState
    let ugr = foldMapOf (traversed <<< (_ResolvedEntry <<< _expr <<< _unresolvedExpr)) toQuery acls
    (UserGroupRoles {users,groups,roles}) <- lift $ lookupUsers ugr
    let filterById :: forall a r. Newtype a {id::String|r} => Array a -> String -> Maybe a
        filterById arr uid = arr ^? (traversed <<< (filtered $ view ((_Newtype :: Lens' a {id::String|r}) <<< _id) >>> eq uid))
        resolveTerm = case _ of 
          (User uid) | Just ud <- filterById users uid -> ResolvedUser ud
          (Group gid) | Just gd <- filterById groups gid -> ResolvedGroup gd
          (Role rid) | Just rd <- filterById roles rid -> ResolvedRole rd
          (User uid) -> ResolvedUser (UserDetails {id:uid, username: "Unknown user with id " <> uid, firstName:"", lastName:"", email:Nothing})
          other -> Already other
        resolve = traverseExpr (\t n -> Term (resolveTerm t) n) \{op,exprs} n -> Op op exprs n
    modifyState $ over (_acls <<< traversed <<< _ResolvedEntry <<< _expr) case _ of 
      Unresolved u -> Resolved (resolve u)
      o -> o

  eval (HandleDrop dr@{source:{index:sourceIndex, droppableId:sourceId}}) | Just {index:destIndex,droppableId:destId} <- toMaybe dr.destination = 
    let handleDrop sId dId | sId == dId && sourceIndex /= destIndex = 
          let reorderCurrent = modifyResolved $ (\e -> case deleteFrom sourceIndex e of 
                  Right (Tuple (Just ne) re)-> insertInto re destIndex ne
                  _ -> e
                )
              l = case sId of 
                    "list" -> addUndo (reorder sourceIndex destIndex)
                    "currentEntry" -> reorderCurrent
                    _       -> modifying _terms (reorder sourceIndex destIndex)
          in modifyState $ execState l
        handleDrop "common" "currentEntry" = do 
          modifyState $ execState $ copyToCurrent sourceIndex destIndex 
        handleDrop _ _ = pure unit
        
    in handleDrop sourceId destId
  eval (HandleDrop _) = pure unit


-- sampleEntries = [
--     AccessEntry {granted:true, priv: "DISCOVER_ITEM", override:false, term: User "dasd"}, -- renderData.user.id},
--     AccessEntry {granted:true, priv: "DISCOVER_ITEM", override:false, term: User "doolse"},
--     AccessEntry {granted:true, priv: "DISCOVER_ITEM", override:false, term: Group "dff74147-98b4-34d3-e193-d3eeada6d836"},
--     AccessEntry {granted:true, priv: "VIEW_ITEM", override:false, term: User "somebody"}
-- ]

commonTerms = [
  Already Everyone,
  Already LoggedInUsers, 
  Already Guests,
  Already Owner,
  Already (Role "TestRole"),
  Already (Group "TestGroup"),
  Already (User "TestUser"),
  Already (Ip "1.2.3.5/24"),
  Already (Referrer "http://*"),
  Already (ShareSecretToken "moodle")
]

opValue :: OpType -> String 
opValue AND = "and"
opValue OR = "or"

valToOpType :: String -> Maybe OpType 
valToOpType = case _ of 
  "and" -> Just AND 
  "or" -> Just OR 
  _ -> Nothing 

opName :: OpType -> String
opName AND = "Match all"
opName OR = "Match one"

opItems :: Array ReactElement
opItems = mkOp <$> [ AND, OR ]
  where 
  mkOp o = menuItem [mkProp "value" $ opValue o] [ text $ opName o ]

backToAccessEntry :: ResolvedEntry -> Maybe AccessEntry
backToAccessEntry (ResolvedEntry {priv,granted,override,expr}) = AccessEntry <<< {priv,granted,override,expr: _} <$> convertExpr expr
  where 
  convertExpr (Unresolved e) = pure $ e
  convertExpr (Resolved re) = pure $ convertRE re
  convertExpr _ = Nothing
  convertRE (Term rt b) = 
    let seterm = case rt of 
          Already t -> t 
          ResolvedUser (UserDetails {id}) -> User id  
          ResolvedGroup (GroupDetails {id}) -> Group id  
          ResolvedRole (RoleDetails {id}) -> Role id
    in SE.Term seterm b
  convertRE (Op o exprs n) = SE.Op o (convertRE <$> exprs) n

data TestCommand = Init | SaveIt (Array AccessEntry)

testEditor :: ReactElement
testEditor = createFactory (createLifecycleComponent (didMount Init) {acls:Nothing} render eval) {}
  where 
  render {acls} (DispatchEff d) = 
    acls # maybe (div' []) \entries -> 
      template' {fixedViewPort:true, menuExtra: [], 
        mainContent: aclEditor {acls:entries, applyChanges: mkIOFn1 $ d SaveIt}, 
        title: "TEST", titleExtra:Nothing }
  eval Init = do 
    r <- lift $ A.get (baseUrl <> "api/acl")
    decodeJson r.response # either (lift <<< log) 
      \(TargetList {entries}) -> do 
        traverse parseEntry entries # either traceAnyA \entries -> modifyState _ {acls = Just entries}
    pure unit
  eval (SaveIt entries) = do 
    r <- lift $ A.put_ (baseUrl <> "api/acl") (encodeJson (TargetList {entries: entryToTargetList <$> entries}))
    pure unit
