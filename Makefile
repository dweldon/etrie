REBAR := ./rebar

.PHONY: all doc test clean update release

all:
	$(REBAR) compile

doc:
	$(REBAR) doc

test:
	$(REBAR) eunit

clean:
	$(REBAR) clean

update:
	git pull
	$(REBAR) compile

release: all test
	dialyzer --src src/*.erl
