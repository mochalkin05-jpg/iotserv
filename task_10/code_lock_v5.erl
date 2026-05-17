-module(code_lock_v5).
-behaviour(gen_statem).

%% API
-export([start_link/1, button/1, change_code/1, stop/0]).

%% Callbacks
-export([callback_mode/0, init/1, terminate/3, code_change/4]).
-export([locked/3, open/3, suspended/3]).

-record(data, {
    code :: [integer()],
    length :: integer(),
    buttons = [] :: [integer()],
    failures = 0 :: integer()
}).

start_link(Code) -> gen_statem:start_link({local, ?MODULE}, ?MODULE, Code, []).
button(Digit) -> gen_statem:call(?MODULE, {button, Digit}).
change_code(NewCode) -> gen_statem:call(?MODULE, {change_code, NewCode}).
stop() -> gen_statem:stop(?MODULE).

callback_mode() -> state_functions.

init(Code) -> {ok, locked, #data{code = Code, length = length(Code)}}.

%% Состояние: ЗАБЛОКИРОВАН
locked({call, From}, {button, Digit}, Data = #data{code = Code, length = Length, buttons = Buttons, failures = Failures}) ->
    NewButtons = Buttons ++ [Digit],
    if
        length(NewButtons) < Length ->
            {keep_state, Data#data{buttons = NewButtons}, [{reply, From, ok}]};
        NewButtons =:= Code ->
            {next_state, open, Data#data{buttons = [], failures = 0}, [
                {reply, From, unlocked}, {state_timeout, 10000, lock}
            ]};
        true ->
            NewFailures = Failures + 1,
            if
                NewFailures >= 3 ->
                    {next_state, suspended, Data#data{buttons = [], failures = NewFailures}, [
                        {reply, From, {error, suspended_due_to_failures}}, {state_timeout, 10000, unlock}
                    ]};
                true ->
                    {keep_state, Data#data{buttons = [], failures = NewFailures}, [{reply, From, {error, incorrect_code}}]}
            end
    end;
locked({call, From}, {change_code, _}, _Data) ->
    {keep_state_and_data, [{reply, From, {error, access_denied}}]}.

%% Состояние: ОТКРЫТ
open(state_timeout, lock, Data) ->
    {next_state, locked, Data#data{buttons = []}};
open({call, From}, {button, _}, _Data) ->
    {keep_state_and_data, [{reply, From, {error, already_open}}]};
open({call, From}, {change_code, NewCode}, Data) ->
    {keep_state, Data#data{code = NewCode, length = length(NewCode)}, [
        {reply, From, ok}, {state_timeout, 10000, lock}
    ]}.

%% Состояние: ПРИОСТАНОВЛЕН (штраф 10 сек)
suspended(state_timeout, unlock, Data) ->
    {next_state, locked, Data#data{failures = 0, buttons = []}};
suspended({call, From}, {button, _}, _Data) ->
    {keep_state_and_data, [{reply, From, {error, suspended}}]};
suspended({call, From}, {change_code, _}, _Data) ->
    {keep_state_and_data, [{reply, From, {error, suspended}}]}.

terminate(_Reason, _State, _Data) -> ok.
code_change(_Vsn, State, Data, _Extra) -> {ok, State, Data}.
