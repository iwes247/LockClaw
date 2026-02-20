.PHONY: help validate iso qcow2 raw clean

help:
	@echo "LockClaw image-builder stubs"
	@echo "Targets:"
	@echo "  make validate  # validates required inputs"
	@echo "  make iso       # ISO build stub"
	@echo "  make qcow2     # QCOW2 build stub"
	@echo "  make raw       # RAW image build stub"
	@echo "  make clean     # remove generated stubs"

validate:
	@./scripts/validate-inputs.sh

iso: validate
	@./scripts/build-iso-stub.sh

qcow2: validate
	@./scripts/build-qcow2-stub.sh

raw: validate
	@./scripts/build-raw-stub.sh

clean:
	@rm -f output/*.stub
	@echo "Cleaned image-builder stub outputs"
