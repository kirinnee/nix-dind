#! /bin/sh

# check for necessary env vars
[ "${DOMAIN}" = '' ] && echo "❌ 'DOMAIN' env var not set" && exit 1
[ "${GITHUB_REPO_REF}" = '' ] && echo "❌ 'GITHUB_REPO_REF' env var not set" && exit 1
[ "${GITHUB_SHA}" = '' ] && echo "❌ 'GITHUB_SHA' env var not set" && exit 1
[ "${GITHUB_BRANCH}" = '' ] && echo "❌ 'GITHUB_BRANCH' env var not set" && exit 1

[ "${CI_DOCKER_IMAGE}" = '' ] && echo "❌ 'CI_DOCKER_IMAGE' env var not set" && exit 1
[ "${CI_DOCKER_CONTEXT}" = '' ] && echo "❌ 'CI_DOCKER_CONTEXT' env var not set" && exit 1
[ "${CI_DOCKERFILE}" = '' ] && echo "❌ 'CI_DOCKERFILE' env var not set" && exit 1

[ "${DOCKER_PASSWORD}" = '' ] && echo "❌ 'DOCKER_PASSWORD' env var not set" && exit 1
[ "${DOCKER_USER}" = '' ] && echo "❌ 'DOCKER_USER' env var not set" && exit 1

set -eu

onExit() {
	rc="$?"
	if [ "$rc" = '0' ]; then
		echo "✅ Successfully built and run images"
	else
		echo "❌ Failed to run Docker image"
	fi
}

trap onExit EXIT

# Login to GitHub Registry
echo "🔐 Logging into docker registry..."
echo "${DOCKER_PASSWORD}" | docker login docker.pkg.github.com -u "${DOCKER_USER}" --password-stdin
echo "✅ Successfully logged into docker registry!"

echo "📝 Generating Image tags..."
# Obtain image
IMAGE_ID="${DOMAIN}/${GITHUB_REPO_REF}/${CI_DOCKER_IMAGE}"
IMAGE_ID=$(echo "${IMAGE_ID}" | tr '[:upper:]' '[:lower:]') # convert to lower case

# obtaining the version
SHA="$(echo "${GITHUB_SHA}" | head -c 6)"
BRANCH="${GITHUB_BRANCH}"
IMAGE_VERSION="${BRANCH}-${SHA}"

# Generate image references
COMMIT_IMAGE_REF="${IMAGE_ID}:${IMAGE_VERSION}"
BRANCH_IMAGE_REF="${IMAGE_ID}:${BRANCH}"
LATEST_IMAGE_REF="${IMAGE_ID}:latest"
CACHED_IMAGE_REF="${IMAGE_ID}:cached"

echo "✅ Commit Image Ref: ${COMMIT_IMAGE_REF}"
echo "✅ Branch Image Ref: ${BRANCH_IMAGE_REF}"
echo "✅ Latest Image Ref: ${LATEST_IMAGE_REF}"
echo "✅ Cached Image Ref: ${CACHED_IMAGE_REF}"

# build image
echo "🔨 Building Docker image..."
docker buildx build \
	"${CI_DOCKER_CONTEXT}" \
	--platform=linux/amd64,linux/arm64 \
	-f "${CI_DOCKERFILE}" \
	--output="type=image,name=${COMMIT_IMAGE_REF}"
echo "✅ Successfully built docker image!"

# push commit image
echo "🔨 Push commit-versioned Docker image..."
docker push "${COMMIT_IMAGE_REF}"
echo "✅ Pushed commit-versioned Docker image!"

# push branch image
echo "🔨 Push branch-versioned Docker image..."
docker tag "${COMMIT_IMAGE_REF}" "${BRANCH_IMAGE_REF}"
docker push "${BRANCH_IMAGE_REF}"
echo "✅ Pushed branch-versioned Docker image!"

# push latest
if [ "$BRANCH" = "main" ]; then
	echo "🔎 Detected branch is 'main', pushing latest image..."
	docker tag "${COMMIT_IMAGE_REF}" "${LATEST_IMAGE_REF}"
	docker push "${LATEST_IMAGE_REF}"
	echo "✅ Pushed latest Docker image!"
fi
