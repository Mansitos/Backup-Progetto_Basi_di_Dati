
create table Area(
    nome                varchar(32),
    numero_abitazioni   integer check(numero_abitazioni>=0) not null,

    constraint pk_area primary key(nome)
);

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
    constraint fk_genere_Abitazione_Genere foreign key (genere) references Genere(nome),
    constraint fk_area_Abitazione_Area foreign key (area) references Area(nome)
);

create table Gabbia(
    id          oid, -- PostgreSQL Object IDentifier type
    abitazione  oid not null,

    constraint pk_Gabbia primary key (id),
    constraint fk_abitazione_Gabbia_Abitazione foreign key (abitazione) references Abitazione(id)
);

create table Esemplare(
    id                  oid, -- PostgreSQL Object IDentifier type
    genere              varchar(32),
    nome                varchar(32) not null,
    sesso               varchar(1) check(sesso == 'M' || sesso == 'F') not null, --check alternative data type
    paese_provenienza   varchar(32) not null,
    data_nascita        date,
    data_arrivo         date not null,
    gabbia              oid not null,

    constraint pk_Esemplare primary key(id,genere),
    constraint fk_genere_Esemplare_Genere foreign key (genere) references Genere(genere),
    constraint fk_gabbia_Esemplare_Gabbia foreign key (gabbia) references Gabbia(id)
);

create table Addetto_pulizie(
    CF              char(16), --check alternative data type (trigger: check if CF is valid)
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 
    turno_pulizia   varchar(64) not null, -- do an entity?

    constraint pk_Addetto_pulizie primary key (CF),
);

create table Pulire(
    addetto_pulizie     char(16),
    abitazione          varchar(32),

    constraint pk_Pulire primary key (addetto_pulizie,abitazione),
    constraint fk_addetto_pulizie_Pulire_Addetto_pulizie foreign key (addetto_pulizie) references Addetto_pulizie(CF),
    constraint fk_abitazione_Pulire_Abitazione foreign key (abitazione) references Abitazione(id) 
);

create table Veterinario(
    CF              char(16), --check alternative data type (trigger: check if CF is valid)
    nome            varchar(32) not null, 
    cognome         varchar(32) not null, 
    stipendio       integer check(stipendio >= 0) not null, 
    telefono        varchar(16), 
    turno_pulizia   varchar(1024) not null, -- do an entity?

    constraint pk_Veterinario primary key (CF),
);

create table Visita(
    veterinario     varchar(32), 
    esemplare_id    oid, 
    esemplare_gen   varchar(32), 
    data            date,
    peso            integer check(peso > 0) not null, 
    diagnostica     varchar(1024) not null, 
    dieta           varchar(1024) not null

    constraint pk_Visita primary key (veterinario,esemplare_id,esemplare_gen,data),
    constraint fk_veterinario_Visita_Veterinario foreign key (veterinario) references Visita(veterinario),
    constraint fk_esemplare_id_Visita_Esemplare foreign key (esemplare_id) references Visita(esemplare_id),
    constraint fk_esemplare_gen_Visista_Genere foreign key (esemplare_gen) references Visita(esemplare_gen)  
);
