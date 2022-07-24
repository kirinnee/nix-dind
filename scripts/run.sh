#!/bin/sh

version="${1:-latest}"

set -eu

onExit() {
	rc="$?"
	if [ "$rc" = '0' ]; then
		echo "✅ Successfully built"
	else
		echo "❌ Failed to run Docker image"
	fi
}
image_name="kirinnee/nix-docker:${version}"

echo "🧱 Building Docker image..."
docker build -t="${image_name}" .
echo "✅ Built Docker image!"

echo "🐳 Start Docker container..."
container_id=$(docker run --privileged -id "${image_name}")
echo "✅ Successfully ran Docker image"

cleanup() {
	rc="$?"
	echo "🧹 Clean up containers removing containers..."
	docker kill "${container_id}"
	docker rm "${container_id}"
	echo "✅ Containers removed!"
	if [ "$rc" = '0' ]; then
		echo "✅ Successfully ran Docker image"
	else
		echo "❌ Failed to run Docker image"
	fi
}
trap cleanup EXIT

echo "🚪 Entering Docker container..."
docker exec -ti "${container_id}" sh
