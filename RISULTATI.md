# Sessione di ricerca: controesempi alla congettura union-closed (Frankl)

Data: 10 agosto 2026 · Ambiente: Python 3.12.3, OR-tools CP-SAT · Aritmetica dei verdetti: solo interi (condizione di controesempio: 2·maxfreq < |F|).

## 1. Stato dell'arte (Passo 0, sintesi con fonti nella chat)

La congettura è aperta. Bound inferiori sulla frequenza massima: Gilmer 2022 (0,01·|F|), poi (3−√5)/2 ≈ 0,38197 (Alweiss–Huang–Sellke; Chase–Lovett; Sawin; Pebody), raffinato a ≈ 0,38234 (Yu) e ≈ 0,3824–0,3827 (Liu, a seconda della fonte). Chase–Lovett: (3−√5)/2 è ottimale per la versione approssimata (barriera per i metodi entropici). Verifiche esaustive: universi con ≤ 12 elementi (Živković–Vučković 2017); famiglie con ≤ 46 insiemi; se il controesempio minimo ha m elementi, ogni controesempio ha ≥ 4m−1 insiemi (Lo Faro; Roberts–Simpson) → con m ≥ 13, |F| ≥ 51. Un controesempio non contiene insiemi di taglia 1 o 2 (Sarvate–Renaud). WLOG ∅ ∈ F (aggiungerlo preserva la chiusura e abbassa tutte le frequenze relative). Caso transitivo: Aaronson–Ellis–Leader 2021 dimostrano la congettura per la famiglia di TUTTE le unioni dei traslati di UN insieme fisso in un gruppo abeliano (caso 1-seme); il caso multi-orbita non risulta coperto.

## 2. Controlli di protocollo (tutti superati)

- Negativo: P([4]) → |F|=16, maxf=8, margine 2·maxf−|F| = 0 esatto (tight, non controesempio).
- Validatore: {{0},{1}} rifiutata (manca {0,1}). Questo controllo ha scoperto un bug reale di flusso nel checker n.1 (violazioni <3 marcate come "chiuso"), corretto prima di ogni run.
- Detector: sei singleton → 2·maxf=2 < 6 rilevato; verdetto complessivo correttamente False (famiglia non chiusa).
- Accordo checker1 (bitmask) / checker2 (frozenset+Counter, implementazione indipendente): 50/50 su chiusure casuali.

## 3. Risultato principale (SAT esatto, famiglie cicliche-invarianti)

Modello: variabile booleana per ognuna delle 630 orbite cicliche non banali di Z₁₃ (∅ e Z₁₃ sempre inclusi; i loro contributi al margine si cancellano). Margine M = Σ (2s−13)x_O; chiusura: 1.863.311 clausole ¬x₁∨¬x₂∨x_target.

- Controlli pipeline: Z₇ e Z₁₁ → INFEASIBLE (come impone la teoria: congettura vera per m ≤ 12). Encoding validato.
- **Z₁₃, vincolo M ≤ −1: INFEASIBLE/UNSAT, ora con certificato verificato.** Quattro conferme concordi e via via più forti: (1) CP-SAT, vincolo lineare nativo, 72 s; (2) pysat/CaDiCaL 1.5.3, encoding ad addizionatori binari validato per forza bruta, UNSAT in 325,6 s; (3) CaDiCaL 2.x compilato da sorgente sul DIMACS esportato (4752 variabili, 1.884.943 clausole), s UNSATISFIABLE con emissione di prova; (4) **certificato DRAT (87 MB) verificato da drat-trim: s VERIFIED in 266,75 s** (481.643 lemmi nel core, ~39,8 M passi di risoluzione). L'intera catena dump→solve→verify è stata prima validata end-to-end su Z₇ e Z₁₁ (UNSAT + VERIFIED). Residuo di fiducia: la sola correttezza della *generazione* della formula, mitigata da due encoder indipendenti concordi e dai controlli. Poiché ogni gruppo transitivo su 13 punti contiene un 13-ciclo (Cauchy), il risultato copre ogni famiglia invariante sotto QUALSIASI gruppo transitivo su 13 punti, ed estende (sperimentalmente) il caso 1-seme di Aaronson–Ellis–Leader al caso multi-seme su Z₁₃.
- Ottimizzazione: min M = 0 (OPTIMAL), raggiunto solo dal power set (|F|=8192) — quasi-controesempio tight banale.
- Regione ammissibile per un controesempio (taglie ≥ 3): min M = 11 (OPTIMAL), |F|=15 (orbita dei 12-set + Z₁₃ + ∅), f = 13, ratio 13/15 ≈ 0,867. Cross-check: l'enumerazione indipendente dà margine scalato 143 = 13·11 per la stessa famiglia.

## 4. Copertura complementare

