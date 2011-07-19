%% @author David Weldon
%% @copyright 2011 David Weldon
%% @doc etrie implements a trie, for storing strings with associated values.

-module(etrie).
-export([find/2, new/0, similar/3, store/3]).
-define(EMPTY_TRIE, {[], []}).
-include_lib("etrie.hrl").

%% @type match() = #match{string = string(),
%%                        edits = integer(),
%%                        value = any()}
%%
%% @type trie() = {orddict(), list()}.

%% @spec find(String::string(), Trie::trie()) -> {ok, Value::any()} | error
%% @doc Returns `{ok, Value}' if `String' was found in `Trie', and `error'
%% otherwise.
find([], {_, []}) -> error;
find([], {_, [Value]}) -> {ok, Value};
find([H|T], {Dict, _}) ->
    case orddict:find(H, Dict) of
        {ok, SubTrie} -> find(T, SubTrie);
        error -> error
    end.

%% @spec new() -> trie()
%% @doc Returns a new trie.
new() -> ?EMPTY_TRIE.

%% @spec similar(string(), integer(), trie()) -> [match()]
%% @doc Returns a list of matches whose strings require at most `MaxEdits' edits
%% to equal `String'. Valid edits are delete, insert, substitute, and transpose.
%% All edits have equal weight.
similar(String, MaxEdits, Trie) ->
    combine_matches(similar([], String, 0, MaxEdits, Trie)).

similar(_, _, Edits, Max, _) when Edits > Max -> [];
similar(_, [], _, _, ?EMPTY_TRIE) -> [];
similar(Path, [], Edits, _, {[], [Value]}) ->
    %% more nodes = no, leaf node = yes -> return match
    [#match{string=lists:reverse(Path), edits=Edits, value=Value}];
similar(Path, [], Edits, Max, {Dict, []}) ->
    %% more nodes = yes, leaf node = no -> try all inserts
    [similar([K|Path], [], Edits+1, Max, Trie) || {K, Trie} <- Dict];
similar(Path, [], Edits, Max, {Dict, [Value]}) ->
    %% more nodes = yes, leaf node = yes -> return match + try all inserts
    Match = #match{string=lists:reverse(Path), edits=Edits, value=Value},
    Matches = [similar([K|Path], [], Edits+1, Max, Trie) || {K, Trie} <- Dict],
    [Match|Matches];
similar(Path, [H|T], Edits, Max, {Dict, _}) when Edits =:= Max ->
    %% this clause is an optimization - it greatly reduces the number of calls
    case orddict:find(H, Dict) of
        {ok, Trie} -> similar([H|Path], T, Edits, Max, Trie);
        error -> []
    end;
similar(Path, [H|T], Edits, Max, {Dict, Value}) ->
    Delete = similar(Path, T, Edits+1, Max, {Dict, Value}),
    Substitute =
        [similar([K|Path], T, Edits+1, Max, Trie) || {K, Trie} <- Dict, K /= H],
    Insert =
        [similar([K|Path], [H|T], Edits+1, Max, Trie) || {K, Trie} <- Dict],
    Transpose =
        case length([H|T]) >= 2 andalso H =/= hd(T) of
            true ->
                [H2|T2] = T,
                similar(Path, [H2,H|T2], Edits+1, Max, {Dict, Value});
            false -> []
        end,
    NoChange =
        case orddict:find(H, Dict) of
            {ok, Trie} -> similar([H|Path], T, Edits, Max, Trie);
            error -> []
        end,
    [Delete, Substitute, Insert, Transpose, NoChange].

%% @spec combine_matches(list()) -> list()
%% @doc Flattens `Matches' and returns a list of matches which are unique by
%% string. If two or more matches have identical strings but different edits,
%% only the one with the fewest edits will appear in the final list.
combine_matches(Matches) ->
    combine_matches(lists:flatten(Matches), []).

