# Prompt pronto — simulazione dei tempi residui

Da incollare in una sessione **nuova e pulita** di Claude Code aperta in
`~/Documents/Matematics/frankl`. Non richiede nulla di questa conversazione.

---

Sei in un progetto di ricerca matematica (congettura di Frankl) che decide, con
solver SAT, se esistono famiglie union-closed invarianti per rotazione su m punti
che violino la congettura. Ho bisogno di una **stima dei tempi**, non di eseguire
calcoli.

**Vincolo assoluto: non lanciare nulla di pesante e non toccare i processi in corso.**
C'è un run CaDiCaL vivo da oltre 12 ore (PID nel file `STATE/HANDOFF.md`) sotto
watchdog: leggilo e basta. Analisi in sola lettura.

## Cosa devi produrre

Una simulazione ragionata del tempo necessario a **chiudere Z15** e, se ne vale la
pena, a proseguire. In particolare:

1. **Il run CaDiCaL su Z15 in corso** — finirà entro la scadenza del watchdog? Con
   che probabilità? Su cosa basi la risposta?
2. **La verifica del certificato con `drat-trim`**, che parte solo se CaDiCaL dice
   `s UNSATISFIABLE`. La prova è già oltre 11 GB: quanto tempo e quanta RAM servono?
   Verifica se il tetto di 9 GB per job è sufficiente, o se drat-trim va lanciato
   con un'eccezione.
3. **Il piano B: lo sharding** (task T8 nel backlog, mai eseguito). Se Z15 non si
   chiude col metodo monolitico: quanti shard servono, quanto costa ciascuno,
   quanto il totale, e si può parallelizzare sui core disponibili?
4. **Il totale realistico** per arrivare a "Z15 deciso e certificato", nei due
   scenari (il run in corso ce la fa / non ce la fa).
5. **Facoltativo, se i dati lo consentono onestamente:** Z16 e Z17 sono
   raggiungibili su questa macchina? Se no, dove si rompe — tempo, RAM o disco?

## Dove sono i dati (verificali, non fidarti dei numeri qui sotto)

- `RISULTATI.md` — risultati storici, incluso Z13 con certificato
- `results/FOUND.md` — Z14 chiuso: i tre esiti che lo dimostrano
- `STATE/backlog.md` — i task, con misure di orbite/clausole per ogni caso
- `STATE/journal.md` — cronologia con tempi misurati (è lungo: usa `grep`/`tail`,
  mai `cat`)
- `STATE/hardware.env` — budget di RAM, core e timeout della macchina
- `results/logs/` — i log dei solver. Le righe di progresso di CaDiCaL hanno il
  tempo in colonna 3, i conflitti in colonna 9 e **la percentuale di variabili
  ancora indecise nell'ultima colonna**: quest'ultima è il miglior segnale di
  avanzamento, molto più dei conflitti.

Numeri di riferimento raccolti finora (da riverificare):

| | Z13 | Z14 | Z15 |
|---|---|---|---|
| Orbite | 630 | 1.180 | 2.190 |
| Clausole CNF | 1,88 M | 6,24 M | 28,85 M |
| CP-SAT | 15,1 s | ~60–100 s | 889 s |
| CaDiCaL | non registrato | 2.240 s | in corso da 12h25m |
| Prova DRAT | 87 MB | 2,24 GB | 11,43 GB e cresce |
| drat-trim | 267 s (macchina storica) | 1.736 s | — |

Per Z14, drat-trim ha verificato 3.411.578 lemmi in core con 315.224.851 passi di
risoluzione. Z15 al momento: ~60,2 M conflitti, variabili residue **50%** — lo
stesso valore che Z14 aveva nell'istante in cui ha prodotto il verdetto, e su cui
Z15 è fermo da circa tre ore dopo essere sceso dal 75% fra l'ottava e la nona ora.

## Come voglio la risposta

- **Separa nettamente ciò che è misurato da ciò che è estrapolato.** I tempi di
  refutazione SAT non sono una funzione liscia della dimensione: dillo, e dai
  intervalli invece di numeri singoli.
- Motiva ogni estrapolazione con il dato da cui parte.
- Se un limite è di RAM o di disco invece che di tempo, segnalalo: conta più del tempo.
- Se i dati non bastano per una stima onesta, dillo invece di inventare un numero.
- Italiano, conciso, con una tabella riassuntiva finale.
