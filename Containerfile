FROM quay.io/rakuos/rakuos-kde:latest

COPY pacchetti-rimossi.txt /tmp/pacchetti-rimossi.txt

# ============================================================
# FASE 1: verifica degli strumenti e preparazione della lista
# ============================================================

RUN set -eux; \
    command -v dnf; \
    command -v rpm; \
    command -v sed; \
    command -v sort; \
    test -s /tmp/pacchetti-rimossi.txt; \
    : > /tmp/pacchetti-da-rimuovere.txt; \
    while IFS= read -r pkg || [ -n "$pkg" ]; do \
        # Rimuove eventuali caratteri CR di file Windows CRLF
        pkg="$(printf '%s' "$pkg" | sed 's/\r$//')"; \
        \
        # Ignora righe vuote e commenti
        case "$pkg" in \
            ''|'#'*) \
                continue \
                ;; \
        esac; \
        \
        # Accetta solo nomi di pacchetto, non gruppi DNF o comandi
        case "$pkg" in \
            *[!A-Za-z0-9._+:-]*) \
                echo "ERROR: nome pacchetto non valido: [$pkg]" >&2; \
                exit 1 \
                ;; \
        esac; \
        \
        # Pacchetti fondamentali che non devono essere rimossi
        case "$pkg" in \
            dnf|dnf-*|\
            libdnf|libdnf-*|\
            rpm|rpm-*|\
            python3|python3-*|\
            coreutils|\
            filesystem|\
            systemd|systemd-*|\
            bash) \
                echo "PROTECTED: $pkg"; \
                continue \
                ;; \
        esac; \
        \
        # Inserisce solo pacchetti attualmente installati
        if rpm -q "$pkg" >/dev/null 2>&1; then \
            printf '%s\n' "$pkg" >> /tmp/pacchetti-da-rimuovere.txt; \
            echo "SELECTED: $pkg"; \
        else \
            echo "SKIP: pacchetto non installato: $pkg"; \
        fi; \
    done < /tmp/pacchetti-rimossi.txt; \
    \
    # Elimina eventuali duplicati
    sort -u /tmp/pacchetti-da-rimuovere.txt \
        -o /tmp/pacchetti-da-rimuovere.txt; \
    \
    echo "Lista finale dei pacchetti selezionati:"; \
    cat /tmp/pacchetti-da-rimuovere.txt


# ============================================================
# FASE 2: simulazione della transazione, senza modifiche
# ============================================================

RUN set -eux; \
    if [ -s /tmp/pacchetti-da-rimuovere.txt ]; then \
        set --; \
        while IFS= read -r pkg || [ -n "$pkg" ]; do \
            set -- "$@" "$pkg"; \
        done < /tmp/pacchetti-da-rimuovere.txt; \
        \
        echo "Simulazione rimozione:"; \
        dnf remove \
            --assumeno \
            --no-autoremove \
            --setopt=clean_requirements_on_remove=False \
            "$@"; \
    else \
        echo "Nessun pacchetto da rimuovere."; \
    fi


# ============================================================
# FASE 3: rimozione effettiva
# ============================================================

RUN set -eux; \
    if [ -s /tmp/pacchetti-da-rimuovere.txt ]; then \
        set --; \
        while IFS= read -r pkg || [ -n "$pkg" ]; do \
            set -- "$@" "$pkg"; \
        done < /tmp/pacchetti-da-rimuovere.txt; \
        \
        echo "Rimozione dei soli pacchetti selezionati:"; \
        dnf remove -y \
            --no-autoremove \
            --setopt=clean_requirements_on_remove=False \
            "$@"; \
    else \
        echo "Nessun pacchetto da rimuovere."; \
    fi


# ============================================================
# FASE 4: verifica del database RPM
# ============================================================

RUN set -eux; \
    rpm --verifydb; \
    rpm -qa >/dev/null


# ============================================================
# FASE 5: pulizia finale
# ============================================================

RUN set -eux; \
    dnf clean all; \
    rm -rf \
        /var/cache/dnf \
        /var/cache/yum \
        /tmp/pacchetti-rimossi.txt \
        /tmp/pacchetti-da-rimuovere.txt

CMD ["/sbin/init"]
