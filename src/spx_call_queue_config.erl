%% Copyright (c) 2010 / 2011 eZuce, Inc. All rights reserved.
%% Contributed to SIPfoundry under a Contributor Agreement
%%
%% This software is free software; you can redistribute it and/or modify it under
%% the terms of the Affero General Public License (AGPL) as published by the
%% Free Software Foundation; either version 3 of the License, or (at your option)
%% any later version.
%%
%% This software is distributed in the hope that it will be useful, but WITHOUT
%% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
%% FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
%% details.

-module(spx_call_queue_config).

-include_lib("OpenACD/include/queue.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-ifdef(TEST).
-export([reset_test_db/0]).
-define(DB, <<"imdb_test">>).
-else.
-define(DB, <<"imdb">>).
-endif.

-export([
	start/0,
	get_queue/1,
	get_queues/0,

	get_queue_group/1,
	get_queue_groups/0
]).

%%====================================================================
%% API
%%====================================================================

start() ->
	cpx_hooks:set_hook(spx_get_queue, get_queue, ?MODULE, get_queue, [], 200),
	cpx_hooks:set_hook(spx_get_queues, get_queues, ?MODULE, get_queues, [], 200),

	cpx_hooks:set_hook(spx_get_queue_group, get_queue_group, ?MODULE, get_queue_group, [], 200),
	cpx_hooks:set_hook(spx_get_queue_groups, get_queue_groups, ?MODULE, get_queue_groups, [], 200),

	ok.

get_queue(Name) ->
	case db_find_one(queue, [{<<"name">>, Name}]) of
		{ok, []} ->
			noexists;
		{ok, Props} ->
			spx_util:build_queue(Props)
	end.

get_queues() ->
	{ok, Props} = db_find(queue, []),
	{ok, [X || P <- Props, {ok, X} <- [spx_util:build_queue(P)]]}.

get_queue_group(Name) ->
	case db_find_one(queuegroup, [{<<"name">>, Name}]) of
		{ok, []} ->
			noexists;
		{ok, Props} ->
			spx_util:build_queue_group(Props)
	end.

get_queue_groups() ->
	{ok, Props} = db_find(queuegroup, []),
	{ok, [X || P <- Props, {ok, X} <- [spx_util:build_queue_group(P)]]}.


db_find(queue, Props) ->
	db_find(<<"openacdqueue">>, Props);
db_find(queuegroup, Props) ->
	db_find(<<"openacdqueuegroup">>, Props);
db_find(Type, Props) when is_binary(Type) ->
	db_find([{<<"type">>, Type}|Props]).

db_find(Props) when is_list(Props) ->
	DB = mongoapi:new(spx, ?DB),
	DB:find(<<"entity">>, Props,
		undefined, 0, 0).
db_find_one(queue, Props) ->
	db_find_one(<<"openacdqueue">>, Props);
db_find_one(Type, Props) when is_binary(Type) ->
	db_find_one([{<<"type">>, Type}|Props]).
db_find_one(Props) when is_list(Props) ->
	DB = mongoapi:new(spx, ?DB),
	DB:findOne(<<"entity">>, Props).


-ifdef(TEST).
%%--------------------------------------------------------------------
%%% Test functions
%%--------------------------------------------------------------------


start_test_() ->
	{setup, fun() ->
		cpx_hooks:start_link(),	
		spx_call_queue_config:start()
	end, [
		?_assert(has_hook(spx_get_queue, get_queue)),
		?_assert(has_hook(spx_get_queues, get_queues)),
		?_assert(has_hook(spx_get_queue_group, get_queue_group)),
		?_assert(has_hook(spx_get_queue_groups, get_queue_groups))
	]}.

integ_get_queue_test_() ->
	{setup, fun reset_test_db/0, fun stop_test_db/1, [
		?_assertMatch({ok, #call_queue{name="boozer", group="queuez"}},
			spx_call_queue_config:get_queue("boozer")),
		?_assertMatch(noexists,
			spx_call_queue_config:get_queue("missingqueue"))
		
	]}.

integ_get_queues_test_() ->
	{setup, fun reset_test_db/0, fun stop_test_db/1, [
		?_assertMatch({ok, [#call_queue{name="boozer", group="queuez"},
			#call_queue{name="homer", group="queuezon"}]},
			spx_call_queue_config:get_queues())
	]}.

integ_get_queue_groups_test_() ->
	{setup, fun reset_test_db/0, fun stop_test_db/1, [
		?_assertMatch({ok, [
			#queue_group{name="Default"},
			#queue_group{name="queuezon"},
			#queue_group{name="boozer"}
			]},
			spx_call_queue_config:get_queue_groups())
	]}.

%% Test helpers

has_hook(Name, Hook) ->
	lists:member({Name, ?MODULE, Hook, [], 200},
		cpx_hooks:get_hooks(Hook)).

reset_test_db() ->
	PrivDir = case code:priv_dir(sipxplugin) of
		{error, _} ->
			filename:join([filename:dirname(code:which(spx_agent_auth)),
				"..", "priv"]);
		Dir -> Dir
	end,
	Path = filename:join(PrivDir, "test_entries.json"),
	
	{ok, Bin} = file:read_file(Path),
	{struct, [{"entries", {array, Entries}}]} = mochijson:decode(Bin),

	% mongodb:start(),
	mongodb:singleServer(spx),
	mongodb:connect(spx),

	DB = mongoapi:new(spx,?DB),
	DB:set_encode_style(default),

	DB:dropDatabase(),
	lists:foreach(fun({struct, Props}) ->
		Id = proplists:get_value("_id", Props),
		P1 = proplists:delete("_id", Props),
		P2 = [{<<"_id">>, Id}| P1],
		DB:save("entity", P2) end,
	Entries).


stop_test_db(_) ->
	% catch mongodb:stop(),
	ok.

-endif.