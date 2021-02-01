-- Codice SQL per la creazione del db --
-- è sufficiente un copia/incolla sul querytool --

------------------------------------------------------------------------------------------------------------------------------------
-- TABELLE -------------------------------------------------------------------------------------------------------------------------

create table Area(
    nome                varchar(32),
    numero_abitazioni   integer check(numero_abitazioni>=0) not null default 0,

    constraint pk_area primary key(nome)
);

create table Genere(
    nome    varchar(32),
    
    constraint pk_Genere primary key (nome)
);

create table Abitazione(
    id              oid, -- PostgreSQL Object IDentifier data-type
    genere          varchar(32) not null,  
    numero_gabbie   integer check(numero_gabbie>=0) not null default 0,
    area            varchar(32) not null,

    constraint pk_Abitazione primary key (id),
    constraint fk_genere_Abitazione_Genere foreign key (genere) references Genere(nome)
        on delete restrict -- non posso eliminare un genere se è ancora assegnato a qualche abitazione
        on update cascade,
    constraint fk_area_Abitazione_Area foreign key (area) references Area(nome)
        on delete restrict -- non posso eliminare un area se contiene ancora delle abitazioni
        on update cascade
);

create table Gabbia(
    id          oid, -- PostgreSQL Object IDentifier data-type
    abitazione  oid not null,

    constraint pk_Gabbia primary key (id),
    constraint fk_abitazione_Gabbia_Abitazione foreign key (abitazione) references Abitazione(id)
        on delete restrict -- non posso eliminare un'abitazione finché contiene gabbie o rimarrebbero non assegnate
        on update cascade
);

create table Esemplare(
    id                  oid, -- PostgreSQL Object IDentifier data-type
    genere              varchar(32),
    nome                varchar(32) not null,
    sesso               varchar(1) check(sesso IN ( 'F' , 'M' )) not null,
    paese_provenienza   varchar(32) not null,
    data_nascita        date,
    data_arrivo         date not null,
    gabbia              oid unique not null, -- il vincolo unique garantisce che non si possano assegnare più esemplari nella stessa gabbia

    constraint pk_Esemplare primary key(id,genere),
    constraint fk_genere_Esemplare_Genere foreign key (genere) references Genere(nome)
        on delete restrict -- non posso eliminare un genere finché ho esemplari che ne fanno parte
        on update cascade,
    constraint fk_gabbia_Esemplare_Gabbia foreign key (gabbia) references Gabbia(id)
        on delete restrict -- non posso eliminare una gabbia se un esemplare è in essa contenuto
        on update cascade
);

create table Addetto_pulizie(
    CF              char(16) check(length(CF) = 16),
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 
    turno_pulizia   varchar(64) not null,

    constraint pk_Addetto_pulizie primary key (CF)
);

create table Pulire(
    addetto_pulizie     char(16) check(length(addetto_pulizie) = 16),
    abitazione          oid, -- PostgreSQL Object IDentifier data-type

    constraint pk_Pulire primary key (addetto_pulizie,abitazione),
    constraint fk_addetto_pulizie_Pulire_Addetto_pulizie foreign key (addetto_pulizie) references Addetto_pulizie(CF)
        on delete cascade -- se viene rimosso un addetto alle pulizie, rimuovo automaticamente tutte le relazioni pulire di cui faceva parte
        on update cascade,
    constraint fk_abitazione_Pulire_Abitazione foreign key (abitazione) references Abitazione(id) 
        on delete cascade -- se viene rimossa un'abitazione, rimuovo automaticamente tutte le relazioni pulire di cui faceva parte
        on update cascade
);

create table Veterinario(
    CF              char(16) check(length(CF) = 16),
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 

    constraint pk_Veterinario primary key (CF)
);

create table Visita(
    veterinario     char(16) check(length(veterinario) = 16),
    esemplare_id    oid, 
    esemplare_gen   varchar(32), 
    data            date,
    peso            integer check(peso > 0) not null, 
    diagnostica     varchar(1024) not null, 
    dieta           varchar(1024) not null,

    constraint pk_Visita primary key (veterinario,esemplare_id,esemplare_gen,data),
    constraint fk_veterinario_Visita_Veterinario foreign key (veterinario) references Veterinario(CF)
        on delete restrict -- non posso eliminare un veterinario dal DB se ho delle visite da lui effettuate nello storico
        on update cascade,
    constraint fk_esemplare_gen_Visita_Genere foreign key (esemplare_gen,esemplare_id) references Esemplare(genere,id) 
        on delete cascade -- se un esemplare viene rimosso, cancello tutte le visite eseguite su di esso
        on update cascade 
);

