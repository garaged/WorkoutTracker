.PHONY: spec-check spec-test spec-done
PYTHON ?= python3
spec-check:
	$(PYTHON) scripts/spec_check.py --mode ready
spec-test:
	$(PYTHON) -m unittest discover -s scripts/tests -v
# Supply the exact tested source SHA: make spec-done COMMIT=<40-character-sha>
spec-done:
	$(PYTHON) scripts/spec_check.py --mode done --commit "$(COMMIT)"
