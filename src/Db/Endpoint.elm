module Db.Endpoint exposing
    ( public
    , user
    )

import Postgres.Http exposing (Endpoint)


user : Endpoint
user =
    Endpoint "/_q/" Nothing


public : Endpoint
public =
    Endpoint "/_pq/" Nothing
