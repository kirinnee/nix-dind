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

COMMIT_CACHE_IMAGE_REF="${COMMIT_IMAGE_REF}-cache"
BRANCH_CACHE_IMAGE_REF="${BRANCH_IMAGE_REF}-cache"
LATEST_CACHE_IMAGE_REF="${LATEST_IMAGE_REF}-cache"

echo "✅ Commit Image Ref: ${COMMIT_IMAGE_REF}"
echo "✅ Branch Image Ref: ${BRANCH_IMAGE_REF}"
echo "✅ Latest Image Ref: ${LATEST_IMAGE_REF}"

echo "✅ Commit Cache Image Ref: ${COMMIT_CACHE_IMAGE_REF}"
echo "✅ Branch Cache Image Ref: ${BRANCH_CACHE_IMAGE_REF}"
echo "✅ Latest Cache Image Ref: ${LATEST_CACHE_IMAGE_REF}"

echo "🧬 Generating ref targets..."
EXPORT_REFS="${COMMIT_CACHE_IMAGE_REF},${BRANCH_CACHE_IMAGE_REF}"
IMPORT_REFS="${COMMIT_CACHE_IMAGE_REF},${BRANCH_CACHE_IMAGE_REF},${LATEST_CACHE_IMAGE_REF}"
# push latest
if [ "$BRANCH" = "main" ]; then
	echo "🔎 Detected branch is 'main', appending ref targets..."
	EXPORT_REFS="${EXPORT_REFS},${LATEST_CACHE_IMAGE_REF}"
fi

echo "✅ Export Ref targets generated: '${EXPORT_REFS}'"
echo "✅ Import Ref targets generated: '${IMPORT_REFS}'"

# build image
echo "🔨 Building Docker image..."
docker buildx build \
	--platform=linux/amd64,linux/arm64 "${CI_DOCKER_CONTEXT}" \
	-f "${CI_DOCKERFILE}" \
	--output type=image,name="${COMMIT_CACHE_IMAGE_REF}" \
	--cache-to type=registry,mode=max,"ref=${EXPORT_REFS}" \
	--cache-from type=registry,"ref=${EXPORT_REFS}"
echo "✅ Successfully built docker image!"

# push commit image
echo "🔨 Push commit-versioned Docker image..."
docker push "${COMMIT_CACHE_IMAGE_REF}"
echo "✅ Pushed commit-versioned Docker image!"

# push branch image
echo "🔨 Push branch-versioned Docker image..."
docker push "${COMMIT_CACHE_IMAGE_REF}"
echo "✅ Pushed branch-versioned Docker image!"

# push latest
if [ "$BRANCH" = "main" ]; then
	echo "🔎 Detected branch is 'main', pushing latest image..."
	docker push "${COMMIT_CACHE_IMAGE_REF}"
	echo "✅ Pushed latest Docker image!"
fi
