
-- CHANGELOG from v2 to v3
-- addedo unique on Esemplare.gabbia --> senza unique: più animali nella stessa gabbia....
-- creato trigger e relativa funzione per la condizione n° 1 e 3
-- creato trigger e relativa funzione per la condizione n° 2
-- creato trigger e relativa funzione per la condizione n° 5
-- creato trigger e relativa funzione per la condizione n° 4


create table Area(
    nome                varchar(32),
    numero_abitazioni   integer check(numero_abitazioni>=0) not null,

    constraint pk_area primary key(nome)
); -- aggiungere trigger per calcolo numero abitazioni

create table Genere(
    nome    varchar(32),
    
    constraint pk_Genere primary key (nome)
);

create table Abitazione(
    id              oid, -- PostgreSQL Object IDentifier type
    genere          varchar(32) not null,  
    numero_gabbie   integer check(numero_gabbie>=0) not null,
    area            varchar(32) not null,

    constraint pk_Abitazione primary key (id),
    constraint fk_genere_Abitazione_Genere foreign key (genere) references Genere(nome)
        on delete restrict
        on update cascade,
    constraint fk_area_Abitazione_Area foreign key (area) references Area(nome)
        on delete restrict
        on update cascade
);

create table Gabbia(
    id          oid, -- PostgreSQL Object IDentifier type
    abitazione  oid not null,

    constraint pk_Gabbia primary key (id),
    constraint fk_abitazione_Gabbia_Abitazione foreign key (abitazione) references Abitazione(id)
        on delete restrict
        on update cascade
);

create table Esemplare(
    id                  oid, -- PostgreSQL Object IDentifier type
    genere              varchar(32),
    nome                varchar(32) not null,
    sesso               varchar(1) check(sesso IN ( 'F' , 'M' )) not null, --check alternative data type
    paese_provenienza   varchar(32) not null,
    data_nascita        date,
    data_arrivo         date not null,
    gabbia              oid unique not null,

    constraint pk_Esemplare primary key(id,genere),
    constraint fk_genere_Esemplare_Genere foreign key (genere) references Genere(nome)
        on delete restrict
        on update cascade,
    constraint fk_gabbia_Esemplare_Gabbia foreign key (gabbia) references Gabbia(id)
        on delete restrict
        on update cascade
);

create table Addetto_pulizie(
    CF              char(16), --check alternative data type (trigger: check if CF is valid)
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 
    turno_pulizia   varchar(64) not null, -- do an entity?

    constraint pk_Addetto_pulizie primary key (CF)
);

create table Pulire(
    addetto_pulizie     char(16),
    abitazione          oid,

    constraint pk_Pulire primary key (addetto_pulizie,abitazione),
    constraint fk_addetto_pulizie_Pulire_Addetto_pulizie foreign key (addetto_pulizie) references Addetto_pulizie(CF)
        on delete cascade
        on update cascade,
    constraint fk_abitazione_Pulire_Abitazione foreign key (abitazione) references Abitazione(id) 
        on delete cascade
        on update cascade
);


create table Veterinario(
    CF              char(16), --check alternative data type (trigger: check if CF is valid)
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 
    turno_pulizia   varchar(1024) not null, -- do an entity?

    constraint pk_Veterinario primary key (CF)
);

create table Visita(
    veterinario     varchar(32), 
    esemplare_id    oid, 
    esemplare_gen   varchar(32), 
    data            date,
    peso            integer check(peso > 0) not null, 
    diagnostica     varchar(1024) not null, 
    dieta           varchar(1024) not null,

    constraint pk_Visita primary key (veterinario,esemplare_id,esemplare_gen,data),
    constraint fk_veterinario_Visita_Veterinario foreign key (veterinario) references Veterinario(CF)
        on delete restrict
        on update cascade,
    constraint fk_esemplare_gen_Visista_Genere foreign key (esemplare_gen,esemplare_id) references Esemplare(genere,id) 
        on delete cascade --se un esemplare muore, cancello tutte le visiste eseguite
        on update cascade
);

------------------------------------------------------------------------------------------------------------------------------
-- TRIGGERS --

create trigger aggiunta_modifica_esemplare -- checks n° 1 & 3
before insert or update on Esemplare
for each row
execute procedure aggiunta_modifica_esemplare();

create trigger modifica_gabbia -- checks n° 2
before update on Gabbia
for each row
execute procedure modifica_gabbia();

create trigger aggiunta_modifica_visita -- checks n° 4
before insert or update on Visita
for each row
execute procedure aggiunta_modifica_visita();

create trigger modifica_genere_abitazione -- checks n° 5
before update on Abitazione
for each row
execute procedure modifica_genere_abitazione();

------------------------------------------------------------------------------------------------------------------------------
-- TRIGGERS SQL FUNCTIONS --