combine_matches([], Dict) -> [V || {_, V} <- Dict];
combine_matches([Match=#match{string=String, edits=Edits}|Matches], Dict) ->
    case orddict:find(String, Dict) of
        {ok, #match{edits=PrevEdits}} when PrevEdits =< Edits ->
            combine_matches(Matches, Dict);
        _ ->
            combine_matches(Matches, orddict:store(String, Match, Dict))
    end.

%% @spec store(String::string(), Value::any(), Trie::trie()) -> trie()
%% @doc Returns a new trie after storing `String' and its associated `Value'
%% into `Trie'. If `String' already exists in `Trie', then `Value' will
%% overwrite the previous value associated with `String'.
store([], Value, {Dict, _}) ->
    {Dict, [Value]};
store([H|T], Value, {Dict, V}) ->
    case orddict:find(H, Dict) of
        {ok, SubTrie} ->
            {orddict:store(H, store(T, Value, SubTrie), Dict), V};
        error ->
            {orddict:store(H, store(T, Value, new()), Dict), V}
    end.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

store_find_test_() ->
    T0 = new(),
    T1 = store("a", 1, T0),
    T2 = store("ab", 2, T1),
    T3 = store("abc", 3, T2),
    T4 = store("abc", 4, T3),
    T5 = store("cba", 5, T4),
    [?_assertEqual(error, find("", T5)),
     ?_assertEqual(error, find("#", T5)),
     ?_assertEqual({ok, 1}, find("a", T5)),
     ?_assertEqual({ok, 2}, find("ab", T5)),
     ?_assertEqual({ok, 3}, find("abc", T3)),
     ?_assertEqual({ok, 4}, find("abc", T5)),
     ?_assertEqual({ok, 5}, find("cba", T5))].

combine_matches_test_() ->
    Ma1 = #match{string="ma", edits=1, value=3},
    Ma2 = #match{string="ma", edits=2, value=2},
    Ma3 = #match{string="ma", edits=3, value=1},
    Mb1 = #match{string="mb", edits=1, value=3},
    Mb2 = #match{string="mb", edits=2, value=2},
    Mb3 = #match{string="mb", edits=3, value=1},
    [?_assertEqual([], combine_matches([])),
     ?_assertEqual([], combine_matches([[], []])),
     ?_assertEqual([Ma1], combine_matches([Ma1, Ma2, Ma3])),
     ?_assertEqual([Ma1], combine_matches([Ma3, Ma2, Ma1])),
     ?_assertEqual([Ma1, Mb1], combine_matches([Ma1, Mb1, Ma2, Mb2, Ma3, Mb3])),
     ?_assertEqual([Ma1, Mb1], combine_matches([Ma3, Mb3, Ma2, Mb2, Ma1, Mb1])),
     ?_assertEqual([Ma1], combine_matches([Ma2, Ma2, Ma1])),
     ?_assertEqual([Ma2, Mb2], combine_matches([Ma2, Ma2, Ma2, Mb2, Ma2]))].

similar_test_() ->
    {S1, D1} = {"abc", 1},
    {S2, D2} = {"abcdef", 2},
    M1 = #match{string=S1, edits=0, value=D1},
    M2 = #match{string=S2, edits=0, value=D2},
    T0 = new(),
    T1 = store(S1, 1, T0),
    T2 = store(S2, 2, T1),
    [?_assertEqual([], similar(S1, 0, T0)),
     ?_assertEqual([], similar("", 0, T0)),
     ?_assertEqual([], similar("X", 1, T2)),
     ?_assertEqual([M1], similar(S1, 0, T2)),
     %% delete
     ?_assertEqual([M1#match{edits=1}], similar("Xabc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("aXbc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("abXc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("abcX", 1, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("XXabc", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("aXbXc", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("abcXX", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("abXXc", 2, T2)),
     %% substitute
     ?_assertEqual([M1#match{edits=1}], similar("Xbc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("aXc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("abX", 1, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("XXc", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("aXX", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("XbX", 2, T2)),
     %% insert
     ?_assertEqual([M1#match{edits=1}], similar("bc", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("ac", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("ab", 1, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("a", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("b", 2, T2)),
     ?_assertEqual([M1#match{edits=2}], similar("c", 2, T2)),
     %% transpose
     ?_assertEqual([M1#match{edits=1}], similar("bac", 1, T2)),
     ?_assertEqual([M1#match{edits=1}], similar("acb", 1, T2)),
     %% mixed
     ?_assertEqual([M1#match{edits=1}], similar("abXc", 3, T2)),
     ?_assertEqual([M1, M2#match{edits=3}], similar("abc", 3, T2)),
     ?_assertEqual([M2#match{edits=3}], similar("bacdXf1", 3, T2))].

-endif.
