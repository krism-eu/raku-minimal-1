name: Build and Publish RakuOS Minimal

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Podman
        run: |
          sudo apt-get update
          sudo apt-get -y install podman

      - name: Log in to GitHub Container Registry
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | podman login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build image with Squash
        run: |
          podman build \
            --squash \
            -f Containerfile \
            -t ghcr.io/krism-eu/raku-minimal-1:latest \
            .

      - name: Verify image size and layers
        run: |
          echo "=== Immagine finale ==="
          podman images ghcr.io/krism-eu/raku-minimal-1:latest
          echo "=== Numero di layer (deve essere 1) ==="
          podman inspect ghcr.io/krism-eu/raku-minimal-1:latest --format '{{len .RootFS.Layers}}'

      - name: Push image to GHCR
        run: |
          podman push ghcr.io/krism-eu/raku-minimal-1:latest
