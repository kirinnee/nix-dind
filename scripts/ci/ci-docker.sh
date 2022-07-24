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
CACHE_IMAGE_REF="${IMAGE_ID}:cache"

echo "✅ Commit Image Ref: ${COMMIT_IMAGE_REF}"
echo "✅ Branch Image Ref: ${BRANCH_IMAGE_REF}"
echo "✅ Latest Image Ref: ${LATEST_IMAGE_REF}"
echo "✅ Cache Image Ref:  ${CACHE_IMAGE_REF}"

# pull cache and tag it as cache
echo "⏬ Pulling past images as cache..."
have_cache="1"
docker pull "${BRANCH_IMAGE_REF}" || docker pull "${LATEST_IMAGE_REF}" || have_cache="0"
docker tag "${BRANCH_IMAGE_REF}" "${CACHE_IMAGE_REF}" || docker tag "${LATEST_IMAGE_REF}" "${CACHE_IMAGE_REF}" || have_cache="0"
if [ "${have_cache}" = '0' ]; then
	echo "✅ℹ️ No cache image found!"
else
	echo "✅ Cache image found, ref: '${CACHE_IMAGE_REF}'"
fi

# build image
echo "🔨 Building Dockerfile..."
docker buildx build --platform=linux/amd64,linux/arm/v7 "${CI_DOCKER_CONTEXT}" -f "${CI_DOCKERFILE}" --tag "${CI_DOCKER_IMAGE}" --cache-from="${CACHE_IMAGE_REF}"
echo "✅ Successfully built docker image!"

# push commit version
echo "⏫ Pushing versioned image..."
docker tag "${CI_DOCKER_IMAGE}" "${COMMIT_IMAGE_REF}"
docker push "${COMMIT_IMAGE_REF}"
echo "✅ Pushed versioned image!"

# push branch version
echo "⏫ Pushing branch image..."
docker tag "${CI_DOCKER_IMAGE}" "${BRANCH_IMAGE_REF}"
docker push "${BRANCH_IMAGE_REF}"
echo "✅ Pushed branch image!"

# push latest
if [ "$BRANCH" = "main" ]; then
	echo "🔎 Detected branch is 'main', pushing to latest..."
	docker tag "${CI_DOCKER_IMAGE}" "${LATEST_IMAGE_REF}"
	docker push "${LATEST_IMAGE_REF}"
	echo "✅ Pushed branch as latest image!"
fi
