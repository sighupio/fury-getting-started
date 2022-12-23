.PHONY: build
build:
	kustomize build .

.PHONY: diff
diff:
	kustomize build . | kubectl diff -f -  --server-side | less -SR

.PHONY: apply
apply:
	kustomize build . | kubectl apply -f - --server-side

.PHONY: delete
delete:
	kustomize build . | kubectl delete -f -
