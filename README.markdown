Overview
--------
etrie implements a trie, for storing strings with associated values. While it
can be used as a general purpose trie, it was designed to be used in spell
checkers or related applications where an efficient answer to the following
problem is desired:

Given a set of strings **S** and an input string **I**, give me the subset of
**S** which is at most **E** edits from **I**. An edit is defined as a delete,
insert, substitute, or transpose.

Installation
------------
    $ git clone git://github.com/dweldon/etrie.git
    $ cd etrie && make

Interface
---------
The following examples give an overview of the etrie interface. Please see the
complete documentation by running `make doc`.

    > T1 = etrie:store("theater", 100, etrie:new()).

    > T2 = etrie:store("theatre", 200, T1).

    > etrie:find("theater", T2).
    {ok,100}
    
    > etrie:find("movie", T2).
    error

    > rr("include/etrie.hrl").
    [match]
    
    > etrie:similar("theatre", 1, T2).
    [#match{string = "theater",edits = 1,value = 100},
     #match{string = "theatre",edits = 0,value = 200}]
