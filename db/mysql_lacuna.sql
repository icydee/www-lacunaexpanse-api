--- Create the schema for the Lacuna Expanse API
--- NOTE the 'star' table will need to be set up from the stars.csv file
---
CREATE TABLE server (
    server_id   integer not null,
    url         text
);

insert into server (server_id, url) values (1, 'http://us1.lacunaexpanse.com/');

--- MORE TO BE DEFINED
CREATE TABLE empire (
    server_id   integer not null,
    empire_id   integer not null,
    foreign key(server_id) references server(id),
    primary key(server_id,empire_id)
);

CREATE TABLE api_hits (
    server_id   integer not null,
    empire_id   integer not null,
    on_date     text not null,
    hits        integer,
    foreign key(server_id) references server(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,empire_id)
);

--- last_scan_date - the last date this star was probed
--- by a probe from empire_id
---
CREATE TABLE star (
    server_id   integer not null,
    star_id     integer not null,
    name        text,
    x           integer not null,
    y           integer not null,
    color       text,
    sector      text,
    foreign key(server_id) references server(id),
    primary key(server_id,star_id)
);

CREATE TABLE star_last_probe (
    server_id   integer not null,
    star_id     integer not null,
    empire_id   integer not null,
    on_date     text,
    foreign key(server_id) references server(id),
    foreign key(star_id) references star(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,star_id,empire_id)
);

CREATE TABLE body (
    server_id   integer not null,
    body_id     integer not null,
    orbit       integer,
    name        text,
    x           integer,
    y           integer,
    image       text,
    size        integer,
    type        text,
    star_id     integer,
    empire_id   integer,
    water       integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(star_id) references star(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,body_id)
);

-- The date that a body was last visited by a probe from an empire
--
CREATE TABLE body_last_visit (
    server_id   integer not null,
    empire_id   integer not null,
    body_id     integer not null,
    on_date     text,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,body_id,empire_id)
);

--- distance from one star to another
---
CREATE TABLE star_distance (
    server_id       integer not null,
    from_star_id    integer,
    to_star_id      integer,
    distance        integer,
    foreign key(from_star_id) references star(id),
    foreign key(to_star_id) references star(id),
    primary key(server_id,from_star_id,to_star_id)
);

CREATE TABLE excavation (
    id              integer not null auto_increment,
    server_id       integer not null,
    empire_id       integer not null,
    body_id         integer,
    body_name       varchar(32),
    on_date         varchar(24),
    colony_id       integer,
    resource_genre  text,
    resource_type   text,
    resource_qty    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(empire_id) references empire(id),
    foreign key(colony_id) references body(id),
    primary key(id)
);

--- alter table excavation add column colony_id integer after on_date;
--- alter table excavation add foreign key(colony_id) references body(id);

CREATE TABLE link_body__ore (
    server_id   integer not null,
    body_id     integer,
    ore_id      integer,
    quantity    integer,
    foreign key(server_id) references server(id),
    foreign key(body_id) references body(id),
    foreign key(ore_id) references ore(id),
    primary key(server_id,body_id,ore_id)
);

CREATE TABLE config (
    server_id   integer not null,
    empire_id   integer not null,
    name        varchar(24) not null,
    val         varchar(256),
    foreign key(server_id) references server(id),
    foreign key(empire_id) references empire(id),
    primary key(server_id,empire_id,name)
);

insert into config (server_id, empire_id, name, val) values (1, 945, 'next_excavated_star', 1);
insert into config (server_id, empire_id, name, val) values (1, 945, 'next_excavated_orbit', 1);

CREATE TABLE ore (
    server_id   integer not null,
    ore_id      integer not null,
    name        text,
    foreign key(server_id) references server(id),
    primary key(server_id,ore_id)
);

insert into ore (server_id, ore_id, name) values (1, 1, 'anthracite');
insert into ore (server_id, ore_id, name) values (1, 2, 'bauxite');
insert into ore (server_id, ore_id, name) values (1, 3, 'beryl');
insert into ore (server_id, ore_id, name) values (1, 4, 'chalcopyrite');
insert into ore (server_id, ore_id, name) values (1, 5, 'chromite');
insert into ore (server_id, ore_id, name) values (1, 6, 'fluorite');
insert into ore (server_id, ore_id, name) values (1, 7, 'galena');
insert into ore (server_id, ore_id, name) values (1, 8, 'goethite');
insert into ore (server_id, ore_id, name) values (1, 9, 'gold');
insert into ore (server_id, ore_id, name) values (1, 10, 'gypsum');
insert into ore (server_id, ore_id, name) values (1, 11, 'halite');
insert into ore (server_id, ore_id, name) values (1, 12, 'kerogen');
insert into ore (server_id, ore_id, name) values (1, 13, 'magnetite');
insert into ore (server_id, ore_id, name) values (1, 14, 'methane');
insert into ore (server_id, ore_id, name) values (1, 15, 'monazite');
insert into ore (server_id, ore_id, name) values (1, 16, 'rutile');
insert into ore (server_id, ore_id, name) values (1, 17, 'sulfur');
insert into ore (server_id, ore_id, name) values (1, 18, 'trona');
insert into ore (server_id, ore_id, name) values (1, 19, 'uraninite');
insert into ore (server_id, ore_id, name) values (1, 20, 'zircon');