-- 1) All'aggiunta (INSERT/UPDATE) di un esemplare ad una gabbia bisogna controllare che l'abitazione in cui essa sia contenuta abbia il genere corretto.
-- 3) All'aggiunta (INSERT/UPDATE) di un esemplare bisogna controllare che data arrivo > data nascita.
create or replace function aggiunta_modifica_esemplare() -- checks n° 1 & 3
returns trigger
as
$$
begin

    perform *
    from(select    A.genere -- ottengo il genere assegnato all'abitazione contenente la gabbia.
        from       Abitazione A
        where      A.id IN(select    G.abitazione -- ottengo l'id dell'abit. della gabbia in cui sto inserendo l'esemp.
                             from    Gabbia G
                            where    G.id = new.gabbia)) genere_ok
    where new.genere = genere_ok.genere;

    if found then
    	if(new.data_arrivo >= new.data_nascita) then
		return new;
	    end if;
            if(TG_OP = 'UPDATE') then
               raise exception 'ERRORE: Operazione di UPDATE non consentita! La modifica delle date ha portato a delle incongruenze! Vincolo da rispettare: la data di nascita deve essere antecedente o uguale alla data di arrivo';
            elseif(TG_OP = 'INSERT') then
               raise exception 'ERRORE: Operazione di INSERT non consentita! L''esemplare possiede delle incongruenze sulle date! Vincolo da rispettare: la data di nascita deve essere antecedente o uguale alla data di arrivo';
            end if;
    end if;
    
    if(TG_OP = 'UPDATE') then
        if(new.genere = old.genere) then
            raise exception 'ERRORE: Operazione di UPDATE non consentita! La gabbia in cui si vuole spostare l''esemplare è contenuta in un abitazione il cui genere assegnato differisce da quello dell''esemplare';
        elseif(new.gabbia = old.gabbia) then
            raise exception 'ERRORE: Operazione di UPDATE non consentita! Il nuovo genere assegnato all''esemplare non concide con quello assegnato all''abitazione in cui è contenuta la sua gabbia';
        end if;
        raise exception 'ERRORE: Operazione di UPDATE non consentita! ';
    elseif(TG_OP = 'INSERT') then
       raise exception 'ERRORE: Operazione di INSERT non consentita! La gabbia in cui si vuole inserire l''esemplare è contenuta in un abitazione il cui genere assegnato differisce da quello dell''esemplare';
    end if;

end;
$$ language plpgsql;


-- 2) Alla modifica (spostamento) (UPDATE) di una gabbia in una abitazione, bisogna controllare che il genere dell'animale in essa contenuto combaci con quello assegnato alla nuova abitazione di dest.
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

    if found then
       return NEW;
    end if;
	
begin -- CASO 2: gestione del caso in cui la gabbia da spostare è vuota, di conseguenza il CASO 1 ritornerà false su "if found" ma la gabbia può comunque essere spostata perchè è vuota!
	
    perform *
    from    Esemplare E2
    where   E2.gabbia = new.id;
	
	if not found then
		return NEW;
	end if;
	 	raise exception 'ERRORE: Operazione di UPDATE non consentita! Stai spostando una gabbia il cui esemplare contenuto appartiene ad un genere diverso di quello assegnato all''abitazione di destinazione! ';
end;
end;
$$ language plpgsql;


-- 4) All'aggiunta (INSERT/UPDATE) di una visita bisogna controllare che data visita > data arrivo esemplare.
create or replace function aggiunta_modifica_visita() -- checks n° 4
returns trigger
as
$$
    -- LOGICA FUNZIONE:
    -- All'aggiunta o modifica di una visita bisogna controllare che il campo data sia coerente, ovvero che la data di visita non sia antecedente a quella di arrivo dell'esemplare nello zoo in quanto non è possibile!
    -- Inoltre bisogna anche controllare che esista l'esemplare prima di controllarne la data

begin -- controllo prima che l'esemplare specificato dalla visita esista, poi controllerò la coerenza delle date.

    perform *
    from    Esemplare E
    where   E.id = new.esemplare_id and E.genere = new.esemplare_gen;

    if not found then
        raise exception 'ERRORE: Operazione di INSERT/UPDATE non consentita! L''esemplare a cui fa riferimento la visita non esiste';
    end if;

begin -- una volta assicurati che l'esemplare visitato esista, controllo la coerenza delle date
    perform *
    from    Esemplare E
    where   E.id = new.esemplare_id and E.genere = new.esemplare_gen and E.data_arrivo <= new.data;

    if found then
        return NEW;
    end if;
        raise exception 'ERRORE: Operazione di INSERT/UPDATE non consentita! Non è possibile aver visistato un esemplare prima che questo sia arrivato allo zoo!';
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
    -- questi esemplari/gabbie altrove altrimenti ad update completato avrei un'abitazione con genere assegnato X ma esemplari di genere Y al suo interno!
begin

    perform *
    from    Gabbia G
    where   (G.abitazione = new.id) and (new.genere NOT IN (select E.genere
                                                            from   Esemplare E
                                                            where  E.gabbia = G.id));

    if found then
        raise exception 'ERRORE: Operazione di UPDATE non consentita! Non puoi cambiare genere assegnato a questa abitazione perché contiene ancora gabbie con esemplari del vecchio genere!';
    end if;
        return new;

end;
$$ language plpgsql;


