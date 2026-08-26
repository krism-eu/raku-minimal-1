FROM quay.io/rakuos/rakuos-kde:latest

COPY pacchetti-rimossi.txt /tmp/pacchetti-rimossi.txt

RUN set -eux; \
    pkgs_to_remove=""; \
    while IFS= read -r pkg || [ -n "$pkg" ]; do \
        case "$pkg" in \
            ''|'#'*) continue ;; \
        esac; \
        case "$pkg" in \
            dnf|dnf-*|libdnf|libdnf-*|rpm|rpm-*|python3|python3-*|coreutils|filesystem|systemd|systemd-*|bash) \
                echo "PROTECTED: $pkg"; \
                continue \
                ;; \
        esac; \
        if rpm -q "$pkg" >/dev/null 2>&1; then \
            pkgs_to_remove="$pkgs_to_remove $pkg"; \
        else \
            echo "Skipping unavailable package: $pkg"; \
        fi; \
    done < /tmp/pacchetti-rimossi.txt; \
    if [ -n "$pkgs_to_remove" ]; then \
        echo "Removing packages:$pkgs_to_remove"; \
        dnf remove -y \
            --no-autoremove \
            $pkgs_to_remove; \
    else \
        echo "No packages to remove."; \
    fi; \
    command -v dnf; \
    command -v rpm; \
    command -v rm; \
    rpm --verifydb; \
    dnf clean all; \
    rm -rf /var/cache/dnf /tmp/pacchetti-rimossi.txt

CMD ["/sbin/init"]
