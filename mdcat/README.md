# mdcat

**mdcat** je nástroj na zobrazování textové aproximace souborů v _Markdownu_. Je vhodný, když se chceme rychle podívat na nějaký Markdownový soubor v čitelné podobě a nechce se nám kvůli tomu otevírat prohlížeč.

**Příklad:**
```
./mdcat.sh data/react_README.md
less data/react_README.md   # pro srovnani citelnosti
```

## Funkce
- zalamování dlouhých řádků _(viz první odstavec)_
- seznamy
    - což je zde self-evident
- styly písma
    - **tučné**
    - _kurzíva_ (jako podtržení)
    - **případně _dokonce oboje_**
    - `inline code`
- nadpisy
    - šest úrovní
- [odkazy včetně _stylovaných_](www.example.com)
    - defaultně je pro čitelnost skryta adresa, lze povolit přes `-l`
- bloky kódu _(viz Příklad)_
