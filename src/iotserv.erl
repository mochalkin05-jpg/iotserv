-module(iotserv).
-behaviour(gen_server).

-export([start_link/0, add/5, delete/1, change/2, lookup/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("iotserv.hrl").

-record(state, {}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

add(Id, Name, Address, Temp, Indicators) ->
    Device = #device{id=Id, name=Name, address=Address, temperature=Temp, indicators=Indicators},
    gen_server:call(?MODULE, {add, Device}).

delete(Id) ->
    gen_server:call(?MODULE, {delete, Id}).

change(Id, UpdatesMap) ->
    gen_server:call(?MODULE, {change, Id, UpdatesMap}).

lookup(Id) ->
    gen_server:call(?MODULE, {lookup, Id}).

init([]) ->
    {ok, Bin} = file:read_file("config.json"),
    Config = jsx:decode(Bin, [{return_maps, true}]),
    DetsFile = binary_to_list(maps:get(<<"dets_file">>, Config, <<"iotserv_data.dets">>)),
    ok = iotserv_db:init(DetsFile),
    {ok, #state{}}.

handle_call({add, Device}, _From, State) ->
    iotserv_db:add_device(Device),
    {reply, ok, State};

handle_call({delete, Id}, _From, State) ->
    iotserv_db:delete_device(Id),
    {reply, ok, State};

handle_call({change, Id, Updates}, _From, State) ->
    case iotserv_db:get_device(Id) of
        {ok, Device} ->
            NewDevice = apply_updates(Device, Updates),
            iotserv_db:update_device(NewDevice),
            {reply, ok, State};
        {error, not_found} ->
            {reply, {error, not_found}, State}
    end;

handle_call({lookup, Id}, _From, State) ->
    Reply = iotserv_db:get_device(Id),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ignored, State}.

handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, _State) ->
    iotserv_db:close(),
    ok.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

apply_updates(Dev, Updates) ->
    D1 = case maps:find(name, Updates) of {ok, V1} -> Dev#device{name=V1}; error -> Dev end,
    D2 = case maps:find(address, Updates) of {ok, V2} -> D1#device{address=V2}; error -> D1 end,
    D3 = case maps:find(temperature, Updates) of {ok, V3} -> D2#device{temperature=V3}; error -> D2 end,
    case maps:find(indicators, Updates) of {ok, V4} -> D3#device{indicators=V4}; error -> D3 end.