- Enumerazione esaustiva 1-seme: Z₁₃ 630/630, Z₁₄ 1180/1180, Z₁₅ 666/666 (solo taglie ≤ 6, parziale dichiarato): zero candidati; tight solo power set (eventualmente "a blocchi"). Conferma sperimentale del teorema AEL.
- Campione 800 coppie di semi su Z₁₃: zero candidati; miglior margine M = 32 (|F|=54, ratio 43/54 ≈ 0,796).
- Annealing sui generatori (m ≤ 16): modalità libera converge al power set (margine 0 — calibrazione riuscita); modalità con generatori di taglia ≥ 3 (48 run): miglior margine 2 (|F|=10, ratio 3/5 = 0,6). Nessun margine negativo.
- Costruzioni strutturate su 13 punti (tutte con conteggi previsti a mano e verificati): PG(2,3) → |F|=704, ratio 507/704 ≈ 0,720; STS(13) ciclico → |F|=4032, ratio 1205/2016 ≈ 0,598 (la migliore ratio "strutturata"); QR(13) → |F|=210, ratio 27/35 ≈ 0,771; intervalli (run ≥ 3) → |F|=522, ratio 37/58 ≈ 0,638. Up-set esclusi a priori (maxf ≥ |F|/2 per iniezione S ↦ S∪{x}).

## 5. Seconda fase: tentativi su Z₁₄/Z₁₅ e lezioni

Il modello monolitico CP-SAT per Z₁₄ (7,32 M clausole) supera la RAM disponibile (OOM-kill a 3,94 GB documentato). Due strade esplorate: (a) CEGAR (chiusura lazy: si parte dal solo vincolo di margine e si aggiungono clausole solo quando violate) — corretto per costruzione e validato su Z₇/Z₁₁, ma su Z₁₃ il rilassamento è risultato *più difficile* da refutare del modello completo (timeout: meno vincoli possono rendere più arduo l'UNSAT); (b) pipeline pysat/CaDiCaL con clausole in **streaming** (memoria C-side: build di Z₁₄ in 13 s, ~930 MB stabili) e margine via encoder ad addizionatori binari. La (b) ha prodotto la conferma indipendente di Z₁₃; su Z₁₄ (ristretto a taglie ≥ 3, restrizione valida per ogni controesempio, Sarvate–Renaud) il run è rimasto senza verdetto nel budget di sessione: esito onesto UNKNOWN, con il collo di bottiglia identificato nella propagazione debole dell'encoding pseudo-Booleano rispetto al vincolo lineare nativo.

## 6. Valutazione onesta

Il passo di certificazione chiude il primo dei "prossimi passi" della prima fase: il teorema di sessione su Z₁₃ non dipende più dalla fiducia in un singolo solver. Restano non decisi Z₁₄ e Z₁₅ multi-orbita (due run CaDiCaL da 20+ minuti senza verdetto; CP-SAT monolitico OOM a 3,94 GB): esito dichiarato UNKNOWN.

Nessun candidato: ogni famiglia chiusa esaminata ha margine ≥ 0, e ratio < 0,5 non è mai comparsa (coerente col tripwire: mai nulla vicino a 0,382). Il contributo non banale della sessione è la decisione esatta del caso Z₁₃-invariante generale (multi-orbita), che non risulta coperto dalla letteratura, insieme al margine minimo certificato M = 11 nella regione senza taglie 1–2. Limiti: Z₁₄ multi-orbita non deciso (7,3 M clausole oltre la memoria disponibile), Z₁₅ SAT non tentato, annealing euristico, CP-SAT senza certificato verificabile.

## 6. Prossimi passi

(1) ~~Certificato DRAT per Z₁₃~~ — fatto e verificato in questa sessione. (2) Z₁₄/Z₁₅ multi-orbita con encoding compatto (variabili ausiliarie di coppia o solver PB nativo). (3) Gruppi transitivi su 14–16 punti privi di cicli lunghi (dove il corollario di Cauchy non si applica). (4) Local search con obiettivi surrogati (media taglie vs m/2) e mosse su orbite anziché su generatori.

## File

`ucs_core.py` (bitmask, chiusura, checker n.1) · `pb_adder.py` (encoder PB auto-validato) · `sat2_cyclic.py` (pipeline pysat/CaDiCaL) · `cegar.py` (raffinamento lazy) · `dump_dimacs.py` (esportazione DIMACS per la catena di certificazione; z13.cnf e la prova DRAT da 87 MB sono rigenerabili con dump_dimacs + CaDiCaL + drat-trim) · `checker2.py` (verificatore indipendente) · `controls.py` (controlli obbligatori) · `cyclic_enum.py` (enumerazione) · `sat_cyclic.py` (CP-SAT) · `anneal.py` (ricerca locale) · `structured.py` (costruzioni con assert manuali).
