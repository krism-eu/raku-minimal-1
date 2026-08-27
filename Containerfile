FROM quay.io/rakuos/rakuos-kde:latest

COPY pacchetti-rimossi.txt /tmp/pacchetti-rimossi.txt


# ============================================================
# FASE 1
# Validazione della lista e individuazione dei pacchetti installati
# ============================================================

RUN set -eux; \
    command -v dnf; \
    command -v rpm; \
    command -v sed; \
    command -v sort; \
    test -f /tmp/pacchetti-rimossi.txt; \
    : > /tmp/pacchetti-da-rimuovere.txt; \
    \
    while IFS= read -r pkg || [ -n "$pkg" ]; do \
        # Rimuove il carattere CR dei file Windows CRLF
        pkg="$(printf '%s' "$pkg" | sed 's/\r$//')"; \
        \
        # Ignora righe vuote e commenti
        case "$pkg" in \
            ''|'#*') \
                continue \
                ;; \
        esac; \
        \
        # Accetta solamente nomi di pacchetti RPM validi
        case "$pkg" in \
            *[!A-Za-z0-9._+:-]*) \
                echo "ERRORE: nome pacchetto non valido: [$pkg]" >&2; \
                exit 1 \
                ;; \
        esac; \
        \
        # ----------------------------------------------------
        # Pacchetti fondamentali protetti
        # ----------------------------------------------------
        \
        case "$pkg" in \
            dnf|dnf-*|\
            dnf5|dnf5-*|\
            libdnf|libdnf-*|\
            libdnf5|libdnf5-*|\
            rpm|rpm-*|\
            rpm-libs|rpm-plugin-*|\
            python3|python3-*|\
            bash|\
            coreutils|\
            filesystem|\
            systemd|systemd-*|\
            bootc|bootc-*|\
            ostree|ostree-*|\
            rpm-ostree|rpm-ostree-*|\
            dracut|dracut-*|\
            dbus|dbus-*|\
            polkit|polkit-*) \
                echo "PROTECTED: $pkg"; \
                continue \
                ;; \
        esac; \
        \
        # ----------------------------------------------------
        # Protezione del kernel reale
        #
        # Il metapacchetto kernel-p03-v2 resta rimovibile.
        # Vengono invece protetti core e moduli.
        # ----------------------------------------------------
        \
        case "$pkg" in \
            kernel-core|\
            kernel-*-core|\
            kernel-modules|\
            kernel-*-modules|\
            kernel-modules-core|\
            kernel-*-modules-core|\
            kernel-modules-extra|\
            kernel-*-modules-extra|\
            kernel-uki|\
            kernel-*-uki) \
                echo "PROTECTED KERNEL COMPONENT: $pkg"; \
                continue \
                ;; \
        esac; \
        \
        # Se il pacchetto è installato, lo aggiunge alla lista
        if rpm -q "$pkg" >/dev/null 2>&1; then \
            printf '%s\n' "$pkg" >> /tmp/pacchetti-da-rimuovere.txt; \
            echo "SELECTED: $pkg"; \
        else \
            echo "SKIP: pacchetto non installato: $pkg"; \
        fi; \
    done < /tmp/pacchetti-rimossi.txt; \
    \
    # Elimina duplicati
    sort -u \
        /tmp/pacchetti-da-rimuovere.txt \
        -o /tmp/pacchetti-da-rimuovere.txt; \
    \
    echo; \
    echo "Lista finale dei pacchetti selezionati:"; \
    cat /tmp/pacchetti-da-rimuovere.txt || true


# ============================================================
# FASE 2
# Simulazione della rimozione
# ============================================================

RUN set -eu; \
    if [ -s /tmp/pacchetti-da-rimuovere.txt ]; then \
        while IFS= read -r pkg || [ -n "$pkg" ]; do \
            echo; \
            echo "Simulazione rimozione: $pkg"; \
            \
            dnf remove \
                --assumeno \
                --no-autoremove \
                --setopt=clean_requirements_on_remove=False \
                "$pkg"; \
        done < /tmp/pacchetti-da-rimuovere.txt; \
    else \
        echo "Nessun pacchetto da rimuovere."; \
    fi


# ============================================================
# FASE 3
# Rimozione effettiva, un pacchetto alla volta
# ============================================================

RUN set -eu; \
    if [ -s /tmp/pacchetti-da-rimuovere.txt ]; then \
        while IFS= read -r pkg || [ -n "$pkg" ]; do \
            echo; \
            echo "================================================"; \
            echo "Rimozione: $pkg"; \
            echo "================================================"; \
            \
            logfile="/tmp/dnf-remove.log"; \
            \
            if dnf remove -y \
                --no-autoremove \
                --setopt=clean_requirements_on_remove=False \
                "$pkg" >"$logfile" 2>&1; then \
                \
                cat "$logfile"; \
                echo "OK: $pkg"; \
                rm -f "$logfile"; \
            else \
                \
                cat "$logfile"; \
                echo; \
                echo "ERRORE durante la rimozione di: $pkg" >&2; \
                exit 1; \
            fi; \
        done < /tmp/pacchetti-da-rimuovere.txt; \
    else \
        echo "Nessun pacchetto da rimuovere."; \
    fi


# ============================================================
# FASE 4
# Verifica del database RPM dopo le rimozioni
# ============================================================

RUN set -eux; \
    rpm --verifydb; \
    rpm -qa >/dev/null


# ============================================================
# FASE 5
# Pulizia cache e file temporanei
# ============================================================

RUN set -eux; \
    dnf clean all; \
    rm -rf \
        /var/cache/dnf \
        /var/cache/yum \
        /tmp/pacchetti-rimossi.txt \
        /tmp/pacchetti-da-rimuovere.txt \
        /tmp/dnf-remove.log


# ============================================================
# Avvio dell'immagine bootc
# ============================================================

CMD ["/sbin/init"]
