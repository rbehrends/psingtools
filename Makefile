
DMD=dmd
DUB=dub
BUILD = $(DUB) build --build-mode=singleFile -q --parallel --compiler=$(DMD)
GEN = gen/scanner.d
all: $(GEN)
	$(BUILD) --build=debug
opt: $(GEN)
	$(BUILD) --build=release
force: $(GEN)
	$(BUILD) --force
test: $(GEN)
	$(DUB) test -q
clean:
	$(DUB) clean -q
	rm -rf gen bin .dub .rdmd-*

gen/scanner.d: src/scanner.re
	@mkdir -p gen
	re2c --no-generation-date --no-version -i -o gen/scanner.d src/scanner.re
	rdmd --tmpdir=. tools/subst.d "unsigned int" "uint" gen/scanner.d