------------------------------------------------------------------------------------------------------------------------------------------
-- FUNZIONI SQL RELATIVE AI TRIGGER PER I VINCOLI DI INTEGRITA'   ------------------------------------------------------------------------

-- 1) All'aggiunta (INSERT/UPDATE) di un esemplare ad una gabbia bisogna controllare che l'abitazione in cui essa sia contenuta abbia il genere corretto.
-- 2) Alla modifica (spostamento) (UPDATE) di una gabbia in una abitazione, bisogna controllare che il genere dell'animale in essa contenuto combaci con quello assegnato alla nuova abitazione di dest.
--     nb: non serve eseguire il check sull'inserimento perchè bisogna prima aggiungere una gabbia e poi assegnarli un animale, di conseguenza non è possibile assegnare una gabbia errata alla sua aggiunta in quanto sono sempre vuote durante la creazione.
-- 3) All'aggiunta (INSERT/UPDATE) di un esemplare bisogna controllare che data arrivo >= data nascita.
-- 4) All'aggiunta (INSERT/UPDATE) di una visita bisogna controllare che data visita > data arrivo esemplare.
-- 5) Alla modifica di un genere assegnato (UPDATE) ad un'abitazione, bisogna controllare che non vengano violati i vincoli di genere
--     nb: non serve il check sull'insert perchè non puoi inserire una abitaziono già con delle gabbie (non c'è rischio che queste violino il vincolo di genere perchè vengono aggiunte e controllate successivamente)
-- 6) Alla modifica della data di arrivo di un esemplare bisogna controllare che questa sia coerente con le date delle visite: una visita non può essere stato effattuata prima che un esemplare sia arrivato nello zoo.

-------------------------------------------------------------------------------------------------------------------------------------------

-- 1) All'aggiunta (INSERT/UPDATE) di un esemplare ad una gabbia bisogna controllare che l'abitazione in cui essa è contenuta abbia il genere corretto (che combaci con quello dell'esemplare).
-- 3) All'aggiunta (INSERT/UPDATE) di un esemplare (nello zoo) bisogna controllare che data arrivo > data nascita.
-- 6) Alla modifica della data di arrivo di un esemplare bisogna controllare che questa sia coerente con le date delle visite: una visita non può essere stato effattuata prima che un esemplare sia arrivato nello zoo.
create or replace function aggiunta_modifica_esemplare() -- checks n° 1,3 & 6
returns trigger
as
$$
begin

