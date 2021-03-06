-module(sipxplugin_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, {{one_for_one, 5, 10}, [
    	{spx_autoloader,
    		{spx_autoloader, start_link, []},
    		permanent,
    		1000,
    		worker,
    		[spx_autoloader]},
    	{spx_integration,
    		{spx_integration, start_link, []},
    		permanent,
    		1000,
    		worker,
    		[spx_integration]}
    ]} }.

