PREFIX ?= "run"
PROFILE_SECONDS ?= "120"

.PHONY: all
all: torch

.PHONY: build
build:  build/cri.txt build/bench.txt

bench.yaml:

build/bench.txt: bench.yaml
	mkdir -p build && docker build --target bench --iidfile=$@ $(bench_build_args) -t cric8d/bench .

.PRECIOUS: build/%.txt
build/%.txt:
	mkdir -p build && docker build --target $* --iidfile=$@ $($*_build_args) -t cric8d/$* .

.PHONY: run
run: run/base run/cri run/bench 

.PHONY: torch
torch: run
	# TODO: figure out something else than this hacky sleep...
	echo running && $(MAKE) run/torch

run/base:
	mkdir -p run && docker run -d --rm --cidfile=$@ -v /run -v /var/run -v /var/lib/containers/storage -v /dev/disk:/dev/disk  busybox top

run/torch: run/bench run/cri 
	docker run --rm --cidfile=$@ --log-driver=none --net=container:$(shell cat run/cri) uber/go-torch -u http://localhost:6060 --print -t $(PROFILE_SECONDS) > $(PREFIX)/torch.svg; \
		rm run/torch; \
		docker logs -f $(shell cat run/bench); \
		docker rm $(shell cat run/bench); \
		rm run/bench

.PRECIOUS: run/%
run/%:  build/%.txt run/base
	mkdir -p run && docker run -d -t --privileged --cidfile=$@ --volumes-from $(shell cat run/base) --net=container:$(shell cat run/base) $(shell cat build/$*.txt)

.PHONY: clean
clean: clean/bench clean/cri clean/torch clean/base
	-rm -rf build/*
	-rm -rf run/*

.PHONY: clean/%
clean/%:
	- if [ -f run/$* ]; then docker rm -f $(shell [ -f run/$* ] && cat run/$*); fi
