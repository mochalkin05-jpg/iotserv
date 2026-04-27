-module(iotserv_db).
-export([init/1, close/0, add_device/1, delete_device/1, get_device/1, update_device/1]).

-include("iotserv.hrl").

init(DetsFile) ->
    {ok, ?MODULE} = dets:open_file(?MODULE, [{file, DetsFile}, {type, set}, {keypos, 2}]),
    ?MODULE = ets:new(?MODULE, [set, named_table, public, {keypos, 2}]),
    dets:to_ets(?MODULE, ?MODULE),
    ok.

close() ->
    dets:close(?MODULE).

add_device(Device) ->
    ets:insert(?MODULE, Device),
    dets:insert(?MODULE, Device),
    ok.

delete_device(Id) ->
    ets:delete(?MODULE, Id),
    dets:delete(?MODULE, Id),
    ok.

get_device(Id) ->
    case ets:lookup(?MODULE, Id) of
        [Device] -> {ok, Device};
        [] -> {error, not_found}
    end.

update_device(Device) ->
    add_device(Device).
