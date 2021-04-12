## Dependency versions

CONTROLLER_TOOLS_VERSION=0.5.0
CSI_VERSION=1.3.0
KUBEBUILDER_VERSION = 3.0.0-rc.0
KUSTOMIZE_VERSION= 3.8.9
PROTOC_VERSION=3.15.0

SUDO=sudo
CURL=curl -Lsf
BINDIR := $(PWD)/bin
CONTROLLER_GEN := $(BINDIR)/controller-gen
KUSTOMIZE := $(BINDIR)/kustomize
STATICCHECK := $(BINDIR)/staticcheck
NILERR := $(BINDIR)/nilerr
INEFFASSIGN := $(BINDIR)/ineffassign
KUBEBUILDER_ASSETS := $(BINDIR)
PROTOC := PATH=$(BINDIR):$(PATH) $(BINDIR)/protoc -I=$(PWD)/include:.
PACKAGES := unzip lvm2 xfsprogs

GO_FILES=$(shell find -name '*.go' -not -name '*_test.go')
GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)
GO111MODULE = on
GOFLAGS =
export GO111MODULE GOFLAGS KUBEBUILDER_ASSETS

BUILD_TARGET=hypertopolvm
TOPOLVM_VERSION ?= devel
IMAGE_TAG ?= latest

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

csi.proto:
	$(CURL) -o $@ https://raw.githubusercontent.com/container-storage-interface/spec/v$(CSI_VERSION)/csi.proto
	sed -i 's,^option go_package.*$$,option go_package = "github.com/topolvm/topolvm/csi";,' csi.proto
	sed -i '/^\/\/ Code generated by make;.*$$/d' csi.proto

csi/csi.pb.go: csi.proto
	mkdir -p csi
	$(PROTOC) --go_out=module=github.com/topolvm/topolvm:. $<

csi/csi_grpc.pb.go: csi.proto
	mkdir -p csi
	$(PROTOC) --go-grpc_out=module=github.com/topolvm/topolvm:. $<

lvmd/proto/lvmd.pb.go: lvmd/proto/lvmd.proto
	$(PROTOC) --go_out=module=github.com/topolvm/topolvm:. $<

lvmd/proto/lvmd_grpc.pb.go: lvmd/proto/lvmd.proto
	$(PROTOC) --go-grpc_out=module=github.com/topolvm/topolvm:. $<

docs/lvmd-protocol.md: lvmd/proto/lvmd.proto
	$(PROTOC) --doc_out=./docs --doc_opt=markdown,$@ $<

PROTOBUF_GEN = csi/csi.pb.go csi/csi_grpc.pb.go \
	lvmd/proto/lvmd.pb.go lvmd/proto/lvmd_grpc.pb.go docs/lvmd-protocol.md

.PHONY: manifests
manifests: ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) \
		crd:crdVersions=v1 \
		rbac:roleName=topolvm-controller \
		webhook \
		paths="./api/...;./controllers;./hook;./driver/k8s" \
		output:crd:artifacts:config=config/crd/bases
	rm -f deploy/manifests/base/crd.yaml
	cp config/crd/bases/topolvm.cybozu.com_logicalvolumes.yaml deploy/manifests/base/crd.yaml

.PHONY: generate
generate: $(PROTOBUF_GEN) ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="./hack/boilerplate.go.txt" paths="./api/..."

.PHONY: check-uncommitted
check-uncommitted: ## Check if latest generated artifacts are committed.
	$(MAKE) manifests
	$(MAKE) generate
	git diff --exit-code --name-only

.PHONY: test
test: ## Run lint and unit tests.
	test -z "$$(gofmt -s -l . | grep -v '^vendor' | tee /dev/stderr)"
	$(STATICCHECK) ./...
	test -z "$$($(NILERR) ./... 2>&1 | tee /dev/stderr)"
	$(INEFFASSIGN) .
	go install ./...
	go test -race -v ./...
	go vet ./...
	test -z "$$(go vet ./... | grep -v '^vendor' | tee /dev/stderr)"