-- controllo del vincolo n°1 --> controllo che il genere dell’esemplare che sto aggiungendo/spostando 
--                               sia lo stesso dell’abitazione di destinazione (che ottengo andando a 
--                               guardare dov’è collocata la gabbia)

    perform *
    from(select    A.genere -- ottengo il genere assegnato all'abitazione contenente la gabbia.
        from       Abitazione A
        where      A.id IN(select    G.abitazione -- ottengo l'id dell'abit. della gabbia in cui sto inserendo l'esemp.
                             from    Gabbia G
                            where    G.id = new.gabbia)) genere_ok
    where new.genere = genere_ok.genere;

    if found then -- if found == true allora posso procedere con il controllo del vincolo n°3 (sulle date)
    	if(new.data_arrivo <= new.data_nascita) then -- controllo coerenza delle date, se il controllo risulta vero (quindi date incoerenti, lancio un'eccezione e interrompo l'op.)
            if(TG_OP = 'UPDATE') then
               raise exception 'Operazione di UPDATE non consentita! La modifica delle date ha portato a delle incongruenze! Vincolo da rispettare: la data di nascita deve essere antecedente o uguale alla data di arrivo';
            elseif(TG_OP = 'INSERT') then
               raise exception 'Operazione di INSERT non consentita! L''esemplare possiede delle incongruenze sulle date! Vincolo da rispettare: la data di nascita deve essere antecedente o uguale alla data di arrivo';
            end if;
        end if; -- endif del controllo date
        
        perform *   -- se arrivo qui, le date sono coerenti e pure il vincolo di genere, continuo controllando il vincolo n°6
        from    Visita V
        where   V.esemplare_id = new.id and V.esemplare_gen = new.genere and V.data < new.data_arrivo;

        if found then -- cerco visite la cui data è antecedente alla nuova data di arrivo, se le trovo lancio un'eccezione, altrimenti tutti i 3 controlli sono stati passati con successo: ritorno la tupla "new"!
            raise exception 'Operazione di UPDATE non consentita! La modifica della data di arrivo ha causato un''incongruenza: ci sono visite effettuate prima della nuova data di arrivo dell''esemplare ma non si può aver Visitato un esemplare prima che questo sia arrivato nello zoo.';
        end if;
        return new;
    end if; -- endif del primo controllo
    
    -- se mi trovo qui il primo controllo (sul vincolo di genere è fallito, interrompo l'esecuzione e lancio un'eccezione)
    if(TG_OP = 'UPDATE') then
        if(new.genere = old.genere) then
            raise exception 'Operazione di UPDATE non consentita! La gabbia in cui si vuole spostare l''esemplare è contenuta in un abitazione il cui genere assegnato differisce da quello dell''esemplare';
        elseif(new.gabbia = old.gabbia) then
            raise exception 'Operazione di UPDATE non consentita! Il nuovo genere assegnato all''esemplare non concide con quello assegnato all''abitazione in cui è contenuta la sua gabbia';
        end if;
        raise exception 'Operazione di UPDATE non consentita! ';
    elseif(TG_OP = 'INSERT') then
       raise exception 'Operazione di INSERT non consentita! La gabbia in cui si vuole inserire l''esemplare è contenuta in un abitazione il cui genere assegnato differisce da quello dell''esemplare';
    end if;

end;
$$ language plpgsql;


-- 2) Alla modifica (spostamento) (UPDATE) di una gabbia in una abitazione, bisogna controllare che il genere dell'animale in essa contenuto combaci con quello assegnato alla nuova abitazione di destinazione.
create or replace function modifica_gabbia() -- checks n° 2
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- Se la gabbia G1 contiene un esemplare del genere A, posso spostarla in abitazioni il cui genere assegnato è lo stesso, altrimenti violerei il vincolo di genere!

begin -- CASO 1: spostamento di una gabbia con un esemplare assegnato

    perform *
	from(select  E.genere  -- ottengo il genere dell'esemplare assegnato alla gabbia che sto spostando
         from    Esemplare E
         where   E.gabbia IN(select  G.id
                             from    Gabbia G
                             where   G.id = new.id)) genere_esemplare
	where (genere_esemplare.genere IN(select   A.genere -- ottengo il genere assegnato all'abitazione in cui sto cercando di spostare/aggiungere la gabbia
                                       from    Abitazione A
                                      where    A.id = new.abitazione));  -- Se la gabbia è vuota, bisogna poterla spostare

    if found then -- se la gabbia è piena e l'esemplare ha lo stesso genere della nuova abitazione di dest., allora è tutto ok
       return NEW;
    end if; -- se non è così, prima controllo se ci troviamo nel caso in cui la gabbia è vuota, se è vuota allora ok, se è piena allora vuol dire che sto violando il vincolo di genere!
	
    begin -- CASO 2: gestione del caso in cui la gabbia da spostare è vuota, di conseguenza il CASO 1 ritornerà false su "if found" ma la gabbia può comunque essere spostata perchè è vuota!
    
        perform *
        from    Esemplare E2
        where   E2.gabbia = new.id;
    
    	if not found then -- la gabbia è vuota
    		return NEW;
    	end if; -- la gabbia non è vuota, allora contiene un esemplare di genere errato! lancio un'eccezione
    	 	raise exception 'Operazione di UPDATE non consentita! Stai spostando una gabbia il cui esemplare contenuto appartiene ad un genere diverso di quello assegnato all''abitazione di destinazione! ';
    end;
end;
$$ language plpgsql;


-- 4) All'aggiunta (INSERT/UPDATE) di una visita bisogna controllare che data visita > data arrivo esemplare.
create or replace function aggiunta_modifica_visita() -- checks n° 4
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- All'aggiunta o modifica di una visita bisogna controllare che il campo data sia coerente, ovvero che la data di nessuna visita non sia antecedente a quella di arrivo dell'esemplare nello zoo in quanto non è possibile!
    -- Inoltre bisogna anche controllare che esista l'esemplare prima di controllarne la data

begin -- controllo prima che l'esemplare specificato dalla visita esista, poi controllerò la coerenza delle date.
                -- (NB: è opzionale..., lo fa già postreSQL controllando l'esistenza della chiave esterna, ma così gestiamo meglio l'errore)
    perform *
    from    Esemplare E
    where   E.id = new.esemplare_id and E.genere = new.esemplare_gen;

    if not found then -- eccezione nel caso in cui non esista l'esemplare (NB: è opzionale..., lo fa già postreSQL controllando l'esistenza della chiave esterna, ma così gestiamo meglio l'errore)
        raise exception 'Operazione di INSERT/UPDATE non consentita! L''esemplare a cui fa riferimento la visita non esiste';
    end if;

    begin -- una volta assicurati che l'esemplare visitato esista, controllo la coerenza delle date
        perform *
        from    Esemplare E
        where   E.id = new.esemplare_id and E.genere = new.esemplare_gen and E.data_arrivo <= new.data;

        if found then   -- date coerenti
            return NEW;
        end if;

        -- date non coerenti, lancio un'eccezione
        if(TG_OP = 'UPDATE') then
            raise exception 'Operazione di UPDATE non consentita! Non è possibile aver Visitato un esemplare prima che questo sia arrivato allo zoo!';
        elseif(TG_OP = 'INSERT') then
            raise exception 'Operazione di INSERT non consentita! Non è possibile aver Visitato un esemplare prima che questo sia arrivato allo zoo!';
        end if;

    end;
end;
$$ language plpgsql;


-- 5) Alla modifica di un genere assegnato (UPDATE) ad un'abitazione, bisogna controllare che non vengano violati i vincoli di genere
create or replace function modifica_genere_abitazione() -- checks n° 5
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- se nell'abitazione A ci sono gabbie con esemplari di genere X, prima di cambiare il genere assegnato in Y devo spostare
    -- questi esemplari/gabbie altrove, altrimenti ad update completato avrei un'abitazione con genere assegnato X ma esemplari di genere Y al suo interno!
    -- nb: non serve il check sull'insert perchè non puoi inserire una abitazione già con delle gabbie (non c'è rischio che queste violino il vincolo di genere perchè vengono aggiunte e controllate successivamente)
begin

    perform *   -- cerco degli esemplari contenuti in gabbie dell'abitazione di cui sto cambiando genere, se ne trovo, allora non posso cambiare il genere o violerei il vincolo di genere!
    from    Gabbia G
    where   (G.abitazione = new.id) and (new.genere NOT IN (select E.genere
                                                            from   Esemplare E
                                                            where  E.gabbia = G.id));

    if found then
        raise exception 'Operazione di UPDATE non consentita! Non puoi cambiare genere assegnato a questa abitazione perché contiene ancora gabbie con esemplari del vecchio genere!';
    end if;
        return new; -- l'abitazione non ha gabbie con esemplari del vechio genere, allora posso cambiarlo

end;
$$ language plpgsql;

--------------------------------------------------------------------------------------------------------------------------------------------
-- TRIGGERS x VINCOLI DI INTEGRITA'  -------------------------------------------------------------------------------------------------------

create trigger aggiunta_modifica_esemplare -- checks condition n° 1 & 3 & 6 when new esemplare is added
before insert or update of data_arrivo,data_nascita,genere,gabbia on Esemplare
for each row
execute procedure aggiunta_modifica_esemplare();

create trigger modifica_gabbia -- checks n° 2
before update of abitazione on Gabbia
for each row
execute procedure modifica_gabbia();

create trigger aggiunta_modifica_visita -- checks n° 4
before insert or update of data on Visita
for each row
execute procedure aggiunta_modifica_visita();

create trigger modifica_genere_abitazione -- checks n° 5
before update of genere on Abitazione
for each row
execute procedure modifica_genere_abitazione();

------------------------------------------------------------------------------------------------------------------------------------------
-- FUNZIONI SQL RELATIVE AIGLI ATTRIBUTI DERIVATI   --------------------------------------------------------------------------------------

-- 1) All'aggiunta/spostamento/rimozione di una gabbia bisogna aggiornare l'attributo derivato n_gabbie sulle abitazioni interessate.
-- 2) All'aggiunta/spostamento/rimozione di una abitazione bisogna aggiornare l'attributo derivato n_abitazioni sulle aree interessate.
-- 3) Alla creazione di abitazioni/gabbie l'attributo derivato dovrebbe essere inizializzato a 0
-- 4) Bisogna negare la modifca manuale all'utente degli attributi Abitazione.numero_gabbie e Area.numero_abitazioni

-------------------------------------------------------------------------------------------------------------------------------------------

-- 1) All'aggiunta/spostamento/rimozione di una gabbia bisogna aggiornare l'attributo derivato n_gabbie sulle abitazioni interessate.
create or replace function aggiorna_numero_gabbie() -- exectues n°1
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- dopo aver eseguito update/insert/delete di un gabbia, calcolo il numero di gabbie contenute nella sua nuova abitazione (inesistente nel caso di insert) di apparteneneza e ne aggiorno il campo (che sarà +1)
    -- eseguo la stessa operazione per la sua vecchia abitazione di appartenenza (inesistente nel caso di insert) (che sarà -1)
begin

    -- PRIMA RIGA: disattivazione temporanea del trigger che vieta le modifiche dell’attributo derivato --
    -- è stato implementato un trigger che vieta all’utente di eseguire degli update manuali sull’attributo derivato 
    -- per evitare che inserisca valori inconsistenti. Questo trigger va disabilitato temporaneamente durante l’aggiornamento 
    -- (eseguito da codice, quindi non manuale) del relativo attributo derivato.
    ALTER TABLE Abitazione DISABLE TRIGGER deny_modifica_manuale_numero_gabbie;

    update Abitazione set numero_gabbie = (select  count(*)
        									from   Gabbia G
        									where  G.abitazione = new.abitazione)
    where  id = new.abitazione;

    update Abitazione set numero_gabbie = (select  count(*)
        									from   Gabbia G
        									where  G.abitazione = old.abitazione)
    where  id = old.abitazione;

	ALTER TABLE Abitazione ENABLE TRIGGER deny_modifica_manuale_numero_gabbie;	

	return new;

end;
$$ language plpgsql;

-- 4) Bisogna negare la modifca manuale all'utente degli attributi Abitazione.numero_gabbie e Area.numero_abitazioni
create or replace function deny_modifica_manuale_numero_gabbie() -- executes n°4
returns trigger
as
$$
begin

    if(new.numero_gabbie != old.numero_gabbie) then
        raise exception'MODIFICA DI UN ATTRIBUTO DERIVATO: Il numero di gabbie contenute in un''abitazione è un attributo derivato e quindi non può essere modificato manualmente! verrà reimpostato al valore corretto!';
    end if;
        return new;

end;
$$ language plpgsql;

-- 3) Alla creazione di abitazioni/gabbie l'attributo derivato dovrebbe essere inizializzato a 0
create or replace function set_default_numero_gabbie() -- exectues n°3
returns trigger
as
$$
begin

if(new.numero_gabbie != 0) then
    new.numero_gabbie := 0;
    raise warning 'Il numero di gabbie è stato impostato a 0 in quanto il valore presente nella query di INSERT non era valido';
    return new;
end if;
return new;

end;
$$ language plpgsql;

-- 2) All'aggiunta/spostamento/rimozione di una abitazione bisogna aggiornare l'attributo derivato n_abitazioni sulle aree interessate.
create or replace function aggiorna_numero_abitazioni() -- exectues n°2
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- dopo aver eseguito update/insert/delete di un abitazione, calcolo il numero di abitazioni contenute nella sua nuova area (inesistente nel caso di insert) di apparteneneza e ne aggiorno il campo (che sarà +1)
    -- eseguo la stessa operazione per la sua vecchia area di appartenenza (inesistente nel caso di insert) (che sarà -1)
begin

    -- PRIMA RIGA: disattivazione temporanea del trigger che vieta le modifiche dell’attributo derivato --
    -- è stato implementato un trigger che vieta all’utente di eseguire degli update manuali sull’attributo derivato 
    -- per evitare che inserisca valori inconsistenti. Questo trigger va disabilitato temporaneamente durante l’aggiornamento 
    -- (eseguito da codice, quindi non manuale) del relativo attributo derivato.
    ALTER TABLE Area DISABLE TRIGGER deny_modifica_manuale_numero_abitazioni;

    update Area set numero_abitazioni = (select  count(*)
        								  from   Abitazione A
        								 where   A.area = new.area)
    where  nome = new.area;

    update Area set numero_abitazioni = (select   count(*)
        								  from   Abitazione A
        								 where   A.area = old.area)
    where  nome = old.area;

	ALTER TABLE Area ENABLE TRIGGER deny_modifica_manuale_numero_abitazioni;	 

	return new;

end;
$$ language plpgsql;


-- 4) Bisogna negare la modifca manuale all'utente degli attributi Abitazione.numero_gabbie e Area.numero_abitazioni
create or replace function deny_modifica_manuale_numero_abitazioni() -- executes n°4
returns trigger
as
$$
begin

    if(new.numero_abitazioni != old.numero_abitazioni) then
        raise exception 'MODIFICA DI UN ATTRIBUTO DERIVATO: Il numero di abitazioni contenute in un''area è un attributo derivato e quindi non può essere modificato manualmente! verrà reimpostato al valore corretto!';
    end if;
        return new;

end;
$$ language plpgsql;

-- 3) Alla creazione di abitazioni/gabbie l'attributo derivato dovrebbe essere inizializzato a 0
create or replace function set_default_numero_abitazioni() -- exectues n°3
returns trigger
as
$$
begin

if(new.numero_abitazioni != 0) then
    new.numero_abitazioni := 0;
    raise warning 'Il numero di abitazioni è stato impostato a 0 in quanto il valore presente nella query di INSERT non era valido';
    return new;
end if;
return new;

end;
$$ language plpgsql;

------------------------------------------------------------------------------------------------------------------------------------------
-- TRIGGER RELATIVI AGLI ATTRIBUTI DERIVATI   --------------------------------------------------------------------------------------------

create trigger aggiorna_numero_gabbie -- triggers check n° 1
after insert or delete or update of abitazione on Gabbia
for each row
execute procedure aggiorna_numero_gabbie();

create trigger aggiorna_numero_abitazioni -- triggers check  n° 2
after insert or delete or update of area on Abitazione
for each row
execute procedure aggiorna_numero_abitazioni();

create trigger deny_modifica_manuale_numero_gabbie -- triggers check  n° 4 for n_gabbie
before update of numero_gabbie on Abitazione
for each row
execute procedure deny_modifica_manuale_numero_gabbie();

create trigger deny_modifica_manuale_numero_abitazioni -- triggers check  n° 4 for n_abitazioni
before update of numero_abitazioni on Area
for each row
execute procedure deny_modifica_manuale_numero_abitazioni();

create trigger set_default_numero_gabbie -- triggers check  n° 3 for n_gabbie
before insert on Abitazione
for each row
execute procedure set_default_numero_gabbie();

create trigger set_default_numero_abitazioni -- triggers check  n° 3 for n_abitazioni
before insert on Area
for each row
execute procedure set_default_numero_abitazioni();

------------------------------------------------------------------------------------------------------------------------------------------
-- CREAZIONE DEGLI INDICI  ---------------------------------------------------------------------------------------------------------------

create index esemplare_genere_index on Esemplare(genere);

create index esemplare_nome_index on Esemplare(nome);

create index esemplare_id_index on Esemplare(id);

create index visita_genere_id_index on Visita(esemplare_id);

------------------------------------------------------------------------------------------------------------------------------------------
-- CREAZIONE VISTE  ----------------------------------------------------------------------------------------------------------------------

create view info_gabbia as
select gabbia.id, abitazione.id as abitazione, abitazione.genere, abitazione.area
from gabbia join abitazione on abitazione.id = gabbia.abitazione;
