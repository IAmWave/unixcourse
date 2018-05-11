# mdcat

**mdcat** je nástroj na zobrazování textové aproximace souborů v _Markdownu_. Hodí se například, když se chceme rychle podívat na nějaký Markdownový soubor v čitelné podobě a nechce se nám kvůli tomu manuálně renderovat a otevírat prohlížeč.

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

### Příklad
mdcat velmi slušně vyrenderuje [README.md Reactu](https://github.com/facebook/react/blob/master/README.md). Problém má jen s nadpisem, kde se používá nestandardní githubový Markdown.
```
./mdcat.sh data/react_README.md
less data/react_README.md   # pro srovnani citelnosti (a jako ukazka viceradkovych bloku kodu)
```
Ve složce `data/` jsou další příklady ilustrující různé featury mdcatu.

## Hacking guide
mdcat počítá s poněkud zjednodušenou verzí Markdownu, která nicméně pokrývá velkou část skutečně využívaných funkcí.

V prvním kroku (`process_all()`) je text rozdělen do bloků. Bloky jsou pak renderované zvlášť podle jejich typu, nezávisle na ostatních blocích; jeden blok vykresluje `process_block()`. Existují čtyři typy bloků, každý se vykresluje jinak:
- **PARAGRAPH**: Normální odstavec textu; `process_paragraph()`.
    - Naformátuje na 80 znaků na řádek
    - Přidá styly (`font_styles()`)
- **HEADER**: Nadpis; `process_paragraph()`. Má na začátku 1 až 6 `#`. Musí být na jednom řádku.
    - Úroveň odstavce detekuje `get_header_level()`.
    - Nepřidává styly.
- **LIST**: Neuspořádaný seznam, potenciálně vnořený. Položky _začínají_ "- " nebo "* ".
    - `process_list()` standardizuje indentaci tak, že udržuje stack, kde je uloženo odsazení
        předchozích odrážek a podle toho určí indentaci momentální odrážky.
    - pomocí `process_paragraph()` nastyluje jednotlivé odrážky
- **CODE**: blok kódu.
    - Může být přes více odstavců; delimiter je řádek začínající třemi backticky.
    - Nepřidává styly, jen zvýrazní jinou barvou