.PHONY: clean
clean: ## Clean working directory.
	rm -rf build/
	rm -rf bin/
	rm -rf include/

##@ Build

.PHONY: build
build: build/hypertopolvm build/lvmd csi-sidecars ## Build binaries.

build/hypertopolvm: $(GO_FILES)
	mkdir -p build
	go build -o $@ -ldflags "-w -s -X github.com/topolvm/topolvm.Version=$(TOPOLVM_VERSION)" ./pkg/hypertopolvm

build/lvmd:
	mkdir -p build
	CGO_ENABLED=0 go build -o $@ -ldflags "-w -s -X github.com/topolvm/topolvm.Version=$(TOPOLVM_VERSION)" ./pkg/lvmd

.PHONY: csi-sidecars
csi-sidecars: ## Build sidecar images.
	mkdir -p build
	make -f csi-sidecars.mk OUTPUT_DIR=build

.PHONY: image
image: ## Build topolvm images.
	docker build -t $(IMAGE_PREFIX)topolvm:devel --build-arg TOPOLVM_VERSION=$(TOPOLVM_VERSION) .
	docker build -t $(IMAGE_PREFIX)topolvm-with-sidecar:devel --build-arg TOPOLVM_VERSION=$(TOPOLVM_VERSION) -f Dockerfile.with-sidecar .

.PHONY: tag
tag: ## Tag topolvm images.
	docker tag $(IMAGE_PREFIX)topolvm:devel $(IMAGE_PREFIX)topolvm:$(IMAGE_TAG)
	docker tag $(IMAGE_PREFIX)topolvm-with-sidecar:devel $(IMAGE_PREFIX)topolvm-with-sidecar:$(IMAGE_TAG)

.PHONY: push
push: ## Push topolvm images.
	docker push $(IMAGE_PREFIX)topolvm:$(IMAGE_TAG)
	docker push $(IMAGE_PREFIX)topolvm-with-sidecar:$(IMAGE_TAG)

##@ Setup

.PHONY: tools
tools: ## Install development tools.
	GOBIN=$(BINDIR) go install golang.org/x/tools/cmd/goimports@latest
	GOBIN=$(BINDIR) go install honnef.co/go/tools/cmd/staticcheck@latest
	GOBIN=$(BINDIR) go install github.com/gordonklaus/ineffassign@latest
	GOBIN=$(BINDIR) go install github.com/gostaticanalysis/nilerr/cmd/nilerr@latest

	# kubebuilder is currently not available for download according to the upstream documentation.
	# We download it from github release directly. Please update below after v3 is released.
	curl -sfLo $(BINDIR)/kubebuilder https://github.com/kubernetes-sigs/kubebuilder/releases/download/v$(KUBEBUILDER_VERSION)/kubebuilder_$(GOOS)_$(GOARCH)
	chmod +x $(BINDIR)/kubebuilder
	GOBIN=$(BINDIR) go install sigs.k8s.io/controller-tools/cmd/controller-gen@v$(CONTROLLER_TOOLS_VERSION)

	curl -sfL -o protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	unzip -o protoc.zip bin/protoc 'include/*'
	rm -f protoc.zip
	GOBIN=$(BINDIR) go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	GOBIN=$(BINDIR) go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	GOBIN=$(BINDIR) go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@latest

	GOBIN=$(BINDIR) go install github.com/onsi/ginkgo/ginkgo@latest

	# check if kustomize suports `go install` command.
	# known issue https://github.com/kubernetes-sigs/kustomize/issues/3618
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v$(KUSTOMIZE_VERSION))

.PHONY: setup
setup: tools ## Setup local environment.
	$(SUDO) apt-get update
	$(SUDO) apt-get -y install --no-install-recommends $(PACKAGES)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef
