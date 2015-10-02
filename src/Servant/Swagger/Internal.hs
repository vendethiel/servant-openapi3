{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE OverloadedLists            #-}
------------------------------------------------------------------------------
module Servant.Swagger.Internal where
------------------------------------------------------------------------------
import           Control.Arrow
import           Control.Lens hiding ((.=))
import           Control.Monad
import           Data.Aeson
import           Data.Maybe
import           Data.Hashable
import           Data.Monoid
import           Data.Proxy
import qualified Data.ByteString.Lazy.Char8 as BC
import           Data.Char
import qualified Data.HashMap.Strict as H
import           Data.Text (Text)
import qualified Data.Text as T
import           GHC.Generics
------------------------------------------------------------------------------
main :: IO ()
main = 
  BC.writeFile "foo.json" $ encode $ SwaggerAPI {
       _swaggerInfo    = SwaggerInfo (APITitle "foo") (APIVersion "2.0")
                            (APIDescription "Hooray") Nothing
    ,  _swaggerSchemes = Just [ Http ]
    ,  _swaggerPaths   = [(PathName "/api/dogs", ps)]
    ,  _swaggerDefinitions = []
    }
  where
    ps = SwaggerPath [(Get, xs)]
    xs = Path {
           _params = [
              Param Query "foo" (Just StringSwagParam) Nothing "Foo query param" True True Nothing
           ]
         , _summary   = "Get some dogs"
         , _responses = [(200, Response "success" Nothing)]
         , _produces  = [ JSON, HTML ]
         , _consumes  = [ JSON, HTML ]
         }

defSwaggerInfo :: SwaggerInfo
defSwaggerInfo = SwaggerInfo (APITitle mempty) (APIVersion "2.0") (APIDescription mempty) Nothing

newtype APIDescription =  APIDescription { _unApiDesc :: Text }
   deriving (Show, Eq, ToJSON)

newtype APITermsOfService = APITermsOfService { _unAPITermsOfService :: Text }
   deriving (Show, Eq, ToJSON)

data Response = Response {
     _description :: Text
   , _responseModelName :: Maybe ModelName
--  , _reponseHeaders :: Maybe Header
  } deriving (Show, Eq)

data SwaggerAPI = SwaggerAPI {
     _swaggerInfo  :: SwaggerInfo
  ,  _swaggerSchemes :: Maybe [Scheme]
  ,  _swaggerPaths :: H.HashMap PathName SwaggerPath
  ,  _swaggerDefinitions  :: H.HashMap ModelName SwaggerModel
  } deriving Show

data SwaggerInfo = SwaggerInfo {
    _swaggerInfoTitle      :: APITitle    
  , _swaggerVersion        :: APIVersion
  , _swaggerAPIDescription :: APIDescription
  , _license               :: Maybe APILicense
  } deriving (Show, Eq)

data APILicense = APILicense {
     _licenseName :: Text
  ,  _licenseUrl  :: Maybe Text
  } deriving (Show, Eq)

data SwaggerPath = SwaggerPath {
     _paths :: H.HashMap Verb Path
  } deriving Show

instance Monoid SwaggerPath where
  mempty = SwaggerPath H.empty
  SwaggerPath a `mappend` SwaggerPath b =
    SwaggerPath ( a <> b )

instance ToJSON APILicense where
  toJSON APILicense{..} =
    object [ "name" .= _licenseName
           , "url"  .= _licenseUrl
           ]

data Verb = Post | Get | Put | Options | Head | Delete | Patch
  deriving (Show, Eq, Read, Generic)

instance Hashable Verb where hash = hash . show

data Path = Path {
     _summary   :: Text     
   , _params    :: [Param]
   , _responses :: H.HashMap Code Response
   , _produces  :: [ContentType]
   , _consumes  :: [ContentType]
  } deriving Show

newtype Code = Code Int
  deriving (Show, Eq, Ord, ToJSON, Hashable, Num)

data SwaggerParamType =
    StringSwagParam
  | NumberSwagParam
  | IntegerSwagParam
  | BooleanSwagParam
  | ArraySwagParam
  | FileSwagParam
  deriving Show

instance ToJSON SwaggerParamType where
  toJSON StringSwagParam = String "string"
  toJSON NumberSwagParam = String "number"
  toJSON IntegerSwagParam = String "integer"
  toJSON BooleanSwagParam = String "boolean"
  toJSON ArraySwagParam = String "array"
  toJSON FileSwagParam = String "file"

data SwaggerType =
    IntegerSwag
  | LongSwag
  | FloatSwag
  | DoubleSwag
  | StringSwag
  | ByteSwag
  | BinarySwag
  | BooleanSwag
  | DateSwag
  | DateTimeSwag
  | PasswordSwag
  deriving (Show, Eq)

instance ToJSON SwaggerType where
  toJSON x =
    let f typ format = object $ [ "type" .= (typ :: Text) ] ++
               if isJust format
                 then [ "format" .= ((fromJust format) :: Text) ]
                 else []
    in case x of
      IntegerSwag -> f "integer" (Just "int32")
      LongSwag -> f "integer" (Just "int64")
      FloatSwag -> f "number" (Just "float")
      DoubleSwag -> f "number" (Just "double")
      StringSwag -> f "string" Nothing
      ByteSwag -> f "string" (Just "byte")
      BinarySwag -> f "string" (Just "binary")
      BooleanSwag -> f "boolean" Nothing
      DateSwag -> f "string" (Just "date")
      DateTimeSwag -> f "string" (Just "date-time")
      PasswordSwag -> f "string" (Just "password")

data ContentType = JSON | HTML | XML | FormUrlEncoded | PlainText | OctetStream  deriving (Show, Eq)
data In = PathUrl | Query | Header | FormData | Body deriving Show
data Scheme = Http | Https | Ws | Wss deriving Show

instance ToJSON ContentType where
  toJSON JSON        = String "application/json"
  toJSON XML         = String "application/xml"
  toJSON FormUrlEncoded = String "application/x-www-form-urlencoded"
  toJSON HTML        = String "text/html"
  toJSON PlainText   = String "text/plain; charset=utf-8"
  toJSON OctetStream = String "application/octet-stream"

instance ToJSON Scheme where
  toJSON Http  = String "http" 
  toJSON Https = String "https" 
  toJSON Ws    = String "ws" 
  toJSON Wss   = String "wss" 

instance ToJSON In where
  toJSON PathUrl  = "path"
  toJSON Query    = "query"
  toJSON Body     = "body"
  toJSON Header   = "header"
  toJSON FormData = "formData"

data Param = Param {
    _in               :: In
  , _name             :: Text
  , _type             :: Maybe SwaggerParamType
  , _items            :: Maybe ItemObject
  , _paramDescription :: Text
  , _allowEmptyValue  :: Bool
  , _required         :: Bool
  , _default          :: Maybe Value
  } deriving Show

data ItemObject = ItemObject {
     _itemsType :: SwaggerParamType
  } deriving Show

newtype APIVersion = APIVersion Text deriving (Show, Eq, ToJSON)
newtype APITitle = APITitle Text deriving (Show, Eq, ToJSON)
newtype PathName = PathName { unPathName :: Text }
  deriving (Show, Eq, Hashable, Monoid)

instance ToJSON PathName where
  toJSON (PathName x) = String (T.toLower x)

newtype ModelName = ModelName { unModelName :: Text } deriving (Show, Eq, Hashable)
newtype Description = Description { unDescription :: Text } deriving (Show, Eq, ToJSON)

class ToSwaggerParamType a where toSwaggerParamType :: Proxy a -> SwaggerParamType

class ToSwaggerDescription a where toSwaggerDescription :: Proxy a -> Text

data SwaggerModel = SwaggerModel {
     _swagModelName :: Maybe ModelName
   , _swagProperties :: [(Text, SwaggerType)]
   , _swagDescription :: Maybe Description
   } deriving Show

instance ToJSON SwaggerModel where
  toJSON SwaggerModel{..} =
    object [
        "type" .= ("object" :: Text)
      , "properties" .= H.fromList _swagProperties
      , "description" .= _swagDescription
    ]

$(makeLenses ''SwaggerModel)

class ToSwaggerModel a where toSwagModel  :: Proxy a -> SwaggerModel

instance ToJSON SwaggerAPI where
  toJSON SwaggerAPI{..} =
    object [
        "swagger"     .= ("2.0" :: Text)
      , "schemes"     .= _swaggerSchemes
      , "info"        .= _swaggerInfo
      , "paths"       .= Object (H.fromList $ map f $ H.toList _swaggerPaths)
      , "definitions" .= Object (H.fromList $ map g $ H.toList _swaggerDefinitions)
      ]
    where
      f (PathName pathName, sp) = (T.toLower pathName, toJSON sp)
      g (ModelName modelName, model) = (modelName, toJSON model)

instance ToJSON SwaggerPath where
  toJSON (SwaggerPath paths) = 
     Object . H.fromList . map f . H.toList $ paths
    where
      f (verb, sp) = (T.toLower $ toTxt verb, toJSON sp)

instance ToJSON Path where
  toJSON Path {..} =
    object [  "parameters" .= _params
            , "responses"  .= (Object . H.fromList . map f . H.toList $ _responses)
            , "produces"   .= _produces 
            , "consumes"   .= _consumes 
            , "summary"    .= _summary  
            ] 
    where f (Code x, resp) = (toTxt x, toJSON resp)
  
instance ToJSON Response where
  toJSON Response {..} = object $ [
      "description" .= _description
    ] ++ maybeModelName
    where
      maybeModelName =
        case _responseModelName of
          Nothing -> []
          Just (ModelName name) -> [
            "schema" .= object [
               "$ref" .= ("#/definitions/" <> name)
             ]
           ]

instance ToJSON Param where
  toJSON Param{..} = 
    object $ [
        "in"          .= _in
      , "name"        .= _name
      , "description" .= _paramDescription
      , "required"    .= _required
      ]  ++ maybeType ++ maybeSchema
    where
      maybeSchema =
        case _in of
          Body -> [ "schema" .= object [
                         "$ref" .= ("#/definitions/" <> _name)
                       ]
                    ]
          _ -> [] 
      maybeType =
        case _type of
          Nothing -> []
          Just pType -> [ "type" .= pType ]

instance ToJSON SwaggerInfo where
  toJSON SwaggerInfo{..} =
    object $ [
        "title"   .= _swaggerInfoTitle
      , "version" .= _swaggerVersion
      , "description" .= _swaggerAPIDescription
      ] ++ (maybe [] (pure .  ("license" .=)) _license)

toTxt :: Show a => a -> Text
toTxt = T.pack . show

data SwagRoute = SwagRoute {
    _routePathName :: PathName 
  , _routeConsumes :: [ContentType]
  , _routeModels   :: H.HashMap ModelName SwaggerModel
  , _routeParams   :: [Param]
  , _routeSwagInfo :: SwaggerInfo
  , _routeSwagSchemes :: Maybe [Scheme]
  } deriving Show

defSwagRoute :: SwagRoute
defSwagRoute = SwagRoute (PathName "") [] [] [] defSwaggerInfo (Just [Http])

$(makeLenses ''SwagRoute)
$(makeLenses ''SwaggerAPI)
$(makeLenses ''SwaggerInfo)
$(makeLenses ''APILicense)