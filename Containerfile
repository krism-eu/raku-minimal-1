Repository: krism-eu/raku-minimal-1
Branch: main
Commit message: Add package-removal Containerfile

File: Containerfile

FROM ghcr.io/rakuos/kde:latest

COPY pacchetti-rimossi.txt /tmp/pacchetti-rimossi.txt

RUN set -eux; \
    pkgs_to_remove=""; \
    while IFS= read -r pkg || [ -n "$pkg" ]; do \
        case "$pkg" in ''|'#'*) continue ;; esac; \
        if rpm -q "$pkg" >/dev/null 2>&1; then \
            pkgs_to_remove="$pkgs_to_remove $pkg"; \
        else \
            echo "Skipping unavailable package: $pkg"; \
        fi; \
    done < /tmp/pacchetti-rimossi.txt; \
    if [ -n "$pkgs_to_remove" ]; then \
        echo "Removing packages:$pkgs_to_remove"; \
        dnf remove -y --setopt=clean_requirements_on_remove=1 $pkgs_to_remove; \
    else \
        echo "No packages to remove."; \
    fi; \
    dnf clean all; \
    rm -rf /var/cache/dnf /tmp/pacchetti-rimossi.txt
