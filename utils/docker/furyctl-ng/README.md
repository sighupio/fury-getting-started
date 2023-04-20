# Getting started docker image

Docker image containing all the necessary tools to deploy fury on EKS

| Docker image              | Latest Tag |
|---------------------------|------------|
| `fury-getting-started-ng` | 0.3.0      |

## Publish new version to Harbor

After having modified the Dockerfile. Select the appropriate tag:

```bash
export TAG=0.3.0 # Semantic Versioning: Major.minor.patch
```

Build the image:

```bash
docker build -t fury-getting-started-ng:${TAG} .
```

## Test the image locally

```bash
docker run -ti -v ${PWD}:/demo fury-getting-started-ng:${TAG}
```

## Deploy to Harbor

Login to [registry.sighup.io](registry.sighup.io):

```bash
docker login registry.sighup.io
```

Tag the local image:

```bash
docker tag fury-getting-started-ng:${TAG} registry.sighup.io/delivery/fury-getting-started-ng:${TAG}

docker tag registry.sighup.io/delivery/fury-getting-started-ng:${TAG} registry.sighup.io/delivery/fury-getting-started-ng:latest
```

Push the image:

```bash
docker push registry.sighup.io/delivery/fury-getting-started-ng:${TAG}
```

Try to pull the image from remote:

```bash
docker pull registry.sighup.io/delivery/fury-getting-started-ng:${TAG}
```

Or run it directly:

```bash
docker run -ti -v ${PWD }:/demo registry.sighup.io/delivery/fury-getting-started-ng:${TAG}
```

Cut a new release in this repository:

```bash
git tag -f ${TAG}
git push --tags
```
