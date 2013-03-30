-module(exapi).

-behaviour(gen_server).

-define(SERVER, ?MODULE).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/2]).
-export([start_sync/0]).
-export([request/1, request/2]).

-record(sref, {sref = "", host = ""}).

start(Host, AuthInfo) ->
    {ok, _Pid} = gen_server:start_link({local, ?SERVER}, ?MODULE, [Host, AuthInfo], []),
    ok.

start_sync() ->
    application:start(sync).

request(Req) ->
    Result = gen_server:call(?SERVER, {call, Req}),
    Result.

request(Req, Params) ->
    Result = gen_server:call(?SERVER, {call, Req, Params}),
    Result.

parse_xapi_request(ReqResult) ->
    Result = case ReqResult of
                 {ok,{response,[{struct, PreResult}]}} -> PreResult;
                 _Other -> {error, unknown}
             end,
    Result.

xapi_request(Req, Params, State) ->
    ReqResult = xmlrpc:call(State#sref.host, 80, "/",{call, Req, [State#sref.sref | Params]}),

    Result = case parse_xapi_request(ReqResult) of
                 {error, unknown} -> error;
                 PreResult -> case proplists:get_value('Value', PreResult) of
                                  {array, List} -> List;
                                  {struct, Struct} -> Struct;
                                  String -> String
                              end
             end,
    Result.

init([Host, AuthInfo]) ->
    {ok, {response, [{struct, Result}]}} = xmlrpc:call(Host, 80, "/", {call, 'session.login_with_password', AuthInfo}),
    SessionRef = proplists:get_value('Value', Result),
    {ok, #sref{sref = SessionRef, host = Host}}.

handle_call({call, Req}, _From, State) ->
    Result = xapi_request(Req, [], State),
    {reply, Result, State};

handle_call({call, Req, Params}, _From, State) ->
    Result = xapi_request(Req, Params, State),
    {reply, Result, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
