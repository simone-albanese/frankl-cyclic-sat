# Obiettivo
Estendere i risultati di RISULTATI.md: decidere se esistono famiglie
union-closed Z14- e Z15-invarianti che violino la congettura di Frankl
(margine intero 2*maxfreq - |F| <= -1), oppure trovare un controesempio
generale alla congettura.

# Criteri di SUCCESS (uno qualunque)
- Candidato controesempio: famiglia che passa ENTRAMBI i checker indipendenti
  (ucs_core.check_family e checker2.verify) con 2*maxfreq < |F| su interi.
- Risultato negativo di valore: UNSAT per Z14 (taglie >= 3) confermato da due
  solver indipendenti o con certificato DRAT verificato da drat-trim.

# Vincoli di rigore ereditati
Aritmetica dei verdetti solo su interi; controlli (Z7, Z11, P([4])) PRIMA di
ogni run di produzione; ogni pipeline nuova va validata sui controlli prima
di credere ai suoi esiti; ratio < 0,382 => bug, fermarsi.

# Non-obiettivi
Niente riscritture estetiche del codice esistente; niente esplorazioni fuori
scope senza aggiungerle prima al backlog con stima costo/valore.
