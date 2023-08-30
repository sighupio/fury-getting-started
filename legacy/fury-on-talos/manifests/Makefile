.PHONY: build
build:
	kustomize build .

.PHONY: diff
diff:
	kustomize build . | kubectl diff -f - | less -SR

.PHONY: apply
apply:
	kustomize build . | kubectl apply -f - | grep -v unchanged
