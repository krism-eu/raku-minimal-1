FROM quay.io/rakuos/rakuos-kde:latest

# Copia la lista dei pacchetti da rimuovere
COPY pacchetti-rimossi.txt /tmp/pacchetti-rimossi.txt

# ------------------------------------------------------------
# 1. Installa i language pack e pulisce subito la cache
# ------------------------------------------------------------
RUN set -eux; \
    dnf install -y \
        --setopt=install_weak_deps=False \
        glibc-langpack-en \
        glibc-langpack-it; \
    dnf clean all

# ------------------------------------------------------------
# 2. Rimuove tutte le chiavi GPG (non servono in un'immagine bootc)
#    Risolve il problema "duplicate with gpg-pubkey" in bootc-image-builder
# ------------------------------------------------------------
RUN set -eux; \
    rpm -qa gpg-pubkey | xargs -r rpm --erase --allmatches || true

# ------------------------------------------------------------
# 3. Selezione dei pacchetti e rimozione sicura (loop)
# ------------------------------------------------------------
RUN set -eux; \
    : > /tmp/pacchetti-da-rimuovere.txt; \
    \
    # Filtra e valida i pacchetti, proteggendo i critici
    while IFS= read -r pkg || [ -n "$pkg" ]; do \
        pkg="$(printf '%s' "$pkg" | sed 's/\r$//')"; \
        case "$pkg" in ''|'#'*) continue ;; esac; \
        case "$pkg" in *[!A-Za-z0-9._+:-]*) echo "ERRORE: nome non valido: [$pkg]" >&2; exit 1 ;; esac; \
        case "$pkg" in \
            dnf|dnf-*|dnf5|dnf5-*|libdnf|libdnf-*|libdnf5|libdnf5-*|rpm|rpm-*|rpm-libs|rpm-plugin-*|python3|python3-*|bash|coreutils|filesystem|systemd|systemd-*|bootc|bootc-*|ostree|ostree-*|rpm-ostree|rpm-ostree-*|dracut|dracut-*|dbus|dbus-*|polkit|polkit-*) \
                echo "PROTECTED: $pkg"; continue ;; \
        esac; \
        case "$pkg" in \
            kernel-core|kernel-*-core|kernel-modules|kernel-*-modules|kernel-modules-core|kernel-*-modules-core|kernel-modules-extra|kernel-*-modules-extra|kernel-uki|kernel-*-uki) \
                echo "PROTECTED KERNEL: $pkg"; continue ;; \
        esac; \
        if rpm -q "$pkg" >/dev/null 2>&1; then \
            printf '%s\n' "$pkg" >> /tmp/pacchetti-da-rimuovere.txt; \
            echo "SELECTED: $pkg"; \
        else \
            echo "SKIP: $pkg"; \
        fi; \
    done < /tmp/pacchetti-rimossi.txt; \
    \
    sort -u /tmp/pacchetti-da-rimuovere.txt -o /tmp/pacchetti-da-rimuovere.txt; \
    \
    # Rimozione sicura in loop (si ferma al primo errore)
    if [ -s /tmp/pacchetti-da-rimuovere.txt ]; then \
        while IFS= read -r pkg; do \
            echo "Rimozione di: $pkg"; \
            logfile="/tmp/dnf-remove-$pkg.log"; \
            if dnf remove -y --no-autoremove --setopt=clean_requirements_on_remove=False "$pkg" >"$logfile" 2>&1; then \
                cat "$logfile"; \
                echo "OK: $pkg"; \
                rm -f "$logfile"; \
            else \
                cat "$logfile"; \
                echo "ERRORE durante la rimozione di: $pkg" >&2; \
                exit 1; \
            fi; \
        done < /tmp/pacchetti-da-rimuovere.txt; \
    else \
        echo "Nessun pacchetto da rimuovere."; \
    fi; \
    \
    # Pulizia finale nello stesso layer
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /tmp/pacchetti-rimossi.txt /tmp/pacchetti-da-rimuovere.txt /tmp/dnf-remove-*.log

# ------------------------------------------------------------
# 4. Verifica finale (senza rebuilddb)
# ------------------------------------------------------------
RUN set -eux; \
    rpm --verifydb; \
    rpm -q glibc-langpack-en; \
    rpm -q glibc-langpack-it

CMD ["/sbin/init"]
